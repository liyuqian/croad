import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:roadart/proto/label.pbgrpc.dart' as pb;
import 'package:roadart/src/line_filter.dart';
import 'package:path/path.dart' as p;

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

  Future<void> labelVideo(String videoPath, int frameIndex) async {
    await _handleRequest(
        pb.LineRequest(videoPath: videoPath, frameIndex: frameIndex));
  }

  Future<void> labelImage(String imagePath) async {
    await _handleRequest(pb.LineRequest(imagePath: imagePath, colorMappings: [
      // comma10k my car to road
      pb.ColorMapping(fromHex: '#cc00ff', toHex: '#402020'),
      // comma10k movable to road
      pb.ColorMapping(fromHex: '#00ff66', toHex: '#402020'),
      // comma10k movable_in_my_car to road
      pb.ColorMapping(fromHex: '#00ccff', toHex: '#402020'),
    ]));
  }

  Future<void> _handleRequest(pb.LineRequest request) async {
    final stopwatch = Stopwatch()..start();
    print('Sending request...');
    final pb.LineDetection detection = await _client.detectLines(request);
    final String size = '${detection.width}x${detection.height}';
    const kDetectionProtoDump = '/tmp/line_detection.pb';
    File(kDetectionProtoDump).writeAsBytesSync(detection.writeToBuffer());
    print('Detection: ${detection.lines.length} lines detected ($size)');
    print('Received detection in ${stopwatch.elapsedMilliseconds}ms');
    print('Detection proto saved to $kDetectionProtoDump');

    stopwatch.reset();
    final filter = LineFilter();
    filter.process(detection);
    print('#R=${filter.rightLines.length}, #L=${filter.leftLines.length}');
    print('Min bottom x: ${filter.minBottomX}');
    print('Max bottom x: ${filter.minBottomX}');
    print('Processed in ${stopwatch.elapsedMilliseconds}ms');

    stopwatch.reset();
    await _client.plot(pb.PlotRequest(
        lines: filter.rightLines.map((l) => l.pbLine), lineColor: 'yellow'));
    await _client.plot(pb.PlotRequest(
        lines: filter.leftLines.map((l) => l.pbLine), lineColor: 'green'));
    await _client.plot(pb.PlotRequest(
      points: filter.intersections.map((v) => vec2Proto(v)),
      pointColor: 'blue',
      lines: _computeBoundaries(filter, detection),
      lineColor: 'blue',
    ));
    if (filter.guessedPoint != null) {
      print('Guessed point: ${filter.guessedPoint}');
      await _client.plot(pb.PlotRequest(
        points: [vec2Proto(filter.guessedPoint!)],
        pointColor: 'red',
      ));
    }
    await _client.exportPng(pb.Empty());
    print('Plotted in ${stopwatch.elapsedMilliseconds}ms\n');
  }

  List<pb.Line> _computeBoundaries(
      LineFilter filter, pb.LineDetection detection) {
    final List<pb.Line> boundaries = [];
    if (filter.guessedPoint == null) return boundaries;
    if (filter.minBottomX != null) {
      boundaries.add(pb.Line(
        x0: filter.guessedPoint!.x,
        y0: filter.guessedPoint!.y,
        x1: filter.minBottomX!,
        y1: detection.height.toDouble(),
      ));
    }
    if (filter.maxBottomX != null) {
      boundaries.add(pb.Line(
        x0: filter.guessedPoint!.x,
        y0: filter.guessedPoint!.y,
        x1: filter.maxBottomX!,
        y1: detection.height.toDouble(),
      ));
    }
    return boundaries;
  }

  late ClientChannel _channel;
  late pb.LineDetectorClient _client;
}

Future<void> listenKeyForVideo(String videoPath, int frameIndex) async {
  final labeler = Labeler();
  await labeler.labelVideo(videoPath, frameIndex);
  stdin.echoMode = false;
  stdin.lineMode = false;
  Future<void> update(int frameDelta) async {
    print('frame: ${frameIndex += frameDelta}');
    await labeler.labelVideo(videoPath, frameIndex);
  }

  late StreamSubscription sub;
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

Future<void> listenKeyForImage(String imageDirOrFile) async {
  final labeler = Labeler();
  late String imageDir;
  late String imageFile;
  if (!FileSystemEntity.isDirectorySync(imageDirOrFile)) {
    imageDir = File(imageDirOrFile).parent.path;
    imageFile = p.basename(File(imageDirOrFile).path);
  } else {
    imageDir = imageDirOrFile;
    imageFile = '';
  }
  final images = Directory(imageDir)
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .toList();
  int index = 0;
  for (int i = 0; i < images.length; ++i) {
    if (p.basename(images[i]) == imageFile) {
      index = i;
      break;
    }
  }
  await labeler.labelImage(images[index]);
  stdin.echoMode = false;
  stdin.lineMode = false;
  Future<void> update(int delta) async {
    while (true) {
      index = (index + delta) % images.length;
      if (index < 0) {
        index = images.length - 1;
      }
      const int kMinSize = 5000; // Ignore images smaller than 5KB
      if (File(images[index]).lengthSync() >= kMinSize) {
        break;
      }
    }
    print('image: ${images[index]}');
    if (images[index].contains('masks')) {
      print('original: ${images[index].replaceAll('masks', 'imgs')}');
    }
    await labeler.labelImage(images[index]);
  }

  late StreamSubscription sub;
  sub = stdin.map<String>(String.fromCharCodes).listen((String key) async {
    if (key == 'q') {
      print('Quitting...');
      sub.cancel();
      await labeler.shutdown();
    } else if (key == 'l') {
      await update(1);
    } else if (key == 'h') {
      await update(-1);
    } else {
      print('Unknown key: $key');
    }
  });
}

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1) {
    await listenKeyForImage(arguments[0]);
  } else {
    await listenKeyForVideo(arguments[0], int.parse(arguments[1]));
  }
}
