import 'dart:io';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:vector_math/vector_math_64.dart';

const double kEpsilon = 1e-8;

class Range {
  Range(this.min, this.max);
  final double min, max;
  bool contains(double value) => value >= min && value <= max;
}

class Line {
  final Vector2 start, end;
  final pb.Line proto;
  Line(this.proto)
      : start = Vector2(proto.x0, proto.y0),
        end = Vector2(proto.x1, proto.y1);
  Vector2 get mid => (start + end) / 2;
  double get length => (end - start).length;

  bool get isHorizontal => (end.y - start.y).abs() < kEpsilon;
  double get dxOverDy => (end.x - start.x) / (end.y - start.y);
  double x(y) => start.x + dxOverDy * (y - start.y);
}

class LineFilter {
  static const bool kSaveProto = false;
  static const kSaveFile = '/tmp/line_detection.pb';

  List<Line> process(pb.LineDetection detection) {
    if (kSaveProto) {
      File(kSaveFile).writeAsBytesSync(detection.writeToBuffer());
      print('Saved proto to $kSaveFile');
    }

    final List<Line> filtered = [];
    for (final pbLine in detection.lines) {
      final line = Line(pbLine);
      final double xRatio = line.mid.x / detection.width;
      final double yRatio = line.mid.y / detection.height;
      if (!_xRatioRange.contains(xRatio) ||
              !_yRatioRange.contains(yRatio) ||
              line.length < _minLength ||
              line.isHorizontal || // No horizontal lines with undefined dx/dy
              line.dxOverDy < 0 // Only lines from top-left to bottom-right
          ) {
        continue;
      }
      filtered.add(line);
    }
    return filtered;
  }

  final Range _yRatioRange = Range(0.4, 0.8);
  final Range _xRatioRange = Range(0.5, 0.9);
  final double _minLength = 20.0;
}
