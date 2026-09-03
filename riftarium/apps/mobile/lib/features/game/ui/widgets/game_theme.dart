import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// La table de jeu est toujours en encre, quel que soit le thème du système :
/// des chiffres clairs sur fond sombre se lisent à un mètre et n'éblouissent
/// personne au-dessus d'un plateau. Les briques de la charte suivent.
Widget gameTheme({required Widget child}) =>
    Theme(data: buildTheme(Brightness.dark), child: child);

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
