import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/design/banners.dart';
import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../../cards/domain/card.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_mode.dart';
import '../../domain/game_state.dart';
import '../../domain/player.dart';
import 'game_theme.dart';

/// Panneau d'un joueur : sa légende en fond, son nom, son score en très grand,
/// ses gemmes de points et sa réserve d'XP.
///
/// La moitié haute compte un point de plus, la moitié basse un de moins :
/// deux cibles énormes, atteignables sans regarder. L'appui long ouvre sa
/// feuille (exténuation, nom, légende).
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({
    super.key,
    required this.state,
    required this.player,
    required this.onAdd,
    required this.onRemove,
    required this.onSheet,
    required this.onAddXp,
    required this.onSpendXp,
    this.showScore = true,
  });

  final GameState state;
  final Player player;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback? onSheet;
  final VoidCallback onAddXp;
  final VoidCallback onSpendXp;

  /// Faux en 2c2 : le score est porté par le disque partagé de l'équipe.
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final active = state.activePlayer.id == player.id;
    final color = player.color;
    return ActiveGlow(
      active: active,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RiftRadius.md),
        // Le panneau s'adapte à sa place : plein écran en duel, un quart
        // d'écran à quatre, un sixième de largeur en 2c2. Tout se met à
        // l'échelle plutôt que de déborder — la barre d'XP en premier, elle
        // doit rester visible et tapable quelle que soit la taille.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final compact = width < 190 || height < 300;
            final scoreSize = (height * 0.24).clamp(38.0, 78.0);
            final haloSize = (scoreSize * 2.3).clamp(
              76.0,
              width < 176 + 12 ? width - 12 : 176.0,
            );
            final xpHeight = compact ? 32.0 : 38.0;
            final showGems = height >= 250;
            return Stack(
              fit: StackFit.expand,
              children: [
                _Backdrop(player: player, color: color),
                // Zones tactiles : elles occupent tout le panneau, le contenu
                // est posé par-dessus sans intercepter les touchers.
                Column(
                  children: [
                    Expanded(
                      child: _TapZone(
                        icon: Icons.add,
                        align: Alignment.centerRight,
                        onTap: onAdd,
                        onLongPress: onSheet,
                      ),
                    ),
                    Expanded(
                      child: _TapZone(
                        icon: Icons.remove,
                        align: Alignment.centerRight,
                        onTap: onRemove,
                        onLongPress: onSheet,
                      ),
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 8 : 12,
                      compact ? 8 : 10,
                      compact ? 8 : 12,
                      // La colonne s'arrête au-dessus de la barre d'XP : plus
                      // aucun chevauchement possible, quelle que soit la taille.
                      xpHeight + 14,
                    ),
                    child: Column(
                      children: [
                        _Identity(
                          player: player,
                          state: state,
                          compact: compact,
                        ),
                        if (showScore)
                          Expanded(
                            child: Center(
                              child: ScoreHalo(
                                diameter: haloSize,
                                child: BigScore(
                                  value: state.scoreOf(player),
                                  color: color,
                                  size: scoreSize,
                                ),
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (showScore && showGems)
                          ScoreGems(
                            score: state.scoreOf(player),
                            target: state.mode.victoryScore,
                            color: color,
                            size: compact ? 7 : 10,
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: compact ? 6 : 10,
                  right: compact ? 6 : 10,
                  bottom: compact ? 6 : 8,
                  child: XpBar(
                    xp: state.xpOf(player),
                    color: color,
                    height: xpHeight,
                    onAdd: onAddXp,
                    onSpend: onSpendXp,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fond d'un panneau : l'art de la légende, à peine flouté et cadré haut pour
/// qu'on reconnaisse le champion du premier coup d'œil. Le voile encre reste
/// léger — c'est le halo local derrière le chiffre (voir [PlayerPanel]) qui
/// garantit la lecture du score, pas un assombrissement général qui noierait
/// l'illustration.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.player, required this.color});

  final Player player;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final legend = player.legend;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Sans légende, le panneau garde sa couleur : un dégradé radial à la
        // teinte du joueur, assez marqué pour qu'on repère sa place.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.45),
              radius: 1.1,
              colors: [
                color.withValues(alpha: legend == null ? 0.42 : 0.24),
                RiftColors.night.withValues(alpha: 0.96),
              ],
            ),
          ),
        ),
        if (legend != null)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: LegendArt(card: legend),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  RiftColors.night.withValues(alpha: 0.25),
                  RiftColors.night.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Illustration d'une légende recadrée pour un panneau : `cover` aligné haut
/// (le visage plutôt que le texte de la carte), en résolution `detail` pour
/// que le flou ne fasse pas ressortir les pixels.
///
/// `CardImage` impose le ratio 5/7 d'une carte et un squelette animé : ni l'un
/// ni l'autre ne conviennent à un fond plein cadre.
class LegendArt extends StatelessWidget {
  const LegendArt({super.key, required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context) {
    final url = card.imageUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return CachedNetworkImage(
      imageUrl: cardThumb(url, width: CardArtSize.zoom),
      cacheManager: riftImageCache,
      fit: BoxFit.cover,
      // Le visage du champion occupe le tiers supérieur de la carte.
      alignment: const Alignment(0, -0.72),
      memCacheWidth: CardArtSize.zoom,
      fadeInDuration: RiftMotion.base,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => const SizedBox.shrink(),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.player,
    required this.state,
    this.compact = false,
  });

  final Player player;
  final GameState state;

  /// Panneau serré (2c2, quatre joueurs sur petit écran) : vignette et nom de
  /// légende s'effacent, le nom du joueur garde la place.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final legend = player.legend;
    return Row(
      children: [
        if (legend != null && !compact) ...[
          SizedBox(
            width: 26,
            child: CardImage(card: legend, thumbWidth: CardArtSize.tile),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyStrong.copyWith(
                  fontSize: compact ? 12.5 : 14,
                  shadows: const [
                    Shadow(color: RiftColors.night, blurRadius: 8),
                  ],
                ),
              ),
              if (legend != null && !compact)
                Text(
                  legend.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.mono.copyWith(
                    fontSize: 10,
                    shadows: const [
                      Shadow(color: RiftColors.night, blurRadius: 8),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (state.mode.isTeamPlay) MonoBadge(label: teamLetter(player.team)),
      ],
    );
  }
}

/// Le chiffre du score : Marcellus, énorme, avec un léger battement à chaque
/// changement pour que le geste se voie de l'autre bout de la table.
class BigScore extends StatelessWidget {
  const BigScore({
    super.key,
    required this.value,
    required this.color,
    this.size = 78,
  });

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
          color: RiftColors.darkInk,
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
class ScoreHalo extends StatelessWidget {
  const ScoreHalo({super.key, required this.child, this.diameter = 176});

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

/// Réserve d'XP (729) : le chiffre, six repères de niveau (824) et deux
/// boutons compacts. L'XP n'est jamais partagée, même en 2c2.
///
/// La barre se dégrade proprement selon la place : libellé « XP » et repères
/// de niveau sur un panneau large, repères seuls sur un panneau serré, le
/// chiffre nu sur un panneau de 2c2 — mais jamais un bloc écrasé illisible.
class XpBar extends StatelessWidget {
  const XpBar({
    super.key,
    required this.xp,
    required this.color,
    required this.onAdd,
    required this.onSpend,
    this.height = 38,
  });

  final int xp;
  final Color color;
  final VoidCallback onAdd;
  final VoidCallback onSpend;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: RiftColors.night.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(RiftRadius.full),
        border: Border.all(color: RiftColors.goldSoft.withValues(alpha: 0.28)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final showLabel = width >= 200;
          final showMarkers = width >= 150;
          final buttonSize = width < 150 ? 28.0 : 34.0;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _XpButton(
                icon: Icons.remove,
                onTap: onSpend,
                tooltip: 'Dépenser 1 XP',
                size: buttonSize,
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showLabel) ...[
                        Text('XP', style: text.eyebrow.copyWith(fontSize: 9)),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        '$xp',
                        style: text.monoStrong.copyWith(
                          fontSize: 16,
                          color: RiftColors.darkInk,
                        ),
                      ),
                      if (showMarkers) ...[
                        const SizedBox(width: 8),
                        LevelMarkers(xp: xp, color: color),
                      ],
                    ],
                  ),
                ),
              ),
              _XpButton(
                icon: Icons.add,
                onTap: onAdd,
                tooltip: 'Gagner 1 XP',
                size: buttonSize,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Six repères : le niveau N s'allume dès que le joueur a N XP. Le dernier
/// atteint bat doucement, pour repérer sans compter ce qui vient d'ouvrir.
class LevelMarkers extends StatefulWidget {
  const LevelMarkers({super.key, required this.xp, required this.color});

  final int xp;
  final Color color;

  @override
  State<LevelMarkers> createState() => _LevelMarkersState();
}

class _LevelMarkersState extends State<LevelMarkers>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant LevelMarkers oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final shouldRun = !_reduceMotion && widget.xp > 0;
    if (shouldRun && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!shouldRun && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reached = widget.xp.clamp(0, GameEngine.maxLevel);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final beat = _reduceMotion ? 1.0 : 0.6 + 0.4 * _pulse.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var level = 1; level <= GameEngine.maxLevel; level++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Semantics(
                  label: 'Niveau $level',
                  selected: level <= reached,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: level <= reached
                          ? RiftColors.gold
                          : Colors.transparent,
                      border: Border.all(
                        color: level <= reached
                            ? RiftColors.gold
                            : RiftColors.goldSoft.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      boxShadow: level == reached && reached > 0
                          ? [
                              BoxShadow(
                                color: RiftColors.gold.withValues(
                                  alpha: 0.7 * beat,
                                ),
                                blurRadius: 8 * beat,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _XpButton extends StatelessWidget {
  const _XpButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 34,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: size * 0.65,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.5, color: RiftColors.goldSoft),
        ),
      ),
    );
  }
}

class _TapZone extends StatelessWidget {
  const _TapZone({
    required this.icon,
    required this.align,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final Alignment align;
  final VoidCallback onTap;

  /// Null en partie suivie : les noms et les légendes viennent des comptes.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: onLongPress,
      child: Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: RiftColors.goldSoft.withValues(alpha: 0.28),
          ),
        ),
      ),
    );
  }
}
