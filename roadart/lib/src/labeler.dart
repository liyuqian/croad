import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as p;
import 'package:roadart/proto/label.pbgrpc.dart' as pb;
import 'package:vector_math/vector_math_64.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'line_filter.dart';

part 'labeler.freezed.dart';
part 'labeler.g.dart';

@freezed
class LabelResult with _$LabelResult {
  const factory LabelResult({
    required String imagePath,
    required double xRatio, // vashing (road direction) at x = xRatio * width
    required double yRatio, // vashing (road direction) at y = yRatio * height
    required double leftRatio, // leftRatio * (pi / 2) from vertical
    required double rightRatio, // rightRatio * (pi / 2) from vertical
  }) = _LabelResult;

  factory LabelResult.fromJson(Map<String, Object?> json) =>
      _$LabelResultFromJson(json);
}

/// Must call [start] first, and [shutdown] at the end.
class Labeler {
  Future<void> start() async {
    final int serverPid = await _startServer();
    final udsAddress = InternetAddress('/tmp/line_detection_$serverPid.sock',
        type: InternetAddressType.unix);
    _channel = ClientChannel(
      udsAddress,
      options: const ChannelOptions(credentials: ChannelCredentials.insecure()),
    );
    _client = pb.LineDetectorClient(_channel);
  }

  // Returns server's pid
  Future<int> _startServer() async {
    final String binPath = p.dirname(Platform.script.path);
    final String root = Directory(binPath).parent.parent.path;
    final String roadpy = p.join(root, 'roadpy');
    _serverProcess = await Process.start(
        'environment/bin/python', ['line_detector_server.py'],
        workingDirectory: roadpy);
    const String kServerOutPath = '/tmp/line_detector_server.out';
    const String kServerErrPath = '/tmp/line_detector_server.err';
    _serverOut = File(kServerOutPath).openWrite();
    _serverErr = File(kServerErrPath).openWrite();
    _serverProcess!.stdout.pipe(_serverOut!);
    _serverProcess!.stderr.pipe(_serverErr!);
    print('Waiting for server to start...');
    while (!File(kServerOutPath).readAsStringSync().contains('started')) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    print('Server started, logs: $kServerOutPath, $kServerErrPath');
    return _serverProcess!.pid;
  }

  Future<void> shutdown() async {
    await _channel.shutdown();
    _serverProcess!.kill();
    await _serverProcess!.exitCode;
    await _serverOut!.close();
    await _serverErr!.close();
  }

  Future<void> labelVideo(String videoPath, int frameIndex) async {
    await _handleRequest(
        pb.LineRequest(videoPath: videoPath, frameIndex: frameIndex));
  }

  Future<void> labelImage(String imagePath) async {
    if (imagePath.contains('comma10k/masks')) {
      await labelCommaMask(imagePath);
    } else if (imagePath.contains('comma10k/imgs')) {
      await labelCommaImage(imagePath);
    } else {
      throw Exception('Unsupported image path: $imagePath');
    }
  }

  Future<void> labelCommaImage(String imagePath) async {
    final String maskPath = imagePath.replaceAll('imgs', 'masks');
    final LineFilter processed = await labelCommaMask(maskPath, plot: false);
    if (processed.guessedPoint == null) {
      return;
    }
    final Vector2 c = processed.guessedPoint!;
    final int h = processed.detection!.height;
    final int w = processed.detection!.width;
    final double leftAngle = atan((c.x - processed.leftBottomX!) / (h - c.y));
    final double rightAngle = atan((processed.rightBottomX! - c.x) / (h - c.y));
    final result = LabelResult(
      imagePath: imagePath,
      xRatio: c.x / w,
      yRatio: c.y / h,
      leftRatio: leftAngle / (pi / 2),
      rightRatio: rightAngle / (pi / 2),
    );
    final jsonStr = JsonEncoder.withIndent('  ').convert(result.toJson());
    print('Label result: $jsonStr\n');
  }

  Future<LineFilter> labelCommaMask(String maskPath, {bool plot = true}) async {
    return await _handleRequest(
      pb.LineRequest(imagePath: maskPath, colorMappings: [
        // comma10k my car to road
        pb.ColorMapping(fromHex: '#cc00ff', toHex: '#402020'),
        // comma10k movable to road
        pb.ColorMapping(fromHex: '#00ff66', toHex: '#402020'),
        // comma10k movable_in_my_car to road
        pb.ColorMapping(fromHex: '#00ccff', toHex: '#402020'),
      ]),
      plot: plot,
    );
  }

  Future<LineFilter> _handleRequest(
    pb.LineRequest request, {
    bool plot = true,
  }) async {
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
    print('Right bottom x: ${filter.rightBottomX}');
    print('Left bottom x: ${filter.leftBottomX}');
    print('Processed in ${stopwatch.elapsedMilliseconds}ms');

    if (plot) {
      await _plot(detection, filter);
    }

    return filter;
  }

  Future<void> _plot(pb.LineDetection detection, LineFilter filter) async {
    final stopwatch = Stopwatch()..start();
    await _client.plot(pb.PlotRequest(
      points: filter.intersections.map((v) => vec2Proto(v)),
      pointColor: 'blue',
      lines: _computeBoundaries(filter, detection),
      lineColor: 'blue',
    ));
    await _client.plot(pb.PlotRequest(
        lines: filter.rightLines.map((l) => l.pbLine), lineColor: 'yellow'));
    await _client.plot(pb.PlotRequest(
        lines: filter.leftLines.map((l) => l.pbLine), lineColor: 'green'));
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
    final Vector2 c = filter.guessedPoint!;
    if (filter.leftBottomX != null) {
      final l = Vector2(filter.leftBottomX!, detection.height.toDouble());
      if (l.x < 0) {
        l.y = c.y - (l.y - c.y) / (l.x - c.x) * c.x;
        l.x = 0;
      }
      boundaries.add(pb.Line(x0: c.x, y0: c.y, x1: l.x, y1: l.y));
    }
    if (filter.rightBottomX != null) {
      final r = Vector2(filter.rightBottomX!, detection.height.toDouble());
      if (r.x > detection.width) {
        r.y = c.y + (r.y - c.y) / (r.x - c.x) * (detection.width - c.x);
        r.x = detection.width.toDouble();
      }
      boundaries.add(pb.Line(x0: c.x, y0: c.y, x1: r.x, y1: r.y));
    }
    return boundaries;
  }

  IOSink? _serverOut, _serverErr;
  Process? _serverProcess;
  late ClientChannel _channel;
  late pb.LineDetectorClient _client;
}
