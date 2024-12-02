import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as p;

class ServerProcess {
  final String name;
  ServerProcess(this.name, {IOSink? out}) : _out = out ?? stdout;

  Future<void> start() async {
    final String binPath = p.dirname(Platform.script.path);
    final String root = Directory(binPath).parent.parent.path;
    final String roadpy = p.join(root, 'roadpy');
    _server = await Process.start('environment/bin/python', ['server/$name.py'],
        workingDirectory: roadpy);
    final String prefix = '/tmp/${name}_${_server!.pid}';
    final String outPath = '$prefix.out';
    final String errPath = '$prefix.err';
    _serverOut = File(outPath).openWrite();
    _serverErr = File(errPath).openWrite();
    _server!.stdout.pipe(_serverOut!);
    _server!.stderr.pipe(_serverErr!);
    _out.writeln('Waiting for $name to start...');
    while (!File(outPath).existsSync() ||
        !File(outPath).readAsStringSync().contains('started')) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _out.writeln('$name started, logs: $outPath, $errPath');

    final udsAddress = InternetAddress('/tmp/${name}_${_server!.pid}.sock',
        type: InternetAddressType.unix);
    _channel = ClientChannel(
      udsAddress,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
  }

  Future<void> shutdown() async {
    await _channel.shutdown();
    _server!.kill();
    await _server!.exitCode;
    await _serverOut!.close();
    await _serverErr!.close();
  }

  ClientChannel get channel => _channel;

  final IOSink _out;

  Process? _server;
  IOSink? _serverOut, _serverErr;
  late ClientChannel _channel;
}
