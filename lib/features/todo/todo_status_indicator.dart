import 'package:flutter/material.dart';

/// Only this small badge animates. Reduced-motion and completed states are static.
class TodoStatusIndicator extends StatefulWidget {
  final Color color;
  final int interval;
  final bool overdue;
  final bool completed;
  const TodoStatusIndicator({
    super.key,
    required this.color,
    required this.interval,
    required this.overdue,
    this.completed = false,
  });
  @override
  State<TodoStatusIndicator> createState() => _TodoStatusIndicatorState();
}

class _TodoStatusIndicatorState extends State<TodoStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 1);
  }

  void _sync() {
    if (_reduceMotion || widget.completed || widget.interval <= 0) {
      _controller.stop();
      _controller.value = 1;
    } else {
      _controller.duration = Duration(milliseconds: widget.interval);
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant TodoStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interval != widget.interval ||
        oldWidget.completed != widget.completed) {
      _sync();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: FadeTransition(
      opacity: Tween<double>(begin: .60, end: 1).animate(_controller),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          border: widget.overdue
              ? Border.all(color: const Color(0xFFB6BCC4), width: 1.5)
              : null,
        ),
        child: widget.completed
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 21)
            : widget.overdue
            ? const CustomPaint(painter: _SkullPainter())
            : const Icon(Icons.circle, color: Colors.white, size: 7),
      ),
    ),
  );
}

// A vector skull stays legible even on devices without the skull emoji font.
class _SkullPainter extends CustomPainter {
  const _SkullPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 30, size.height / 30);
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF17191C);
    canvas.drawOval(const Rect.fromLTWH(7, 6, 16, 15), white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 17, 10, 7),
        const Radius.circular(2),
      ),
      white,
    );
    canvas.drawCircle(const Offset(11.5, 13.5), 2.5, dark);
    canvas.drawCircle(const Offset(18.5, 13.5), 2.5, dark);
    canvas.drawPath(
      Path()
        ..moveTo(15, 16)
        ..lineTo(13.5, 19)
        ..lineTo(16.5, 19)
        ..close(),
      dark,
    );
    dark.strokeWidth = 1;
    canvas.drawLine(const Offset(13, 21), const Offset(13, 24), dark);
    canvas.drawLine(const Offset(17, 21), const Offset(17, 24), dark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SkullPainter oldDelegate) => false;
}
