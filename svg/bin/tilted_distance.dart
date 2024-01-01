import 'dart:io';
import 'dart:math';

import 'package:tikd/tikd.dart';
import 'package:vector_math/vector_math_64.dart';

double rad(double degrees) => toRadian(degrees);

void main() async {
  final p = Picture()..backgroundColor = Color.white;

  // Horizon line
  const double kL = 10;
  final origin = XY(0, 0);
  final o = Coordinate('o');
  p.namePath(Path(origin)..coordinate = o, 'origin');
  p.draw(origin >>> XY(kL, 0)
    ..endNode = Node(r'\Large horizon', place: Placement.right()));

  // Ground line
  const double kGroundH = 3;
  const double kHalfFov = 30; // degrees
  final ground = Coordinate('ground');
  final groundLine = origin >>> XY(kL, 0)
    ..endNode = Node(r'\Large ground', place: Placement.right());
  p.draw(groundLine, options: [Shift(XY.y(-kGroundH))]);

  // FoV and vertical lines
  const String kFovLine = 'fov_line';
  final double d0 = kGroundH / tan(rad(kHalfFov));
  p.draw(origin >>> XY(kGroundH / tan(rad(kHalfFov)), -kGroundH),
      options: [NamePath(kFovLine)]);
  final vertical = origin >>> XY(0, -kGroundH)
    ..coordinate = ground;
  p.draw(vertical, options: [Shift(XY.x(d0)), dashedStyle]);

  // Screen line
  const String kScreenLine = 'screen_line';
  const double kTheta = 10; // degrees
  final d0Coordinate = Coordinate('d0Coordinate');
  p.draw(Path(XY(d0, 0))
    ..coordinate = d0Coordinate
    ..endNode = Node(r'\Large $d_0$', place: Placement.above()));
  p.draw(XY(0, 0) >>> XY.polar(-90 - kTheta, kGroundH),
      options: [Shift(XY.x(d0)), NamePath(kScreenLine)]);

  // h0
  final screenEnd = Intersection(kFovLine, kScreenLine, 'screen_end');
  final h0Coordinate = Coordinate('h0Coordinate');
  final h0 = Path(screenEnd.position)
    ..coordinate = h0Coordinate
    ..endNode = Node(r'\Large $\lambda h_0$', place: Placement.left());
  p.draw(h0, options: [screenEnd]);

  // h1
  const String kObjLineName = 'obj_line';
  const double kObjAngle = 20; // degrees
  final d1Coordinate = Coordinate('d1Coordinate');
  final objLine = origin >>> XY(kGroundH / tan(rad(kObjAngle)), -kGroundH)
    ..coordinate = d1Coordinate
    ..endNode = Node(r'\Large $d_1$', place: Placement.below());
  p.draw(objLine, options: [NamePath(kObjLineName)]);
  final objEnd = Intersection(kScreenLine, kObjLineName, 'obj_end');
  final h1 = Path(objEnd.position)
    ..endNode = Node(r'\Large $\lambda h_1$', place: Placement.right());
  p.draw(h1, options: [objEnd]);

  // f and \xi
  final double xi = d0 * sin(rad(kTheta));
  final xiVec = Vector2(d0 - xi * sin(rad(kTheta)), -xi * cos(rad(kTheta)));
  final fCoordinate = Coordinate('fCoordinate');
  final fLine = origin >>> XY.vec(xiVec)
    ..midNode = Node(r'\Large $f$', place: Placement.right(by: 30))
    ..coordinate = fCoordinate;
  p.draw(fLine, options: [Color.red, dashedStyle]);
  p.draw(Path(fCoordinate)
    ..endNode = Node(r'\Large $\xi$', place: Placement.aboveLeft(by: 4)));

  // Angles
  p.drawAngle(r'$\theta$', fCoordinate, o, d0Coordinate,
      radiusCm: 2, eccentricity: 0.8);
  p.drawAngle(r'$\alpha_1 - \theta$', d1Coordinate, o, fCoordinate,
      radiusCm: 4, eccentricity: 0.8);
  p.drawAngle(r'$\alpha_0 - \alpha_1$', h0Coordinate, o, d1Coordinate,
      radiusCm: 4.5, eccentricity: 0.85);
  p.drawAngle('', o, fCoordinate, d0Coordinate, radiusCm: 0.2, isRight: true);
  p.drawAngle('', d0Coordinate, ground, d1Coordinate,
      radiusCm: 0.2, isRight: true);

  LatexWrapper.fromPicture(p).makeSvgFromDart(Platform.script.path);
}
