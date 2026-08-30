import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../application/game_providers.dart';
import '../../domain/game_actions.dart';
import '../../domain/game_state.dart';
import '../../domain/player.dart';
import 'game_theme.dart';
import 'player_panel.dart';
import 'player_sheet.dart';

/// Deuxième étape : la table. Les panneaux occupent tout l'écran, orientés
/// vers chaque joueur, la barre de commande reste au milieu, à l'endroit.
///
/// La même table sert au compteur hors ligne et au match suivi : [actions]
/// choisit le moteur branché derrière les gestes, [readOnly] la fige pour
/// l'invité qui regarde l'hôte compter.
class GameTableView extends ConsumerStatefulWidget {
  const GameTableView({
    super.key,
    required this.state,
    this.onQuit,
    this.actions,
    this.readOnly = false,
    this.notice,
    this.quitLabel = 'Quitter',
    this.allowRestart = true,
    this.confirmQuit,
  });

  final GameState state;
  final VoidCallback? onQuit;

  /// Moteur branché sur les gestes. Null = la partie libre (`GameController`).
  final GameActions? actions;

  /// Table figée : aucun geste ne compte (l'hôte tient le compte).
  final bool readOnly;

  /// Bandeau discret au-dessus de la barre (synchronisation, lecture seule).
  final Widget? notice;

  /// Libellé de la sortie de table (« Quitter », « Abandonner »).
  final String quitLabel;

  /// Faux en partie suivie : ni remise à zéro ni nouvelle manche au menu.
  final bool allowRestart;

  /// Confirmation sur mesure avant de quitter ; sinon la boîte par défaut.
  final Future<bool> Function()? confirmQuit;

  @override
  ConsumerState<GameTableView> createState() => _GameTableViewState();
}

