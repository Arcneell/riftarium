import 'package:flutter/material.dart';

import 'tokens.dart';

/// Squelette de chargement : surface parchemin traversée d'un reflet lent.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = RiftRadius.sm,
    this.child,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Widget? child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? RiftColors.darkPaper2 : RiftColors.paper2;
    final glow = dark
        ? RiftColors.darkPaper2.withValues(alpha: 0.4)
        : const Color(0xFFFDFAF2);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: reduce
            ? ColoredBox(color: base, child: widget.child)
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1 + 2 * _controller.value * 1.5, 0),
                      end: Alignment(1 + 2 * _controller.value * 1.5, 0),
                      colors: [base, glow, base],
                    ),
                  ),
                  child: child,
                ),
                child: widget.child,
              ),
      ),
    );
  }
}
