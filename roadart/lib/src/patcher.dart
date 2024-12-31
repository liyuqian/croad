import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart';

// Patch the holes in the segmentation mask
class Patcher {
  void patch(String inPath, String outPath) {
    final Uint8List inBytes = File(inPath).readAsBytesSync();
    final Image mask = decodePng(inBytes)!;

    final colorCount = HashMap<Color, int>();
    final xToMinY = HashMap<int, int>();
    final xToMaxY = HashMap<int, int>();
    final yToMinX = HashMap<int, int>();
    final yToMaxX = HashMap<int, int>();

    final int w = mask.width;
    final int h = mask.height;
    Color? positiveColor;
    int maxPositiveCount = 0;
    for (int x = 0; x < w; ++x) {
      for (int y = 0; y < h; ++y) {
        final Color c = mask.getPixel(x, y);
        colorCount[c] = (colorCount[c] ?? 0) + 1;
        if ((c.r + c.g + c.b) > 0) {
          xToMinY[x] = min(xToMinY[x] ?? h, y);
          xToMaxY[x] = max(xToMaxY[x] ?? 0, y);
          yToMinX[y] = min(yToMinX[y] ?? w, x);
          yToMaxX[y] = max(yToMaxX[y] ?? 0, x);
          if (colorCount[c]! > maxPositiveCount) {
            positiveColor = c;
          }
        }
      }
    }

    if (positiveColor == null) {
      File(outPath).writeAsBytesSync(inBytes);
      return;
    }

    for (int x = 0; x < w; ++x) {
      for (int y = xToMinY[x] ?? h; y <= (xToMaxY[x] ?? 0); ++y) {
        mask.setPixel(x, y, positiveColor);
      }
    }

    // Do not fill the horizontal gap on the top part to preserve road shapes.
    const kTopRatioWithoutHorizontalFilling = 0.7;
    final int horizontalTopY = (h * kTopRatioWithoutHorizontalFilling).round();
    for (int y = horizontalTopY; y < h; ++y) {
      for (int x = yToMinX[y] ?? w; x <= (yToMaxX[y] ?? 0); ++x) {
        mask.setPixel(x, y, positiveColor);
      }
    }

    File(outPath).writeAsBytesSync(encodePng(mask));
  }
}
