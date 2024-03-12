import 'dart:io';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:roadart/src/line_filter.dart';
import 'package:test/test.dart';

void main() {
  test('LineFilter finds curb boundaries', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_2023121012_11001.pb').readAsBytesSync());
    final List<Line> result = filter.process(lineDetection);
    print('filtered ${result.length} lines');
    for (final Line line in result) {
      print('x(${lineDetection.height}) = ${line.x(lineDetection.height)}');
      print('proto = \n${line.proto}\n');
    }
  });

  // TODO TEST horizontal lines
}
