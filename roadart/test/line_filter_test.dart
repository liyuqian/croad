import 'dart:io';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:roadart/src/line_filter.dart';
import 'package:test/test.dart';

void main() {
  test('LineFilter finds curb boundaries', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_2023121012_11001.pb').readAsBytesSync());
    final List<Line> filtered = filter.process(lineDetection);
    expect(filtered.length, 8);
    expect(filter.minBottomX, closeTo(840.94, 0.01));
  });

  test('LineFilter ignores horizontal lines', () {
    final lineDetection = pb.LineDetection();
    lineDetection.width = lineDetection.height = 200;
    lineDetection.lines.add(pb.Line(x0: 0, y0: 100, x1: 200, y1: 100));
    final List<Line> result = LineFilter().process(lineDetection);
    expect(result, isEmpty);
  });
}
