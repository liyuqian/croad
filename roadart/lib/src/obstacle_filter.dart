import 'dart:io';

import 'package:roadart/proto/label.pb.dart' as pb;
import 'package:roadart/src/line_filter.dart';
import 'package:vector_math/vector_math_64.dart';

class ObstacleFilter {
  static const kRelatedTypes = ['car', 'truck', 'pedestrian'];

  // Ego car
  static const double kInvalidBottomRatio = 60.0 / 360;

  final Set<String> allTypes = {};

  ObstacleFilter(this._out, LineFilter lineFilter)
      : vanishingPoint = lineFilter.guessedPoint,
        rightBottomX = lineFilter.rightBottomX;

  final IOSink _out;

  final Vector2? vanishingPoint;
  final double? rightBottomX;

  pb.Obstacle? findClosestObstacle(pb.LineDetection detection) {
    pb.Obstacle? closest;
    for (final obstacle in detection.obstacles) {
      allTypes.add(obstacle.label);
      if (!kRelatedTypes.contains(obstacle.label)) {
        continue;
      }
      final double rThreshold =
          vanishingPoint == null ? 0.5 : vanishingPoint!.x / detection.width;
      if (obstacle.r < rThreshold) {
        continue; // Ignore obstacles on the left side
      }
      if (obstacle.b >= 1.0 - kInvalidBottomRatio) {
        continue; // Ignore ego car
      }
      if (vanishingPoint != null && rightBottomX != null) {
        final bottomRight = Vector2(rightBottomX!, detection.height.toDouble());
        final Vector2 v2road = bottomRight - vanishingPoint!;
        final obsBottomLeft = Vector2(
            obstacle.l * detection.width, obstacle.b * detection.height);
        final Vector2 v2obs = obsBottomLeft - vanishingPoint!;
        if (v2obs.cross(v2road) > 0) {
          _out.writeln('Ignore outside ${obstacle.label} at $obsBottomLeft');
          continue;
        }
      }
      if (closest == null || closest.b < obstacle.b) {
        closest = obstacle;
      }
    }
    _out.writeln('All obstacle types: $allTypes');
    return closest;
  }
}
