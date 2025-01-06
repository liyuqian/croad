import 'dart:io';

import 'package:image/image.dart';
import 'package:roadart/src/patcher.dart';
import 'package:test/test.dart';

void main() {
  group('Patcher', () {
    late Directory tempDir;
    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('patcher_test');
    });

    void testFrame(int index,
        {List<List<int>> positives = const [],
        List<List<int>> negatives = const [],
        bool preservePatched = false}) {
      final String outPath = '${tempDir.path}/patched.png';
      final patcher = Patcher();
      patcher.patch(
          'test/data/qu2023121012_front.mp4.$index.segment.png', outPath);

      final Image patched = decodePng(File(outPath).readAsBytesSync())!;
      Pixel? positivePixel;
      for (final xy in positives) {
        final Pixel pixel = patched.getPixel(xy[0], xy[1]);
        expect(pixel.r + pixel.g + pixel.b, greaterThan(0));
        positivePixel ??= pixel;
        expect(pixel, equals(positivePixel), reason: "positive color mismatch");
      }
      for (final xy in negatives) {
        final Pixel pixel = patched.getPixel(xy[0], xy[1]);
        expect(pixel.r + pixel.g + pixel.b, equals(0),
            reason: '$xy should be black');
      }

      if (preservePatched) {
        File(outPath).copySync('/tmp/patched.png');
        File(outPath).copySync('/tmp/patched_$index.png');
      }
    }

    test(
        'patches a large hole',
        () => testFrame(4310, positives: [
              [164, 321],
              [151, 346],
              [347, 218],
              [446, 224],
              [436, 344],
            ], negatives: [
              [371, 184],
              [510, 199],
              [121, 196],
              [585, 224],
            ]));

    test(
        'patches a large hole in a tilted image',
        () => testFrame(
              4388,
              positives: [
                [229, 200],
                [265, 272],
                [423, 251],
              ],
              negatives: [
                [397, 184],
                [266, 189],
              ],
            ));

    test(
        'patches small holes',
        () => testFrame(5618, positives: [
              [110, 245],
              [192, 221],
              [413, 210],
            ], negatives: [
              [445, 182],
              [488, 167],
            ]));
    test(
        'patches another set of small holes',
        () => testFrame(6058, positives: [
              [153, 275],
              [253, 198],
              [415, 261],
              [209, 320],
            ], negatives: [
              [557, 220],
              [470, 202],
              [97, 196],
            ]));

    test(
        'patches a strange hole',
        () => testFrame(
              3223,
              positives: [
                [194, 295],
                [269, 313],
              ],
              negatives: [
                [534, 197],
                [396, 193],
              ],
            ));
    test(
        'patches the tilted image',
        () => testFrame(3622, positives: [
              [304, 285],
              [348, 321],
              [418, 323],
            ], negatives: [
              [453, 184],
              [116, 202],
            ]));

    test(
        'patches round holes',
        () => testFrame(7052, positives: [
              [266, 281],
              [303, 312],
              [305, 224],
            ], negatives: [
              [424, 207],
              [122, 206]
            ]));
    test(
        'patches multiple colors',
        () => testFrame(7283, positives: [
              [302, 281],
              [325, 222],
            ]));

    test(
        'patches noisy masks',
        () => testFrame(7674, positives: [
              [221, 335],
              [411, 339],
            ], negatives: [
              [471, 194]
            ]));
  });
}
