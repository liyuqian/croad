import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:roadart/proto/label.pbgrpc.dart';
import 'package:roadart/src/line_filter.dart';

class Labeler {
  Labeler() {
    final udsAddress = InternetAddress('/tmp/line_detection.sock',
        type: InternetAddressType.unix);
    _channel = ClientChannel(
      udsAddress,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _client = LineDetectorClient(_channel);
  }

  Future<void> shutdown() async => await _channel.shutdown();

  Future<void> label(String videoPath, int frameIndex) async {
    print('Sending request...');
    final LineDetection detection = await _client
        .detectLines(LineRequest(videoPath: videoPath, frameIndex: frameIndex));
    final String size = '${detection.width}x${detection.height}';
    print('Detection: ${detection.lines.length} lines detected ($size)');

    final filtered = LineFilter().filter(detection);
    print('Filtered: ${filtered.length} lines remaining');
    await _client.plot(PlotRequest(lines: filtered, color: 'green'));
  }

  late ClientChannel _channel;
  late LineDetectorClient _client;
}

Future<void> main(List<String> arguments) async {
  final labeler = Labeler();
  await labeler.label(arguments[0], int.parse(arguments[1]));
  await labeler.shutdown();
}
