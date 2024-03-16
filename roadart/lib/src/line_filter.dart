import 'dart:io';
import 'dart:math';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:vector_math/vector_math_64.dart';

const double kEpsilon = 1e-8;

class Range {
  Range(this.min, this.max);
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

  void process(pb.LineDetection detection) {
    if (kSaveProto) {
      File(kSaveFile).writeAsBytesSync(detection.writeToBuffer());
      print('Saved proto to $kSaveFile');
    }

    for (final pbLine in detection.lines) {
      final line = Line(pbLine, detection);
      if (_rightConditions.accepts(line)) {
        _rightLines.add(line);
        _minBottomX = min(_minBottomX, line.x(detection.height));
      } else if (_leftConditions.accepts(line)) {
        _leftLines.add(line);
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
    }
  }

  Vector2? get guessedPoint => _medianPoint;
  List<Vector2> get intersections => _intersections;

  List<Line> get leftLines => _leftLines;
  List<Line> get rightLines => _rightLines;

  /// The minimum x value for filtered lines at the bottom of the image. Only
  /// valid after calling [process].
  double get minBottomX => _minBottomX;
  double _minBottomX = double.infinity;

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

  static const double _kMinLength = 20.0;
  static final Range _yRatioRange = Range(0.4, 0.95);

  final _rightConditions = CombinedCondition([
    LengthCondition(_kMinLength),
    RatioCondition(Range(0.5, 1.0), _yRatioRange),
    RightSlopeCondition(),
  ]);

  final _leftConditions = CombinedCondition([
    LengthCondition(_kMinLength),
    RatioCondition(Range(0.0, 0.5), _yRatioRange),
    LeftSlopeCondition(),
  ]);

  final List<Line> _leftLines = [];
  final List<Line> _rightLines = [];

  final List<Vector2> _intersections = [];
  final List<double> _weights = [];

  final List<_WeightedDouble> _weightedX = [];
  final List<_WeightedDouble> _weightedY = [];

  Vector2? _medianPoint;
}

class _WeightedDouble implements Comparable<_WeightedDouble> {
  _WeightedDouble(this.value, this.weight);
  final double value, weight;
  bool operator <(_WeightedDouble other) => value < other.value;

  @override
  int compareTo(_WeightedDouble other) => (value - other.value).sign.toInt();
}
