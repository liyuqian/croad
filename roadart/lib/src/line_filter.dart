import 'dart:io';
import 'dart:math';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:vector_math/vector_math_64.dart';

const double kEpsilon = 1e-8;

class Range {
  const Range(this.min, this.max);
  final double min, max;
  bool contains(double value) => value >= min && value <= max;
}

pb.Point vec2Proto(Vector2 v) => pb.Point(x: v.x, y: v.y);

class Line {
  final Vector2 start, end;
  final pb.Line pbLine;
  final pb.LineDetection fullDetection;
  Line(this.pbLine, this.fullDetection)
      : start = Vector2(pbLine.x0, pbLine.y0),
        end = Vector2(pbLine.x1, pbLine.y1);
  Vector2 get mid => (start + end) / 2;
  double get length => (end - start).length;
  double get xRatio => mid.x / fullDetection.width;
  double get yRatio => mid.y / fullDetection.height;
  double get xStartRatio => start.x / fullDetection.width;
  double get yStartRatio => start.y / fullDetection.height;
  double get xEndRatio => end.x / fullDetection.width;
  double get yEndRatio => end.y / fullDetection.height;

  bool get isHorizontal => (end.y - start.y).abs() < kEpsilon;
  double? get dxOverDy =>
      isHorizontal ? null : (end.x - start.x) / (end.y - start.y);
  double x(y) => start.x + dxOverDy! * (y - start.y);

  Vector2? intersect(Line other) {
    final double x1 = start.x, y1 = start.y, x2 = end.x, y2 = end.y;
    final double x3 = other.start.x, y3 = other.start.y;
    final double x4 = other.end.x, y4 = other.end.y;
    final double denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denominator.abs() < kEpsilon) return null;
    final v = Vector2(
      ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)),
      ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)),
    );
    return v / denominator;
  }
}

abstract class LineCondition {
  bool accepts(Line line);
}

class RatioCondition implements LineCondition {
  RatioCondition(this.xRange, this.yRange);
  final Range xRange, yRange;
  @override
  bool accepts(Line line) =>
      xRange.contains(line.xStartRatio) &&
      yRange.contains(line.yStartRatio) &&
      xRange.contains(line.xEndRatio) &&
      yRange.contains(line.yEndRatio);
}

class LengthCondition implements LineCondition {
  LengthCondition(this.minLength);
  final double minLength;
  @override
  bool accepts(Line line) => line.length >= minLength;
}

class DxOverDyCondition implements LineCondition {
  DxOverDyCondition(this.range);
  final Range range;
  @override
  bool accepts(Line line) =>
      !line.isHorizontal && range.contains(line.dxOverDy!);
}

const double _kSlopeDegrees = 30;
const double _kSlopeRadians = _kSlopeDegrees * pi / 180;

class RightSlopeCondition extends DxOverDyCondition {
  RightSlopeCondition() : super(Range(tan(_kSlopeRadians), double.infinity));
}

class LeftSlopeCondition extends DxOverDyCondition {
  LeftSlopeCondition() : super(Range(-double.infinity, -tan(_kSlopeRadians)));
}

class CombinedCondition implements LineCondition {
  CombinedCondition(this.conditions);
  final List<LineCondition> conditions;
  @override
  bool accepts(Line line) => conditions.every((c) => c.accepts(line));
}

class LineFilter {
  static const bool kSaveProto = false;
  static const kSaveFile = '/tmp/line_detection.pb';

  static const double kMinLength = 20.0;
  static const Range kYRatioRange = Range(0.4, 0.95);
  static const Range kLeftXRange = Range(0.0, 0.5);
  static const Range kRightXRange = Range(0.5, 1.0);
  static const Range kGuessXRange = Range(0.3, 0.7);

  static const double kGuessNeighborRatio = 0.01; // 1% of width/height

  // 20% width * 20% height. Or 100 * 2% width * 2% height.
  static const double kMinGuessNeighborWeightSumRatio = 0.04;

