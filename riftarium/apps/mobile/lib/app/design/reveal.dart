import 'package:flutter/material.dart';

import 'tokens.dart';

/// Révélation à l'apparition : fondu + légère montée, décalée selon `index`
/// pour qu'une grille se déploie en cascade (équivalent de `v-reveal`).
/// Ne rejoue pas au défilement : une fois vue, la tuile reste en place.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStaggered = 12,
    this.offset = 14,
  });

  final Widget child;
  final int index;

  /// Au-delà de ce rang, plus de décalage : les tuiles chargées plus tard
  /// (pagination) apparaissent sans attendre.
  final int maxStaggered;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RiftMotion.slow,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: RiftMotion.ease,
  );

  @override
  void initState() {
    super.initState();
    final rank = widget.index.clamp(0, widget.maxStaggered);
    Future<void>.delayed(RiftMotion.stagger * rank, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Mise à l'échelle au toucher (0.97) : retour tactile des tuiles et boutons.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: RiftMotion.quick,
        curve: RiftMotion.ease,
        child: widget.child,
      ),
    );
  }
}
