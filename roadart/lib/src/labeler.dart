import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:roadart/proto/label.pbgrpc.dart' as pb;
import 'package:roadart/src/obstacle_filter.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'label_set.dart';
import 'line_filter.dart';
import 'server_process.dart';

part 'labeler.freezed.dart';
part 'labeler.g.dart';

const int kMinImageSize = 5000; // Ignore images smaller than 5KB

@freezed
class LabelResult with _$LabelResult {
  const factory LabelResult({
    required String imagePath,
    required double xRatio, // vashing (road direction) at x = xRatio * width
    required double yRatio, // vashing (road direction) at y = yRatio * height
    required double leftRatio, // leftRatio * (pi / 2) from vertical
    required double rightRatio, // rightRatio * (pi / 2) from vertical
    required double yRatioObstacleMin, // obs top at this ratio * height
    required double yRatioObstacleMax, // obs bottom at this ratio * height
    required double xRatioObstacleMin, // obs left at this ratio * width
    required double xRatioObstacleMax, // obs right at this ratio * width
    required double obstacleConfidence, // 0 to 1
  }) = _LabelResult;

  factory LabelResult.fromJson(Map<String, Object?> json) =>
      _$LabelResultFromJson(json);
}

/// Must call [start] first, and [shutdown] at the end.
class Labeler {
  Labeler({IOSink? out}) : _out = out ?? stdout;
  final IOSink _out;

  Future<void> start() async {
    _lineServer = ServerProcess('line_detector_server', out: _out);
    await _lineServer!.start();
    _lineClient = pb.LineDetectorClient(_lineServer!.channel);
  }

  Future<void> _startSegmentServer() async {
    _segmentServer = ServerProcess('segment_server', out: _out);
    await _segmentServer!.start();
    _segmentClient = pb.SegmenterClient(_segmentServer!.channel);
  }

  Future<void> shutdown() async {
    await _lineServer?.shutdown();
    await _segmentServer?.shutdown();
  }

  Future<void> exportLabel(LabelSet labelSet) async {
    if (_lastFilter == null) {
      _out.writeln('No filter to export label');
      return;
    }
    final LabelResult? result = _makeResult(_lastFilter!, _lastClosest);
    if (result == null) {
      _out.writeln('Failed to generate label.');
      return;
    }
    labelSet.add(result.imagePath, result);
    labelSet.save();
    _out.writeln('Exported label to ${labelSet.jsonPath}');
  }

  Future<void> adjustRight(int indexDelta) async {
    if (_lastFilter == null || _lastFilter!.guessedPoint == null) {
      _out.writeln('Nothing to adjust');
      return;
    }
    _lastFilter!.adjustRightBottomX(indexDelta);
    await _lineClient.resetPlot(pb.Empty());
    await _plot(_lastFilter!, _lastClosest);
  }

  Future<void> resetImage() async {
    await _lineClient.resetPlot(pb.Empty());
    await _lineClient.exportPng(pb.Empty());
    _out.writeln('Image reset.');
  }

  Future<void> labelVideo(
      String videoPath, int frameIndex, String? modelPath) async {
    _lastFilter = await _handleRequest(pb.LineRequest(
        videoPath: videoPath, frameIndex: frameIndex, modelPath: modelPath));
  }

  Future<LabelResult?> labelVideoWithSam(
      String videoPath, int frameIndex, String? modelPath) async {
    if (_segmentServer == null) {
      await _startSegmentServer();
    }
    const String kSegmentPath = '/tmp/segment.png';
    await _segmentClient.segment(pb.SegmentRequest(
        videoPath: videoPath,
        frameIndex: frameIndex,
        outputPath: kSegmentPath));
    final LineFilter maskLabel = await labelGeneral(kSegmentPath, modelPath);
    final LineFilter label = await _handleRequest(pb.LineRequest(
        videoPath: videoPath, frameIndex: frameIndex, modelPath: modelPath));
    return await labelAfterMask(maskLabel, label);
  }

