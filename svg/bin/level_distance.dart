import 'dart:io';
import 'dart:math';

import 'package:tikd/tikd.dart';

double rad(double degrees) => toRadian(degrees);

void main() async {
  final p = Picture();

  // Horizon line
  const double kL = 10;
  final origin = XY(0, 0);
  p.draw(origin >>> XY(kL, 0)
    ..endNode = Node(r'\Large horizon', place: Placement.right()));

  // Screen line
  const double kScreenH = 1;
  const double kHalfFov = 30; // degrees
  final double focal = kScreenH / tan(rad(kHalfFov));
  final screenColor = Color.green % 80 + Color.black;
  p.draw(origin >>> XY(kL, 0), options: [Shift(XY.y(-kScreenH))]);
  final screenLine = XY(focal, 0) >>> XY(focal, -kScreenH)
    ..endNode = Node(r'\Large $h_0$', place: Placement.below());
  p.draw(screenLine, options: [screenColor]);
  final focalLine = origin >>> XY(focal, 0)
    ..midNode = Node(r'\Large $f$', place: Placement.above());
  p.draw(focalLine, options: [Shift(XY.y(0.1))]);

  // Ground line
  const double kGroundH = 3;
  final groundLine = origin >>> XY(kL, 0)
    ..endNode = Node(r'\Large ground', place: Placement.right());
  p.draw(groundLine, options: [Shift(XY.y(-kGroundH))]);
  p.draw(origin >>> XY(kGroundH / tan(rad(kHalfFov)), -kGroundH)
    ..endNode = Node(r'\Large $d_0$', place: Placement.below()));
  final hgLine = origin >>> XY(0, -kGroundH)
    ..midNode = Node(r'\Large $h_g$', place: Placement.left());
  p.draw(hgLine, options: [Shift(XY.x(-0.1))]);

  // Object
  const double kObjH = 2.0 / 3;
  final objColor = Color.blue;
  final double objTan = kObjH / focal;
  final objLine = origin >>> XY(kGroundH / objTan, -kGroundH)
    ..endNode = Node(r'\Large $d_1$', place: Placement.below());
  p.draw(objLine, options: [dashedStyle, objColor]);
  final objH = XY(focal, 0) >>> XY(focal, -kObjH)
    ..midNode = Node(r'\Large $h_1$', place: Placement.right());
  p.draw(objH, options: [objColor, Shift(XY.x(0.05))]);

  // Text
  const double kTextWidth = 6;
  final textLines = [
    r'\Large $f = d_1 \frac{h_1}{h_g} = d_0 \frac{h_0}{h_g}$, ',
    r'$d_1 = d_0 \frac{h_0}{h_1}$',
  ];
  final textNode = Node(textLines.join('\n'),
      place: Placement.below(), options: [TextWidth(kTextWidth, unit: 'cm')]);
  p.draw(Path(XY(kTextWidth / 2, -kGroundH - 1))..endNode = textNode);

  LatexWrapper.fromPicture(p).makeSvgFromDart(Platform.script.path);
}