class _GameTableViewState extends ConsumerState<GameTableView> {
  Timer? _clock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le chronomètre bat à la seconde. En mouvement réduit (et donc dans les
    // tests), aucun minuteur n'est lancé : l'affichage reste figé.
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _clock?.cancel();
      _clock = null;
    } else {
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  GameActions get _game =>
      widget.actions ?? ref.read(gameControllerProvider.notifier);

  Widget _panel(Player player, {bool showScore = true}) {
    final panel = _livePanel(player, showScore: showScore);
    // Lecture seule : le panneau reste lisible et animé, mais aucun toucher
    // ne compte. La barre de commande, elle, reste active (quitter, abandon).
    return widget.readOnly ? AbsorbPointer(child: panel) : panel;
  }

  Widget _livePanel(Player player, {bool showScore = true}) => PlayerPanel(
    state: widget.state,
    player: player,
    showScore: showScore,
    onAdd: () => _game.addPoint(player.id),
    onRemove: () => _game.removePoint(player.id),
    onAddXp: () => _game.addXp(player.id),
    onSpendXp: () => _game.spendXp(player.id),
    // La feuille sert à renommer et à changer de légende : en partie suivie,
    // les deux viennent des comptes et du salon.
    onSheet: widget.actions == null
        ? () => showPlayerSheet(context, player: player)
        : null,
  );

  Widget _rotated(Widget child) => RotatedBox(quarterTurns: 2, child: child);

  /// Rangée d'une équipe en 2c2 : les coéquipiers côte à côte, leur score
  /// commun posé entre eux.
  Widget _teamRow(int team) {
    final members = widget.state.teamPlayers(team);
    if (members.isEmpty) return const SizedBox.shrink();
    if (members.length == 1) return _panel(members.first);
    return Row(
      children: [
        Expanded(child: _panel(members[0], showScore: false)),
        const SizedBox(width: 8),
        _TeamScore(
          state: widget.state,
          team: team,
          onAdd: () => _game.addPoint(members[0].id),
          onRemove: () => _game.removePoint(members[0].id),
        ),
        const SizedBox(width: 8),
        Expanded(child: _panel(members[1], showScore: false)),
      ],
    );
  }

  Widget _board() {
    final state = widget.state;
    final players = state.players;
    if (state.mode.isTeamPlay) {
      final teams = state.teams;
      return Column(
        children: [
          Expanded(child: _rotated(_teamRow(teams.length > 1 ? teams[1] : 0))),
          _bar(),
          Expanded(child: _teamRow(teams.first)),
        ],
      );
    }
    if (players.length <= 2) {
      return Column(
        children: [
          if (players.length > 1) Expanded(child: _rotated(_panel(players[1]))),
          _bar(),
          Expanded(child: _panel(players[0])),
        ],
      );
    }
    if (players.length == 3) {
      return Column(
        children: [
          Expanded(
            child: _rotated(
              Row(
                children: [
                  Expanded(child: _panel(players[2])),
                  const SizedBox(width: 8),
                  Expanded(child: _panel(players[1])),
                ],
              ),
            ),
          ),
          _bar(),
          Expanded(child: _panel(players[0])),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: _rotated(
            Row(
              children: [
                Expanded(child: _panel(players[3])),
                const SizedBox(width: 8),
                Expanded(child: _panel(players[2])),
              ],
            ),
          ),
        ),
        _bar(),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _panel(players[0])),
              const SizedBox(width: 8),
              Expanded(child: _panel(players[1])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar() => _ControlBar(
    state: widget.state,
    readOnly: widget.readOnly,
    notice: widget.notice,
    quitLabel: widget.quitLabel,
    allowRestart: widget.allowRestart,
    onNextTurn: () {
      HapticFeedback.selectionClick();
      _game.nextTurn();
    },
    onUndo: widget.state.canUndo ? _game.undo : null,
    onNewRound: _game.newRound,
    onReset: _game.reset,
    onQuit: _confirmQuit,
    onDismissHint: _game.markHintSeen,
  );

  Future<void> _confirmQuit() async {
    final custom = widget.confirmQuit;
    if (custom != null) {
      if (!await custom()) return;
      _game.quit();
      widget.onQuit?.call();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter la partie ?'),
        content: const Text('Les scores en cours seront effacés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (leave != true) return;
    _game.quit();
    widget.onQuit?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(8), child: _board());
  }
}

/// Score partagé d'une équipe (2c2), posé entre les deux coéquipiers.
class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.state,
    required this.team,
    required this.onAdd,
    required this.onRemove,
  });

  final GameState state;
  final int team;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final color = Player.fallbackColors[team % Player.fallbackColors.length];
    final score = state.scoreOfTeam(team);
    return SizedBox(
      width: 116,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onAdd();
                  },
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onRemove();
                  },
                ),
              ),
            ],
          ),
          IgnorePointer(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ÉQUIPE', style: text.eyebrow.copyWith(fontSize: 9)),
                ScoreHalo(
                  diameter: 132,
                  child: BigScore(value: score, color: color, size: 66),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ScoreGems(
                    score: score,
                    target: state.mode.victoryScore,
                    color: color,
                    size: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre centrale : tour, chronomètre, tour suivant, annuler, menu. Jamais
/// tournée : elle appartient à la table, pas à un joueur.
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.state,
    required this.readOnly,
    required this.notice,
    required this.quitLabel,
    required this.allowRestart,
    required this.onNextTurn,
    required this.onUndo,
    required this.onNewRound,
    required this.onReset,
    required this.onQuit,
    required this.onDismissHint,
  });

  final GameState state;
  final bool readOnly;
  final Widget? notice;
  final String quitLabel;
  final bool allowRestart;
  final VoidCallback onNextTurn;
  final VoidCallback? onUndo;
  final VoidCallback onNewRound;
  final VoidCallback onReset;
  final VoidCallback onQuit;
  final VoidCallback onDismissHint;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final showHint = !state.hintSeen && state.turnNumber == 1;
    final elapsed = DateTime.now().difference(state.startedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (notice != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: notice!),
          if (showHint)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: RiftColors.goldSoft,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      state.mode.firstTurnNotes.join(' '),
                      style: text.small.copyWith(fontSize: 11.5),
                    ),
                  ),
                  InkResponse(
                    onTap: onDismissHint,
                    radius: 18,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Le chrono est borné : « Tour suivant » garde sa place, c'est
              // lui qui s'ellipse quand la police est agrandie.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.mode.roundsToWin > 1
                          ? 'M${state.round} · TOUR ${state.turnNumber}'
                          : 'TOUR ${state.turnNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.eyebrow.copyWith(fontSize: 9.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatChrono(elapsed),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.monoStrong.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!readOnly)
                IconButton(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo),
                  tooltip: 'Annuler',
                ),
              Expanded(
                child: Center(
                  child: readOnly
                      ? const SizedBox.shrink()
                      : GoldButton(
                          label: 'Tour suivant',
                          icon: Icons.skip_next_rounded,
                          expand: false,
                          onPressed: onNextTurn,
                        ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Menu de la partie',
                onSelected: (value) => switch (value) {
                  'round' => onNewRound(),
                  'reset' => onReset(),
                  _ => onQuit(),
                },
                itemBuilder: (context) => [
                  if (allowRestart && !readOnly) ...const [
                    PopupMenuItem(
                      value: 'round',
                      child: Text('Nouvelle manche'),
                    ),
                    PopupMenuItem(
                      value: 'reset',
                      child: Text('Réinitialiser les scores'),
                    ),
                  ],
                  PopupMenuItem(value: 'quit', child: Text(quitLabel)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