  void process(pb.LineDetection detection) {
    if (kSaveProto) {
      File(kSaveFile).writeAsBytesSync(detection.writeToBuffer());
      print('Saved proto to $kSaveFile');
    }

    for (final pbLine in detection.lines) {
      final line = Line(pbLine, detection);
      if (_rightConditions.accepts(line)) {
        _rightLines.add(line);
        final double bottomX = line.x(detection.height);
        _minBottomX ??= bottomX;
        _minBottomX = min(_minBottomX!, bottomX);
      } else if (_leftConditions.accepts(line)) {
        _leftLines.add(line);
        final double bottomX = line.x(detection.height);
        _maxBottomX ??= bottomX;
        _maxBottomX = max(_maxBottomX!, bottomX);
      }
    }

    final xBounds = Range(0, detection.width.toDouble());
    final yBounds = Range(0, detection.height.toDouble());
    for (final l in _leftLines) {
      for (final r in _rightLines) {
        final intersection = l.intersect(r);
        if (intersection != null &&
            xBounds.contains(intersection.x) &&
            yBounds.contains(intersection.y)) {
          _intersections.add(intersection);
          _weights.add(l.length * r.length);
          _weightedX.add(_WeightedDouble(intersection.x, _weights.last));
          _weightedY.add(_WeightedDouble(intersection.y, _weights.last));
        }
      }
    }

    if (_intersections.isNotEmpty) {
      _medianPoint = Vector2(_median(_weightedX), _median(_weightedY));
      _guess(detection);
    }
  }

  void _guess(pb.LineDetection detection) {
    _guessedPoint = null;
    if (_medianPoint == null) return;
    if (!kGuessXRange.contains(_medianPoint!.x / detection.width)) return;
    double neighborWeight = 0;
    for (int i = 0; i < _intersections.length; ++i) {
      final Vector2 diff = _intersections[i] - _medianPoint!;
      if (diff.x.abs() < kGuessNeighborRatio * detection.width &&
          diff.y.abs() < kGuessNeighborRatio * detection.height) {
        neighborWeight += _weights[i] / detection.width / detection.height;
      }
    }
    if (neighborWeight < kMinGuessNeighborWeightSumRatio) return;
    _guessedPoint = _medianPoint;
  }

  /// Guessed vanishing point where the (straight) road points to.
  Vector2? get guessedPoint => _guessedPoint;

  /// List of all intersection bewteen [leftLines] and [rightLines].
  List<Vector2> get intersections => _intersections;

  List<Line> get leftLines => _leftLines;
  List<Line> get rightLines => _rightLines;

  /// The minimum x value for filtered lines at the bottom of the image. Only
  /// valid after calling [process].
  double? get rightBottomX => _minBottomX;
  double? _minBottomX;
  double? get leftBottomX => _maxBottomX;
  double? _maxBottomX;

  double _median(List<_WeightedDouble> list) {
    list.sort();
    final totalWeight = list.fold(0.0, (sum, w) => sum + w.weight);
    final halfWeight = totalWeight / 2;
    double sum = 0;
    for (final w in list) {
      sum += w.weight;
      if (sum >= halfWeight) return w.value;
    }
    return list.last.value;
  }

  final _rightConditions = CombinedCondition([
    LengthCondition(kMinLength),
    RatioCondition(kRightXRange, kYRatioRange),
    RightSlopeCondition(),
  ]);

  final _leftConditions = CombinedCondition([
    LengthCondition(kMinLength),
    RatioCondition(kLeftXRange, kYRatioRange),
    LeftSlopeCondition(),
  ]);

  final List<Line> _leftLines = [];
  final List<Line> _rightLines = [];

  final List<Vector2> _intersections = [];
  final List<double> _weights = [];

  final List<_WeightedDouble> _weightedX = [];
  final List<_WeightedDouble> _weightedY = [];

  Vector2? _medianPoint;
  Vector2? _guessedPoint;
}

class _WeightedDouble implements Comparable<_WeightedDouble> {
  _WeightedDouble(this.value, this.weight);
  final double value, weight;
  bool operator <(_WeightedDouble other) => value < other.value;

  @override
  int compareTo(_WeightedDouble other) => (value - other.value).sign.toInt();
}
