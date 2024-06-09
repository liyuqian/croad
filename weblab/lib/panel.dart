import 'dart:ui';

import 'package:flutter/material.dart';

const int kImageWidth = 640;
const int kImageHeight = 360;

class Panel extends StatefulWidget {
  const Panel({super.key});

  @override
  State<Panel> createState() => _PanelState();
}

class _PanelState extends State<Panel> {
  final List<Offset> _keypoints = [];

  @override
  Widget build(BuildContext context) {
    final image = Image.asset('test.jpg', gaplessPlayback: true);
    final customPaint = CustomPaint(
        size: Size(kImageWidth.toDouble(), kImageHeight.toDouble()),
        painter: _KeypointPainter(_keypoints));
    final gesture = GestureDetector(
      child: Stack(children: [image, customPaint]),
      onTapDown: (TapDownDetails details) => setState(() {
        _keypoints.add(details.localPosition);
      }),
    );
    final clearButton = ElevatedButton(
      child: const Text('Clear Points'),
      onPressed: () => setState(() => _keypoints.clear()),
    );
    return Column(children: [
      gesture,
      Padding(padding: const EdgeInsets.all(10), child: clearButton),
    ]);
  }
}

class _KeypointPainter extends CustomPainter {
  final List<Offset> keypoints;

  _KeypointPainter(this.keypoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10;
    canvas.drawPoints(PointMode.points, keypoints, paint);
    // TODO: implement paint
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
