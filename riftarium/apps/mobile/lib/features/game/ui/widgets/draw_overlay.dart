import 'package:flutter/material.dart';

import '../../../../app/design/foil.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../data/legends_repository.dart';
import '../../domain/player.dart';

/// Tirage du premier joueur, en plein écran : les légendes défilent au centre
/// comme une roue qui ralentit, puis la gagnante s'agrandit dans un éclat or.
///
/// Plein écran parce qu'à trois ou quatre autour d'une table, un cadre qui
/// s'allume dans une liste passe inaperçu.
class DrawOverlay extends StatelessWidget {
  const DrawOverlay({
    super.key,
    required this.players,
    required this.nameOf,
    required this.animation,
    required this.steps,
    required this.target,
    required this.note,
    required this.onDismiss,
    this.title = 'PREMIER JOUEUR',
    this.resultOf = _defaultResult,
  });

  static String _defaultResult(String name) => '$name commence.';

  final List<Player> players;

  /// Nom saisi dans la configuration (le `Player` porte encore le défaut).
  final String Function(Player player) nameOf;

  /// Avance de la roue, de 0 à 1. `kAlwaysCompleteAnimation` en mouvement
  /// réduit : le résultat s'affiche sans défilement.
  final Animation<double> animation;

  /// Nombre de crans parcourus : trois tours complets puis le siège tiré.
  final int steps;
  final int target;

  /// Rappel des ajustements du premier tour, sous le nom.
  final String note;

  final VoidCallback onDismiss;

  /// Surtitre de la roue : « PREMIER JOUEUR », ou « JOUEUR DÉSIGNÉ » en
  /// tournoi, où le tirage ne désigne pas qui commence mais qui choisit.
  final String title;

  /// Phrase affichée sous la roue une fois le nom tiré.
  final String Function(String name) resultOf;

  static const _itemWidth = 132.0;
  static const _stride = _itemWidth + 26;
  static const _rowHeight = 216.0;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: ColoredBox(
          color: RiftColors.night.withValues(alpha: 0.94),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final progress = Curves.easeOutCubic.transform(animation.value);
                final position = progress * steps;
                final settled = animation.value >= 1;
                final winner = players[target % players.length];
                // Écran court et note longue (chambre magmatique) : le
                // contenu défile au lieu de déborder.
                return LayoutBuilder(
                  builder: (context, viewport) => SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: viewport.maxHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(title, style: text.eyebrow),
                          const SizedBox(height: 26),
                          SizedBox(
                            height: _rowHeight,
                            child: LayoutBuilder(
                              builder: (context, constraints) => _wheel(
                                width: constraints.maxWidth,
                                position: position,
                                settled: settled,
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          AnimatedOpacity(
                            duration: RiftMotion.base,
                            opacity: settled ? 1 : 0,
                            child: Column(
                              children: [
                                Text(
                                  resultOf(nameOf(winner)),
                                  textAlign: TextAlign.center,
                                  style: text.displayLarge.copyWith(
                                    color: RiftColors.goldSoft,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: Text(
                                    note,
                                    textAlign: TextAlign.center,
                                    style: text.small,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Roue horizontale : seuls les crans visibles sont construits, décalés de
  /// leur distance au centre.
  Widget _wheel({
    required double width,
    required double position,
    required bool settled,
  }) {
    final first = position.floor() - 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var index = first; index <= first + 5; index++)
          _slot(
            index: index,
            position: position,
            centre: width / 2,
            settled: settled,
          ),
      ],
    );
  }

  Widget _slot({
    required int index,
    required double position,
    required double centre,
    required bool settled,
  }) {
    final count = players.length;
    final player = players[((index % count) + count) % count];
    final distance = index - position;
    final away = distance.abs();
    final chosen = settled && away < 0.01;
    return Positioned(
      left: centre + distance * _stride - _itemWidth / 2,
      top: 0,
      width: _itemWidth,
      height: _rowHeight,
      child: Opacity(
        opacity: (1 - away * 0.4).clamp(0.18, 1.0),
        child: Transform.scale(
          scale: chosen ? 1.18 : (1 - away * 0.26).clamp(0.5, 1.0),
          child: Center(
            child: _Face(player: player, name: nameOf(player), chosen: chosen),
          ),
        ),
      ),
    );
  }
}

/// Un cran de la roue : la légende du joueur, ou son initiale sur un médaillon
/// à sa couleur quand il n'en a pas choisi.
class _Face extends StatelessWidget {
  const _Face({required this.player, required this.name, required this.chosen});

  final Player player;
  final String name;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final legend = player.legend;
    final glow = chosen
        ? [
            BoxShadow(
              color: RiftColors.gold.withValues(alpha: 0.55),
              blurRadius: 42,
              spreadRadius: 4,
            ),
          ]
        : null;

    final Widget face = legend == null
        ? Container(
            width: 118,
            height: 118,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  player.color.withValues(alpha: 0.85),
                  player.color.withValues(alpha: 0.35),
                ],
              ),
              border: Border.all(
                color: chosen ? RiftColors.gold : RiftColors.goldSoft,
                width: chosen ? 3 : 1.4,
              ),
              boxShadow: glow,
            ),
            child: Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: text.displayLarge.copyWith(
                fontSize: 52,
                color: RiftColors.darkInk,
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RiftRadius.card),
              boxShadow: glow,
            ),
            child: FoilOverlay(
              enabled: chosen,
              rainbow: legendVariantLabel(legend) != null,
              child: CardImage(
                card: legend,
                width: 118,
                thumbWidth: CardArtSize.tile,
              ),
            ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        face,
        const SizedBox(height: 10),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.small.copyWith(
            color: chosen ? RiftColors.goldSoft : null,
          ),
        ),
      ],
    );
  }
}
