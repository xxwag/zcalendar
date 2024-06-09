import 'dart:math';
import 'package:flutter/material.dart';

class GlitterParticle {
  Offset position;
  double radius;
  Color color;
  double opacity;
  double velocityY;
  Shape shape;

  GlitterParticle({
    required this.position,
    required this.radius,
    required this.color,
    required this.opacity,
    required this.velocityY,
    required this.shape,
  });
}

enum Shape { circle, square, triangle }

class CursorPainter extends CustomPainter {
  final List<GlitterParticle> particles;

  CursorPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      paint.color = particle.color.withOpacity(particle.opacity);
      switch (particle.shape) {
        case Shape.circle:
          _drawCircle(canvas, particle.position, particle.radius, paint);
          break;
        case Shape.square:
          _drawSquare(canvas, particle.position, particle.radius, paint);
          break;
        case Shape.triangle:
          _drawTriangle(canvas, particle.position, particle.radius, paint);
          break;
      }
    }
  }

  void _drawCircle(Canvas canvas, Offset position, double radius, Paint paint) {
    canvas.drawCircle(position, radius, paint);
  }

  void _drawSquare(Canvas canvas, Offset position, double radius, Paint paint) {
    canvas.drawRect(
      Rect.fromCenter(center: position, width: radius * 2, height: radius * 2),
      paint,
    );
  }

  void _drawTriangle(
      Canvas canvas, Offset position, double radius, Paint paint) {
    final path = Path();
    path.moveTo(position.dx, position.dy - radius);
    path.lineTo(position.dx + radius, position.dy + radius);
    path.lineTo(position.dx - radius, position.dy + radius);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class CursorPainterWidget extends StatefulWidget {
  final ValueNotifier<Offset?> cursorPositionNotifier;

  const CursorPainterWidget({
    super.key,
    required this.cursorPositionNotifier,
  });

  @override
  CursorPainterWidgetState createState() => CursorPainterWidgetState();
}

class CursorPainterWidgetState extends State<CursorPainterWidget>
    with SingleTickerProviderStateMixin {
  final List<GlitterParticle> _particles = [];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    widget.cursorPositionNotifier.addListener(_updateCursorPosition);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateParticles);
    _controller.repeat();
  }

  @override
  void dispose() {
    widget.cursorPositionNotifier.removeListener(_updateCursorPosition);
    _controller.dispose();
    super.dispose();
  }

  void _updateCursorPosition() {
    final position = widget.cursorPositionNotifier.value;
    if (position != null) {
      setState(() {
        for (int i = 0; i < 5; i++) {
          _particles.add(GlitterParticle(
            position: position,
            radius: Random().nextDouble() * 3 + 2,
            color: _randomGlitterColor(),
            opacity: 1.0,
            velocityY: Random().nextDouble() * 2 + 1,
            shape: Shape
                .values[Random().nextInt(Shape.values.length)], // Random shape
          ));
        }
      });
    }
  }

  Color _randomGlitterColor() {
    const List<Color> glitterColors = [
      Color(0xFFFFF9C4), // Light Yellow
      Color(0xFFFFF59D), // Yellow
      Color(0xFFFFF176), // Darker Yellow
      Color(0xFFFFEE58), // Golden Yellow
      Color(0xFFFFEB3B), // Bright Yellow
    ];
    return glitterColors[Random().nextInt(glitterColors.length)];
  }

  void _updateParticles() {
    setState(() {
      for (int i = 0; i < _particles.length; i++) {
        _particles[i].position =
            _particles[i].position.translate(0, _particles[i].velocityY);
        _particles[i].opacity -= 0.02;
        if (_particles[i].opacity <= 0) {
          _particles.removeAt(i);
          i--;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CursorPainter(particles: _particles),
      child: Container(),
    );
  }
}
