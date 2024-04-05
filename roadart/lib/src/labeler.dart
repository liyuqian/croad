import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as p;
import 'package:roadart/proto/label.pbgrpc.dart' as pb;
import 'package:vector_math/vector_math_64.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'label_set.dart';
import 'line_filter.dart';

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
  }) = _LabelResult;

  factory LabelResult.fromJson(Map<String, Object?> json) =>
      _$LabelResultFromJson(json);
}

/// Must call [start] first, and [shutdown] at the end.
class Labeler {
  Labeler({IOSink? out}) : _out = out ?? stdout;
  final IOSink _out;

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
    final String prefix = '/tmp/line_detector_server_${_serverProcess!.pid}';
    final String outPath = '$prefix.out';
    final String errPath = '$prefix.err';
    _serverOut = File(outPath).openWrite();
    _serverErr = File(errPath).openWrite();
    _serverProcess!.stdout.pipe(_serverOut!);
    _serverProcess!.stderr.pipe(_serverErr!);
    _out.writeln('Waiting for server to start...');
    while (!File(outPath).existsSync() ||
        !File(outPath).readAsStringSync().contains('started')) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _out.writeln('Server started, logs: $outPath, $errPath');
    return _serverProcess!.pid;
  }

  Future<void> shutdown() async {
    await _channel.shutdown();
    _serverProcess!.kill();
    await _serverProcess!.exitCode;
    await _serverOut!.close();
    await _serverErr!.close();
  }

  Future<void> exportLabel(LabelSet labelSet) async {
    if (_lastFilter == null) {
      _out.writeln('No filter to export label');
      return;
    }
    final LabelResult? result = _makeResult(_lastFilter!);
    if (result == null) {
      _out.writeln('Failed to generate label.');
      return;
    }
    labelSet.add(result.imagePath, result);
    labelSet.save();
    _out.writeln('Exported label to ${labelSet.jsonPath}');
  }

  Future<void> labelVideo(
      String videoPath, int frameIndex, String? modelPath) async {
    _lastFilter = await _handleRequest(pb.LineRequest(
        videoPath: videoPath, frameIndex: frameIndex, modelPath: modelPath));
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
    final LineFilter processed = await labelCommaMask(maskPath, plot: false);
    final LabelResult? result = _makeResult(processed);
    if (result != null) {
      final jsonStr = JsonEncoder.withIndent('  ').convert(result.toJson());
      _out.writeln('Label result: $jsonStr\n');
    }
    _lastFilter = processed;
    return result;
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
    final pb.LineDetection newDetection = await _client.detectLines(request);
    filter.refreshRightBottomX(newDetection);
    const kNewDetectionProtoDump = '/tmp/new_line_detection.pb';
    File(kNewDetectionProtoDump).writeAsBytesSync(newDetection.writeToBuffer());
    _out.writeln('Detection w/o landmarks: ${newDetection.lines.length} lines');
    _out.writeln('New detection proto saved to $kNewDetectionProtoDump');
    _out.writeln('Updated right bottom x: ${filter.rightBottomX}');
    if (plot) {
      await _plot(newDetection, filter);
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

  LabelResult? _makeResult(LineFilter processed) {
    if (processed.guessedPoint == null ||
        processed.leftBottomX == null ||
        processed.rightBottomX == null) {
      return null;
    }
    final Vector2 c = processed.guessedPoint!;
    final int h = processed.detection!.height;
    final int w = processed.detection!.width;
    final double leftAngle = atan((c.x - processed.leftBottomX!) / (h - c.y));
    final double rightAngle = atan((processed.rightBottomX! - c.x) / (h - c.y));
    return LabelResult(
      imagePath: processed.debugImagePath,
      xRatio: c.x / w,
      yRatio: c.y / h,
      leftRatio: leftAngle / (pi / 2),
      rightRatio: rightAngle / (pi / 2),
    );
  }

  Future<LineFilter> _handleRequest(
    pb.LineRequest request, {
    bool plot = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    _out.writeln('Sending request...');
    final pb.LineDetection detection = await _client.detectLines(request);
    final String size = '${detection.width}x${detection.height}';
    const kDetectionProtoDump = '/tmp/line_detection.pb';
    File(kDetectionProtoDump).writeAsBytesSync(detection.writeToBuffer());
    _out.writeln('Detection: ${detection.lines.length} lines detected ($size)');
    _out.writeln('Received detection in ${stopwatch.elapsedMilliseconds}ms');
    _out.writeln('Detection proto saved to $kDetectionProtoDump');

    stopwatch.reset();
    final filter = LineFilter();
    filter.process(detection);
    _out.writeln(
        '#R=${filter.rightLines.length}, #L=${filter.leftLines.length}');
    _out.writeln('Right bottom x: ${filter.rightBottomX}');
    _out.writeln('Left bottom x: ${filter.leftBottomX}');
    _out.writeln('Processed in ${stopwatch.elapsedMilliseconds}ms');

    if (plot) {
      await _plot(detection, filter);
    }

    if (request.hasImagePath()) {
      filter.debugImagePath = request.imagePath;
    } else if (request.hasVideoPath()) {
      filter.debugImagePath = '${request.videoPath}:${request.frameIndex}';
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
      _out.writeln('Guessed point: ${filter.guessedPoint}');
      await _client.plot(pb.PlotRequest(
        points: [vec2Proto(filter.guessedPoint!)],
        pointColor: 'red',
      ));
    }
    await _client.exportPng(pb.Empty());
    _out.writeln('Plotted in ${stopwatch.elapsedMilliseconds}ms\n');
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
  LineFilter? _lastFilter;
}
