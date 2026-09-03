import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// La table de jeu est toujours en encre, quel que soit le thème du système :
/// des chiffres clairs sur fond sombre se lisent à un mètre et n'éblouissent
/// personne au-dessus d'un plateau. Les briques de la charte suivent.
Widget gameTheme({required Widget child}) =>
    Theme(data: buildTheme(), child: child);

/// Chronomètre de la partie : `12:04`, ou `1:02:33` au-delà de l'heure.
String formatChrono(Duration elapsed) {
  final seconds = elapsed.inSeconds.clamp(0, 359999);
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  final tail =
      '${minutes.toString().padLeft(2, '0')}:'
      '${rest.toString().padLeft(2, '0')}';
  return hours == 0 ? tail : '$hours:$tail';
}

/// Le score d'un camp : le chiffre en très grand posé sur son voile radial,
/// et (si [target] est donné) ses gemmes de points juste dessous. Le même
/// bloc sert au panneau d'un joueur et au disque partagé d'une équipe : il
/// n'existe qu'ici.
class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    super.key,
    required this.score,
    required this.color,
    this.target,
    this.diameter = 176,
    this.digitSize = 78,
    this.gemSize = 8,
    this.gemPadding = EdgeInsets.zero,
  });

  final int score;
  final Color color;

  /// Score de victoire du mode : donné, les gemmes s'affichent sous le
  /// chiffre. Null, le bloc ne montre que le chiffre.
  final int? target;

  /// Diamètre du voile posé derrière le chiffre.
  final double diameter;
  final double digitSize;
  final double gemSize;

  /// Marge des gemmes : sur un disque étroit, elles ne doivent pas toucher
  /// les bords.
  final EdgeInsetsGeometry gemPadding;

  @override
  Widget build(BuildContext context) {
    final gems = target;
    final digits = _ScoreHalo(
      diameter: diameter,
      child: _BigScore(value: score, color: color, size: digitSize),
    );
    if (gems == null) return digits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        digits,
        const SizedBox(height: 8),
        Padding(
          padding: gemPadding,
          child: ScoreGems(
            score: score,
            target: gems,
            color: color,
            size: gemSize,
          ),
        ),
      ],
    );
  }
}

/// Le chiffre du score : Marcellus, énorme, avec un léger battement à chaque
/// changement pour que le geste se voie de l'autre bout de la table.
class _BigScore extends StatelessWidget {
  const _BigScore({required this.value, required this.color, this.size = 78});

  final int value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: RiftMotion.quick,
      switchInCurve: RiftMotion.ease,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.72, end: 1).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Text(
        '$value',
        key: ValueKey(value),
        style: TextStyle(
          fontFamily: RiftFonts.display,
          fontSize: size,
          height: 1,
          color: RiftColors.ink,
          shadows: [
            // Un halo à la couleur du joueur, doublé d'une ombre encre : le
            // chiffre tient même posé sur la partie claire d'une illustration.
            Shadow(color: color.withValues(alpha: 0.55), blurRadius: 28),
            const Shadow(
              color: RiftColors.night,
              blurRadius: 14,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voile radial local posé derrière le chiffre : l'illustration reste visible
/// partout ailleurs, le score reste lisible au centre.
class _ScoreHalo extends StatelessWidget {
  const _ScoreHalo({required this.child, this.diameter = 176});

  final Widget child;
  final double diameter;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          RiftColors.night.withValues(alpha: 0.55),
          RiftColors.night.withValues(alpha: 0),
        ],
        stops: const [0.35, 1],
      ),
    ),
    child: child,
  );
}

/// Gemmes de score : une par point à marquer, remplies jusqu'au score courant.
/// Lisible d'un coup d'œil : « il lui en reste trois ».
class ScoreGems extends StatelessWidget {
  const ScoreGems({
    super.key,
    required this.score,
    required this.target,
    required this.color,
    this.size = 10,
  });

  final int score;
  final int target;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: size * 0.55,
      runSpacing: size * 0.55,
      children: [
        for (var index = 0; index < target; index++)
          AnimatedContainer(
            duration: RiftMotion.base,
            curve: RiftMotion.ease,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < score ? color : Colors.transparent,
              border: Border.all(
                color: index < score
                    ? color
                    : RiftColors.goldSoft.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: index < score
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: size * 0.8,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Contour opaque autour de l'élément actif : un trait plein à la couleur du
/// joueur, sans transparence ni dégradé — le joueur dont c'est le tour doit se
/// voir de l'autre bout de la table. Seul le halo serré derrière le trait
/// respire ; statique quand le système demande moins de mouvement.
class ActiveGlow extends StatefulWidget {
  const ActiveGlow({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = RiftRadius.md,
    this.color = RiftColors.gold,
  });

  final bool active;
  final Widget child;
  final double borderRadius;

  /// Teinte du liseré : l'or par défaut (sélections), la couleur du joueur
  /// sur la table de jeu.
  final Color color;

  @override
  State<ActiveGlow> createState() => _ActiveGlowState();
}

class _ActiveGlowState extends State<ActiveGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant ActiveGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldRun = widget.active && !_reduceMotion;
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
    if (!widget.active) {
      return _frame(0, widget.child);
    }
    if (_reduceMotion) return _frame(1, widget.child);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          _frame(0.55 + 0.45 * _controller.value, child!),
      child: widget.child,
    );
  }

  Widget _frame(double intensity, Widget child) {
    // Inactif : simple filet discret. Actif : contour de 4 px totalement
    // opaque à la couleur du joueur — jamais de transparence ni de dégradé
    // sur le trait lui-même, il doit se lire d'un coup d'œil sur n'importe
    // quelle illustration. Seul le petit halo derrière respire.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: intensity == 0
              ? RiftColors.gold.withValues(alpha: 0.12)
              : widget.color,
          width: intensity == 0 ? 1 : 4,
        ),
        boxShadow: intensity == 0
            ? null
            : [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35 + 0.4 * intensity),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: child,
    );
  }
}
