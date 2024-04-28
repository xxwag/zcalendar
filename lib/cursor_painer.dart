import 'package:flutter/material.dart';

class CursorPainter extends CustomPainter {
  final Offset? cursorPosition;
  final double radius;
  final Color color;

  CursorPainter(
      {this.cursorPosition, this.radius = 20.0, this.color = Colors.red});

  @override
  void paint(Canvas canvas, Size size) {
    if (cursorPosition != null) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(cursorPosition!, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CursorPainter oldDelegate) {
    return oldDelegate.cursorPosition != cursorPosition;
  }
}
