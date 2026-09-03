import 'package:flutter/material.dart';

import 'tokens.dart';

/// Squelette de chargement : surface nuit traversée d'un reflet lent. Prend
/// la place que son parent lui donne (il remplace un visuel en attente).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.borderRadius = RiftRadius.sm});

  final double borderRadius;

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
    const colors = [
      RiftColors.paper2,
      RiftColors.shimmerGlow,
      RiftColors.paper2,
    ];
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: reduce
          ? const ColoredBox(color: RiftColors.paper2)
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1 + 2 * _controller.value * 1.5, 0),
                    end: Alignment(1 + 2 * _controller.value * 1.5, 0),
                    colors: colors,
                  ),
                ),
              ),
            ),
    );
  }
}
