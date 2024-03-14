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
    final stopwatch = Stopwatch()..start();
    print('Sending request...');
    final pb.LineDetection detection = await _client.detectLines(
        pb.LineRequest(videoPath: videoPath, frameIndex: frameIndex));
    final String size = '${detection.width}x${detection.height}';
    print('Detection: ${detection.lines.length} lines detected ($size)');
    print('Received detection in ${stopwatch.elapsedMilliseconds}ms');

    stopwatch.reset();
    final filter = LineFilter();
    filter.process(detection);
    print('#R=${filter.rightLines.length}, #L=${filter.leftLines.length}');
    print('Min bottom x: ${filter.minBottomX}');
    print('Processed in ${stopwatch.elapsedMilliseconds}ms');

    stopwatch.reset();
    await _client.plot(pb.PlotRequest(
        lines: filter.rightLines.map((l) => l.pbLine), lineColor: 'yellow'));
    await _client.plot(pb.PlotRequest(
        lines: filter.leftLines.map((l) => l.pbLine), lineColor: 'green'));
    await _client.plot(pb.PlotRequest(
      points: filter.intersections.map((v) => vec2Proto(v)),
      pointColor: 'blue',
    ));
    if (filter.guessedPoint != null) {
      await _client.plot(pb.PlotRequest(
        points: [vec2Proto(filter.guessedPoint!)],
        pointColor: 'red',
      ));
    }
    await _client.exportPng(pb.Empty());
    print('Plotted in ${stopwatch.elapsedMilliseconds}ms\n');
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
  Future<void> update(int frameDelta) async {
    print('frame: ${frameIndex += frameDelta}');
    await labeler.label(videoPath, frameIndex);
  }

  sub = stdin.map<String>(String.fromCharCodes).listen((String key) async {
    const int kFrameStep = 30;
    if (key == 'q') {
      print('Quitting...');
      sub.cancel();
      await labeler.shutdown();
    } else if (key == 'l') {
      await update(kFrameStep);
    } else if (key == 'h') {
      await update(-kFrameStep);
    } else if (key == 'k') {
      await update(1);
    } else if (key == 'j') {
      await update(-1);
    } else {
      print('Unknown key: $key');
    }
  });
}

Future<void> main(List<String> arguments) async {
  await listenKey(arguments[0], int.parse(arguments[1]));
}
