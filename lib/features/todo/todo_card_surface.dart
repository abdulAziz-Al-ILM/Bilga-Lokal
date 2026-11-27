import 'package:flutter/material.dart';

/// Subtle, static grid. Text retains the theme's normal surface contrast.
class TodoCardSurface extends StatelessWidget {
  final Color color;
  final Widget child;
  const TodoCardSurface({super.key, required this.color, required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(13),
    child: CustomPaint(painter: _Grid(color), child: child),
  );
}

class _Grid extends CustomPainter {
  final Color color;
  _Grid(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: .035),
    );
    final paint = Paint()
      ..color = color.withValues(alpha: .065)
      ..strokeWidth = .6;
    for (double x = 0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Grid oldDelegate) => color != oldDelegate.color;
}
