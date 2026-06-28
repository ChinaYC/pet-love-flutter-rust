import 'package:flutter/material.dart';
import '../../../../../theme/theme_provider.dart';

class InventoryItemSkeleton extends StatefulWidget {
  final bool isWideLayout;

  const InventoryItemSkeleton({
    super.key,
    this.isWideLayout = false,
  });

  @override
  State<InventoryItemSkeleton> createState() => _InventoryItemSkeletonState();
}

class _InventoryItemSkeletonState extends State<InventoryItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final baseColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final highlightColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.8);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                (_animation.value - 0.5).clamp(0, 1),
                _animation.value.clamp(0, 1),
                (_animation.value + 0.5).clamp(0, 1),
              ],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.isWideLayout
          ? _buildWideSkeleton(context)
          : _buildCompactSkeleton(context),
    );
  }

  Widget _buildCompactSkeleton(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(color: Colors.white),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(width: double.infinity, height: 12),
                  const SizedBox(height: 4),
                  _skeletonBox(width: 60, height: 10),
                  const Spacer(),
                  _skeletonBox(width: 40, height: 14, radius: 4),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _skeletonBox(width: 30, height: 10),
                      _skeletonBox(width: 40, height: 9),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _skeletonBox(width: 50, height: 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideSkeleton(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _skeletonBox(width: 150, height: 22),
                  const SizedBox(height: 8),
                  _skeletonBox(width: 200, height: 14),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skeletonBox(width: 30, height: 12),
                          const SizedBox(height: 4),
                          _skeletonBox(width: 60, height: 18),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _skeletonBox(width: 30, height: 12),
                          const SizedBox(height: 4),
                          _skeletonBox(width: 60, height: 18),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _skeletonBox(width: 70, height: 30, radius: 10),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({
    required double width,
    required double height,
    double radius = 2,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