  Future<LabelResult?> labelImage(String imagePath, String? modelPath) async {
    LabelResult? result;
    _out.writeln('Labeling image: $imagePath');
    if (imagePath.contains('comma10k/masks')) {
      await labelCommaMask(imagePath);
    } else if (imagePath.contains('comma10k/imgs')) {
      result = await labelCommaImage(imagePath);
    } else {
      await labelGeneral(imagePath, modelPath);
    }
    _out.writeln('');
    return result;
  }

  Future<LabelResult?> labelCommaImage(String imagePath) async {
    final String maskPath = imagePath.replaceAll('imgs', 'masks');
    final LineFilter maskLabel = await labelCommaMask(maskPath, plot: false);
    // Find the closest obstacle using detections from the original image.
    final LineFilter label = await labelGeneral(imagePath, null, plot: false);
    return await labelAfterMask(maskLabel, label);
  }

  Future<LabelResult?> labelAfterMask(
      LineFilter maskLabel, LineFilter label) async {
    final obstacleFilter = ObstacleFilter(_out, maskLabel);
    _lastClosest = obstacleFilter.findClosestObstacle(label.detection!);

    final LabelResult? maskResult = _makeResult(maskLabel, _lastClosest);
    if (maskResult != null) {
      final result = maskResult.copyWith(imagePath: label.debugImagePath);
      final jsonStr = JsonEncoder.withIndent('  ').convert(result.toJson());
      _out.writeln('Label result: $jsonStr\n');
      return result;
    }
    return null;
  }

  Future<LineFilter> labelCommaMask(String maskPath, {bool plot = true}) async {
    final map = <pb.ColorMapping>[
      // comma10k my car to road
      pb.ColorMapping(fromHex: '#cc00ff', toHex: '#402020'),
      // comma10k movable to road
      pb.ColorMapping(fromHex: '#00ff66', toHex: '#402020'),
      // comma10k movable_in_my_car to road
      pb.ColorMapping(fromHex: '#00ccff', toHex: '#402020'),
    ];
    final request = pb.LineRequest(imagePath: maskPath, colorMappings: map);
    final LineFilter filter = await _handleRequest(request, plot: false);

    // Try to refresh right bottom x without lane markings (i.e., maps comma10k
    // lane marking to road). This helps detecting road boundaries.
    request.colorMappings
        .add(pb.ColorMapping(fromHex: '#ff0000', toHex: '#402020'));
    final pb.LineDetection newDetection =
        await _lineClient.detectLines(request);
    filter.refreshRightBottomX(newDetection);
    const kNewDetectionProtoDump = '/tmp/new_line_detection.pb';
    File(kNewDetectionProtoDump).writeAsBytesSync(newDetection.writeToBuffer());
    _out.writeln('Detection w/o landmarks: ${newDetection.lines.length} lines');
    _out.writeln('New detection proto saved to $kNewDetectionProtoDump');
    _out.writeln('Updated right bottom x: ${filter.rightBottomX}');

    if (plot) {
      await _plot(filter, null);
    }
    _lastFilter = filter;
    return filter;
  }

  Future<LineFilter> labelGeneral(
    String imagePath,
    String? modelPath, {
    bool plot = true,
  }) async {
    _lastFilter = await _handleRequest(
      pb.LineRequest(imagePath: imagePath, modelPath: modelPath),
      plot: plot,
    );
    return _lastFilter!;
  }

  static LabelResult? _makeResult(LineFilter line, pb.Obstacle? obs) {
    if (line.guessedPoint == null ||
        line.leftBottomX == null ||
        line.rightBottomX == null) {
      return null;
    }
    final Vector2 c = line.guessedPoint!;
    final int h = line.detection!.height;
    final int w = line.detection!.width;
    final double leftAngle = atan((c.x - line.leftBottomX!) / (h - c.y));
    final double rightAngle = atan((line.rightBottomX! - c.x) / (h - c.y));
    return LabelResult(
      imagePath: line.debugImagePath,
      xRatio: c.x / w,
      yRatio: c.y / h,
      leftRatio: leftAngle / (pi / 2),
      rightRatio: rightAngle / (pi / 2),
      yRatioObstacleMin: obs?.t ?? 0.0,
      yRatioObstacleMax: obs?.b ?? 0.0,
      xRatioObstacleMin: obs?.l ?? 0.0,
      xRatioObstacleMax: obs?.r ?? 0.0,
      obstacleConfidence: obs?.confidence ?? 0.0,
    );
  }

