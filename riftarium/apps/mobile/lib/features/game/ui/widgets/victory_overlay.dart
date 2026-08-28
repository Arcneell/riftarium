import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../app/design/components.dart';
import '../../../../app/design/foil.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../domain/game_state.dart';
import 'confetti.dart';

/// Troisième étape : l'écran de victoire. Le visuel du vainqueur balayé d'un
/// reflet or, le mot en Marcellus, le score final, et la suite à donner.
class VictoryOverlay extends StatefulWidget {
  const VictoryOverlay({
    super.key,
    required this.state,
    required this.onNewRound,
    required this.onNewGame,
    required this.onFinish,
    this.finishLabel = 'Terminer',
    this.allowNewGame = true,
  });

  final GameState state;
  final VoidCallback onNewRound;
  final VoidCallback onNewGame;
  final VoidCallback onFinish;

  /// Libellé de l'action qui clôt la rencontre (« Envoyer le résultat » en
  /// partie suivie).
  final String finishLabel;

  /// Faux en partie suivie : une rencontre enregistrée ne se rejoue pas d'un
  /// bouton, elle se termine.
  final bool allowNewGame;

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay> {
  /// Chaque incrément relance une pluie de confettis.
  int _burst = 0;

  void _replay() => setState(() => _burst++);

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final text = riftText(context);
    final team = state.winnerTeam;
    if (team == null) return const SizedBox.shrink();
    final winners = state.teamPlayers(team);
    final legend = winners
        .map((player) => player.legend)
        .where((card) => card != null)
        .firstOrNull;
    final others = state.teams.where((other) => other != team);
    final hasNextRound = state.mode.roundsToWin > 1 && !state.isMatchOver;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Positioned.fill(
      child: _FadeIn(
        enabled: !reduceMotion,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Un tap n'importe où sur le fond relance la fête.
              onTap: reduceMotion ? null : _replay,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: ColoredBox(
                  color: RiftColors.inkStrong.withValues(alpha: 0.9),
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (legend != null)
                              SizedBox(
                                width: 168,
                                child: FoilOverlay(
                                  rainbow: true,
                                  child: CardImage(
                                    card: legend,
                                    thumbWidth: CardArtSize.detail,
                                    shadow: true,
                                  ),
                                ),
                              )
                            else
                              const _GoldEmblem(),
                            const SizedBox(height: 22),
                            Text(
                              'Victoire',
                              style: text.displayLarge.copyWith(
                                fontSize: 46,
                                color: RiftColors.goldSoft,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Center(child: GoldRule(width: 72)),
                            const SizedBox(height: 14),
                            Text(
                              state.teamName(team),
                              textAlign: TextAlign.center,
                              style: text.displaySmall.copyWith(fontSize: 22),
                            ),
                            if (state.mode.isTeamPlay) ...[
                              const SizedBox(height: 4),
                              Text(
                                winners
                                    .map((player) => player.name)
                                    .join(' et '),
                                textAlign: TextAlign.center,
                                style: text.small,
                              ),
                            ],
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                MonoBadge(
                                  label: 'Score ${state.scoreOfTeam(team)}',
                                  filled: true,
                                ),
                                for (final other in others)
                                  MonoBadge(
                                    label:
                                        '${state.teamName(other)} '
                                        '${state.scoreOfTeam(other)}',
                                  ),
                                if (state.mode.roundsToWin > 1)
                                  MonoBadge(
                                    label:
                                        'Manches ${state.roundsWonBy(team)} – '
                                        '${others.map(state.roundsWonBy).join(' – ')}',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 26),
                            if (hasNextRound)
                              GoldButton(
                                label: 'Manche suivante',
                                icon: Icons.play_arrow_rounded,
                                onPressed: widget.onNewRound,
                              )
                            else if (widget.allowNewGame)
                              GoldButton(
                                label: 'Nouvelle partie',
                                icon: Icons.refresh_rounded,
                                onPressed: widget.onNewGame,
                              )
                            else
                              GoldButton(
                                label: widget.finishLabel,
                                icon: Icons.check_rounded,
                                onPressed: widget.onFinish,
                              ),
                            if (hasNextRound || widget.allowNewGame) ...[
                              const SizedBox(height: 8),
                              GhostButton(
                                label: widget.finishLabel,
                                icon: Icons.check_rounded,
                                onPressed: widget.onFinish,
                              ),
                            ],
                            if (!reduceMotion)
                              TextButton.icon(
                                onPressed: _replay,
                                icon: const Icon(
                                  Icons.celebration_outlined,
                                  size: 18,
                                ),
                                label: const Text('Encore !'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ConfettiOverlay(
              colors: confettiPalette(
                winners.expand(
                  (player) => player.legend?.domains ?? const <String>[],
                ),
              ),
              burst: _burst,
            ),
          ],
        ),
      ),
    );
  }
}

/// Fondu d'ouverture de l'écran de victoire, absent en mouvement réduit.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: RiftMotion.slow,
      curve: RiftMotion.ease,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

/// Emblème doré quand le vainqueur n'a pas choisi de légende : la table reste
/// jouable sans aucune donnée de carte.
class _GoldEmblem extends StatelessWidget {
  const _GoldEmblem();

  @override
  Widget build(BuildContext context) => Container(
    width: 128,
    height: 128,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RiftColors.goldGradient,
      boxShadow: RiftShadows.glowGold,
    ),
    child: const Icon(
      Icons.emoji_events_outlined,
      size: 58,
      color: Colors.white,
    ),
  );
}
