import 'package:flutter/material.dart';

/// Virtual pages repeat the same items; no duplicate state is stored in cards.
class LoopCarousel extends StatefulWidget {
  final int count;
  final int initialIndex;
  final double height;
  final Widget Function(BuildContext, int) itemBuilder;
  final ValueChanged<int>? onSelected;
  const LoopCarousel({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.height = 190,
    this.onSelected,
  });
  @override
  State<LoopCarousel> createState() => _LoopCarouselState();
}

class _LoopCarouselState extends State<LoopCarousel> {
  late final PageController controller;
  @override
  void initState() {
    super.initState();
    controller = PageController(
      initialPage: widget.count * 10000 + widget.initialIndex,
      viewportFraction: .68,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    child: PageView.builder(
      controller: controller,
      onPageChanged: (page) => widget.onSelected?.call(page % widget.count),
      itemBuilder: (context, page) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final current =
              controller.hasClients && controller.position.haveDimensions
              ? controller.page ?? controller.initialPage.toDouble()
              : controller.initialPage.toDouble();
          final distance = (current - page).abs().clamp(0.0, 1.0).toDouble();
          return Transform.scale(
            scale: 1 - distance * .17,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: Semantics(selected: distance < .5, child: child),
            ),
          );
        },
        child: RepaintBoundary(
          child: widget.itemBuilder(context, page % widget.count),
        ),
      ),
    ),
  );
}
