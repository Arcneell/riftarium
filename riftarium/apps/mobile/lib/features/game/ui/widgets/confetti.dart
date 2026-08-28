import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Pluie de confettis de fin de manche. Dessinée à la main (`CustomPainter`) :
/// une centaine de rectangles et de losanges qui tombent, tournent et dérivent,
/// aux couleurs du vainqueur. Rien ne se peint quand le système demande moins
/// de mouvement : l'écran de victoire se suffit alors à lui-même.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({
    super.key,
    required this.colors,
    this.burst = 0,
    this.count = 110,
  });

  /// Couleurs des domaines du vainqueur, complétées d'or et de parchemin.
  final List<Color> colors;

  /// Incrémenter cette valeur relance une pluie (bouton « Encore ! »).
  final int burst;

  final int count;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<ConfettiFlake> _flakes;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _flakes = _makeFlakes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_reduceMotion && !_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.burst != oldWidget.burst && !_reduceMotion) {
      setState(() => _flakes = _makeFlakes());
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ConfettiFlake> _makeFlakes() {
    // Semence tirée de la rafale : deux pluies ne tombent jamais pareil.
    final random = Random(widget.burst * 7919 + 17);
    final palette = widget.colors.isEmpty
        ? const [RiftColors.gold, RiftColors.paper]
        : widget.colors;
    return [
      for (var index = 0; index < widget.count; index++)
        ConfettiFlake(
          x: random.nextDouble(),
          y: -random.nextDouble() * 0.6 - 0.05,
          fall: 0.85 + random.nextDouble() * 0.75,
          drift: (random.nextDouble() - 0.5) * 0.4,
          sway: random.nextDouble() * 2 * pi,
          spin: (random.nextDouble() - 0.5) * 10,
          size: 6 + random.nextDouble() * 8,
          diamond: random.nextBool(),
          color: palette[random.nextInt(palette.length)],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: ConfettiPainter(progress: _controller, flakes: _flakes),
        size: Size.infinite,
      ),
    );
  }
}

/// Un confetti : position de départ, vitesse de chute, dérive et rotation.
class ConfettiFlake {
  const ConfettiFlake({
    required this.x,
    required this.y,
    required this.fall,
    required this.drift,
    required this.sway,
    required this.spin,
    required this.size,
    required this.diamond,
    required this.color,
  });

  final double x;
  final double y;
  final double fall;
  final double drift;
  final double sway;
  final double spin;
  final double size;
  final bool diamond;
  final Color color;
}

/// Peint la pluie à l'instant `progress`. Repeint sur le contrôleur, jamais
/// sur `shouldRepaint` : le rendu suit l'animation image par image.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.progress, required this.flakes})
    : super(repaint: progress);

  final Animation<double> progress;
  final List<ConfettiFlake> flakes;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0) return;
    // Sortie en fondu sur le dernier quart : les confettis s'effacent au lieu
    // de disparaître d'un coup.
    final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final flake in flakes) {
      // Chute accélérée (gravité) et balancement latéral.
      final y = flake.y + flake.fall * t + 0.55 * t * t;
      if (y < -0.1 || y > 1.25) continue;
      final x = flake.x + flake.drift * t + 0.02 * sin(flake.sway + t * 6);
      final center = Offset(x * size.width, y * size.height);
      paint.color = flake.color.withValues(alpha: fade.clamp(0, 1));

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(flake.sway + flake.spin * t);
      final half = flake.size / 2;
      if (flake.diamond) {
        canvas.drawPath(
          Path()
            ..moveTo(0, -half)
            ..lineTo(half * 0.7, 0)
            ..lineTo(0, half)
            ..lineTo(-half * 0.7, 0)
            ..close(),
          paint,
        );
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: flake.size,
            height: flake.size * 0.55,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.flakes != flakes;
}

/// Palette d'une pluie : les domaines du vainqueur, l'or et le parchemin.
List<Color> confettiPalette(Iterable<String> domains) {
  final colors = <Color>[
    RiftColors.gold,
    RiftColors.goldSoft,
    RiftColors.paper,
  ];
  for (final domain in domains) {
    final color = RiftColors.domain(domain);
    if (color != RiftColors.muted) colors.add(color);
  }
  return colors;
}
