import 'dart:math';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:vector_math/vector_math_64.dart';

const double kEpsilon = 1e-8;

class Line {
  late Vector2 start, end;
  final pb.Line pbLine;
  final pb.LineDetection fullDetection;
  Line(this.pbLine, this.fullDetection) {
    if (pbLine.x0 > pbLine.x1) {
      start = Vector2(pbLine.x1, pbLine.y1);
      end = Vector2(pbLine.x0, pbLine.y0);
    } else {
      start = Vector2(pbLine.x0, pbLine.y0);
      end = Vector2(pbLine.x1, pbLine.y1);
    }
  }

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

  @override
  String toString() => '$start -- $end';
}

class LineMerger {
  LineMerger(int width, int height) {
    const double kDistanceRatio = 0.01; // 1% of sqrt(h^2 + w^2)
    _distanceThreshold = sqrt(pow(width, 2) + pow(height, 2)) * kDistanceRatio;
  }

  List<Line> merge(List<Line> lines) {
    final sorted = List<Line>.from(lines)
      ..sort((a, b) => a.start.x.compareTo(b.start.x));
    final List<Line> merged = [];
    for (int i = 0; i < sorted.length; ++i) {
      int end = i + 1;
      while (end < sorted.length && shouldMerge(sorted[end - 1], sorted[end])) {
        ++end;
      }
      final pbLine = pb.Line(
          x0: sorted[i].start.x,
          y0: sorted[i].start.y,
          x1: sorted[end - 1].end.x,
          y1: sorted[end - 1].end.y);
      merged.add(Line(pbLine, sorted[i].fullDetection));
      i = end - 1;
    }
    return merged;
  }

  bool shouldMerge(Line left, Line right) {
    if (left.end.x > right.start.x) {
      return false; // Only merge if the x ranges are disjoint.
    }
    if (left.end.y.compareTo(left.start.y) !=
        right.end.y.compareTo(left.start.y)) {
      return false; // Only merge if the y slope sign is preserved.
    }
    final List<double> distances = [
      _distance(left.start, right),
      _distance(left.end, right),
      _distance(right.start, left),
      _distance(right.end, right),
    ];
    return distances.every((d) => d <= _distanceThreshold);
  }

  static double _distance(Vector2 point, Line line) {
    final Vector2 dir = (line.end - line.start).normalized();
    final Vector2 projection = line.start + dir * (point - line.start).dot(dir);
    return (point - projection).length;
  }

  double _distanceThreshold = 0.0;
}
