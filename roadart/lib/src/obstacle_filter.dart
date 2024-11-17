import 'dart:io';

import 'package:roadart/proto/label.pb.dart' as pb;

class ObstacleFilter {
  static const kRelatedTypes = ['car', 'truck', 'pedestrian'];

  // Ego car
  static const double kInvalidBottomRatio = 60.0 / 360;

  final Set<String> allTypes = {};

  ObstacleFilter(this._out);
  final IOSink _out;

  pb.Obstacle? findClosestObstacle(pb.LineDetection detection) {
    pb.Obstacle? closest;
    for (final obstacle in detection.obstacles) {
      allTypes.add(obstacle.label);
      if (!kRelatedTypes.contains(obstacle.label)) {
        continue;
      }
      if (obstacle.r < 0.5) {
        continue; // Ignore obstacles on the left side
      }
      if (obstacle.b >= 1.0 - kInvalidBottomRatio) {
        continue;
      }
      // TODO NEXT: filter ego vehicle (large b and center (l, r))
      if (closest == null || closest.b < obstacle.b) {
        closest = obstacle;
      }
    }
    _out.writeln('All obstacle types: $allTypes');
    return closest;
  }
}
