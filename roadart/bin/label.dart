import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:roadart/proto/label.pbgrpc.dart' as pb;
import 'package:roadart/src/line_filter.dart';

class Labeler {
  Labeler() {
    final udsAddress = InternetAddress('/tmp/line_detection.sock',
        type: InternetAddressType.unix);
    _channel = ClientChannel(
      udsAddress,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _client = pb.LineDetectorClient(_channel);
  }

  Future<void> shutdown() async => await _channel.shutdown();

  Future<void> label(String videoPath, int frameIndex) async {
    print('Sending request...');
    final pb.LineDetection detection = await _client.detectLines(
        pb.LineRequest(videoPath: videoPath, frameIndex: frameIndex));
    final String size = '${detection.width}x${detection.height}';
    print('Detection: ${detection.lines.length} lines detected ($size)');

    final filter = LineFilter();
    final filtered = filter.process(detection);
    print('Filtered: ${filtered.length} lines remaining');
    print('Min bottom x: ${filter.minBottomX}');
    await _client.plot(
        pb.PlotRequest(lines: filtered.map((l) => l.proto), color: 'yellow'));
  }

  late ClientChannel _channel;
  late pb.LineDetectorClient _client;
}

Future<void> listenKey(String videoPath, int frameIndex) async {
  final labeler = Labeler();
  await labeler.label(videoPath, frameIndex);
  stdin.echoMode = false;
  stdin.lineMode = false;
  late StreamSubscription sub;
  sub = stdin.map<String>(String.fromCharCodes).listen((String key) async {
    const int kFrameStep = 30;
    if (key == 'q') {
      print('Quitting...');
      sub.cancel();
      await labeler.shutdown();
    } else if (key == 'l') {
      print('frame: ${frameIndex += kFrameStep}');
      await labeler.label(videoPath, frameIndex);
    } else if (key == 'h') {
      print('frame: ${frameIndex -= kFrameStep}');
      await labeler.label(videoPath, frameIndex);
    } else {
      print('Unknown key: $key');
    }
  });
}

Future<void> main(List<String> arguments) async {
  await listenKey(arguments[0], int.parse(arguments[1]));
}
