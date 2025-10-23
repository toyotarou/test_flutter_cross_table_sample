import 'package:flutter/material.dart';

///
class DiagonalSlashPainter extends CustomPainter {
  ///
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0xFFB0B0B0)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width, size.height), p);
  }

  ///
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
