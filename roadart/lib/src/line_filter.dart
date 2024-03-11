import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:vector_math/vector_math.dart';

class Range {
  Range(this.min, this.max);
  final double min, max;
  bool contains(double value) => value >= min && value <= max;
}

class Line {
  Line(pb.Line pbLine)
      : start = Vector2(pbLine.x0, pbLine.y0),
        end = Vector2(pbLine.x1, pbLine.y1);
  Vector2 get mid => (start + end) / 2;
  double get length => (end - start).length;
  final Vector2 start, end;
}

class LineFilter {
  List<pb.Line> filter(pb.LineDetection detection) {
    final List<pb.Line> filtered = [];
    for (final pbLine in detection.lines) {
      final line = Line(pbLine);
      final double xRatio = line.mid.x / detection.width;
      final double yRatio = line.mid.y / detection.height;
      if (!_xRatioRange.contains(xRatio) ||
          !_yRatioRange.contains(yRatio) ||
          line.length < _minLength) {
        continue;
      }
      filtered.add(pbLine);
    }
    return filtered;
  }

  final Range _yRatioRange = Range(0.4, 0.8);
  final Range _xRatioRange = Range(0.5, 0.9);
  final double _minLength = 20.0;
}
