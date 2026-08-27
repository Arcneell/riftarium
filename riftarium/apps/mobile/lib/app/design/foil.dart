import 'package:flutter/material.dart';

import 'tokens.dart';

/// Reflet « foil » : une bande claire qui balaie la carte en 7 s, fondue en
/// mode écran, comme `.card-foil` sur le site. Signature visuelle de la
/// collection : une carte que l'on possède brille. Désactivé quand le système
/// demande moins d'animations.
class FoilOverlay extends StatefulWidget {
  const FoilOverlay({
    super.key,
    required this.child,
    this.enabled = true,
    this.intensity = 1,
    this.rainbow = false,
    this.borderRadius = RiftRadius.card,
  });

  final Widget child;
  final bool enabled;

  /// 0 → 1 : opacité de la bande (0.6 pour une carte possédée, 1 pour une foil).
  final double intensity;

  /// Ajoute une teinte prismatique (variantes foil).
  final bool rainbow;
  final double borderRadius;

  @override
  State<FoilOverlay> createState() => _FoilOverlayState();
}

class _FoilOverlayState extends State<FoilOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RiftMotion.foil,
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le ticker ne tourne que si le reflet est réellement peint : sinon un
    // pumpAndSettle (tests) ou un économiseur d'énergie n'en finirait jamais.
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant FoilOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldRun = widget.enabled && !_reduceMotion;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _reduceMotion) return widget.child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_controller.value);
                  // -0.34 → +0.34 de la largeur, comme @keyframes foil.
                  final shift = -0.34 + 0.68 * t;
                  return FractionalTranslation(
                    translation: Offset(shift, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-1, -0.6),
                          end: const Alignment(1, 0.6),
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(
                              alpha: 0.38 * widget.intensity,
                            ),
                            (widget.rainbow
                                    ? RiftColors.hexSoft
                                    : const Color(0xFFD7F2EF))
                                .withValues(alpha: 0.26 * widget.intensity),
                            Colors.transparent,
                          ],
                          stops: const [0.38, 0.47, 0.53, 0.62],
                        ),
                        backgroundBlendMode: BlendMode.screen,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.rainbow)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.16 * widget.intensity,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          RiftColors.fury,
                          RiftColors.order,
                          RiftColors.body,
                          RiftColors.calm,
                          RiftColors.mind,
                          RiftColors.chaos,
                        ],
                      ),
                      backgroundBlendMode: BlendMode.overlay,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