  Future<LineFilter> _handleRequest(
    pb.LineRequest request, {
    bool plot = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    _out.writeln('Sending request...');
    late pb.LineDetection detection;
    try {
      detection = await _lineClient.detectLines(request);
    } catch (e) {
      print('Shutdown due to errors.');
      await shutdown();
      rethrow;
    }

    final String size = '${detection.width}x${detection.height}';
    final List<pb.Obstacle> obstacles = detection.obstacles;
    const kDetectionProtoDump = '/tmp/line_detection.pb';
    File(kDetectionProtoDump).writeAsBytesSync(detection.writeToBuffer());
    _out.writeln('Detection: ${detection.lines.length} lines detected ($size)');
    _out.writeln('Received detection in ${stopwatch.elapsedMilliseconds}ms');
    _out.writeln('Detected ${obstacles.length} obstacles');
    if (obstacles.isNotEmpty) {
      _out.writeln('First obstacle:\n${obstacles.first.toDebugString()}');
    }
    _out.writeln('Detection proto saved to $kDetectionProtoDump');

    stopwatch.reset();
    final filter = LineFilter();
    filter.process(detection);
    _out.writeln(
        '#R=${filter.rightLines.length}, #L=${filter.leftLines.length}');
    _out.writeln('Right bottom x: ${filter.rightBottomX}');
    _out.writeln('Left bottom x: ${filter.leftBottomX}');
    _out.writeln('Processed in ${stopwatch.elapsedMilliseconds}ms');

    final obstacleFilter = ObstacleFilter(_out, filter);
    pb.Obstacle? closest = obstacleFilter.findClosestObstacle(detection);
    _lastClosest = closest;

    if (plot) {
      await _plot(filter, closest);
    }

    if (request.hasImagePath()) {
      filter.debugImagePath = request.imagePath;
    } else if (request.hasVideoPath()) {
      filter.debugImagePath = '${request.videoPath}:${request.frameIndex}';
    }

    return filter;
  }

  Future<void> _plot(LineFilter filter, pb.Obstacle? closestObstacle) async {
    final stopwatch = Stopwatch()..start();
    await _lineClient.plot(pb.PlotRequest(
      points: filter.intersections.map((v) => vec2Proto(v)),
      pointColor: 'blue',
      lines: _computeBoundaries(filter),
      lineColor: 'blue',
    ));
    await _lineClient.plot(pb.PlotRequest(
        lines: filter.rightLines.map((l) => l.pbLine), lineColor: 'yellow'));
    await _lineClient.plot(pb.PlotRequest(
        lines: filter.leftLines.map((l) => l.pbLine), lineColor: 'green'));
    if (filter.guessedPoint != null) {
      _out.writeln('Guessed point: ${filter.guessedPoint}');
      await _lineClient.plot(pb.PlotRequest(
        points: [vec2Proto(filter.guessedPoint!)],
        pointColor: 'red',
      ));
    }

    if (closestObstacle != null) {
      final double width = filter.detection!.width.toDouble();
      final double height = filter.detection!.height.toDouble();
      final double y = height * closestObstacle.b;
      final pb.Obstacle obs = closestObstacle;
      final double w = obs.r - obs.l;
      final double x0 = width * obs.l;
      final double x1 = width * obs.r;
      _out.writeln('Closest obstacle: ${obs.label} at b=${obs.b}, w=$w');
      await _lineClient.plot(pb.PlotRequest(
          lines: [pb.Line(x0: x0, y0: y, x1: x1, y1: y)], lineColor: 'red'));
    }

    await _lineClient.exportPng(pb.Empty());
    _out.writeln('Plotted in ${stopwatch.elapsedMilliseconds}ms\n');
  }

  List<pb.Line> _computeBoundaries(LineFilter filter) {
    final pb.LineDetection detection = filter.detection!;
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

  ServerProcess? _segmentServer;
  late pb.SegmenterClient _segmentClient;
  ServerProcess? _lineServer;
  late pb.LineDetectorClient _lineClient;
  LineFilter? _lastFilter;
  pb.Obstacle? _lastClosest;
}
