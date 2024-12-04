import 'dart:io';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:roadart/src/line_filter.dart';
import 'package:test/test.dart';

void main() {
  test('LineFilter finds curb boundaries', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_2023121012_11001.pb').readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.rightLines.length, 8);
    expect(filter.rightBottomX, closeTo(840.94, 0.01));
  });

  test('LineFilter ignores horizontal lines', () {
    final lineDetection = pb.LineDetection();
    lineDetection.width = lineDetection.height = 200;
    lineDetection.lines.add(pb.Line(x0: 0, y0: 100, x1: 200, y1: 100));
    final filter = LineFilter()..process(lineDetection);
    expect(filter.rightLines, isEmpty);
  });

  test('LineFilter discards intersection with false left vanishing point', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_comma10k_00008_e_a1fc603d9a8ddfc4.pb')
            .readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.guessedPoint, isNull);
  });

  test('LineFilter finds vanishing point with many horizontal lines', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_comma10k_00189_f_20f59690c1da9379.pb')
            .readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.guessedPoint, isNotNull);
    expect(filter.guessedPoint!.x, closeTo(959.0, 0.1));
    expect(filter.guessedPoint!.y, closeTo(382.9, 0.1));
  });

  test('LineFilter discards median point without enough nearby weights', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_comma10k_00164_e_a1fc603d9a8ddfc4.pb')
            .readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.guessedPoint, isNull);
  });

  test('LineFilter discards median point without nearby intersections', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_comma10k_00345_e_4f0aab72f56d7cd9.pb')
            .readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.guessedPoint, isNull);
  });

  test('LineFilter discards vanishing point with tiny right line', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_comma10k_00040_f_5352b3c0dcecc48d.pb')
            .readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.guessedPoint, isNull);
  });

  test('LineFilter computes bottom x without lines disagreeing vanishing point',
      () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/line_detection_qu_2023121012_1420.pb')
            .readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.rightBottomX, greaterThan(640));
  });

  test('LineFilter computes the guess point using video mask', () {
    final filter = LineFilter();
    final lineDetection = pb.LineDetection.fromBuffer(
        File('test/data/mask_line_detection_2023121012_f2675.pb')
            .readAsBytesSync());
    filter.process(lineDetection);
    expect(filter.guessedPoint, isNotNull);
  });
}
