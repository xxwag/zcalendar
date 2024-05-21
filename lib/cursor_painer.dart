import 'package:flutter/material.dart';

class CursorPainter extends CustomPainter {
  final Offset? cursorPosition;
  final double radius;
  final Color color;

  CursorPainter({
    this.cursorPosition,
    this.radius = 20.0,
    this.color = Colors.red,
  });

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
    return oldDelegate.cursorPosition != cursorPosition ||
        oldDelegate.radius != radius ||
        oldDelegate.color != color;
  }
}

class CursorPainterWidget extends StatelessWidget {
  final Offset cursorPosition;
  final double radius;
  final Color color;

  const CursorPainterWidget({
    Key? key,
    required this.cursorPosition,
    required this.radius,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: CursorPainter(
            cursorPosition: cursorPosition,
            radius: radius,
            color: color,
          ),
        ),
      ),
    );
  }
}
