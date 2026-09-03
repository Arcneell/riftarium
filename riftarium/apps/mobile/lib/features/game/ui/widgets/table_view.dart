import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/reveal.dart';
import '../../../../app/theme.dart';
import '../../application/game_providers.dart';
import '../../domain/game_actions.dart';
import '../../domain/game_mode.dart';
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
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  /// Battement de l'horloge : rafraîchit l'affichage et, en tournoi, annonce
  /// la fin du temps quand la ronde est écoulée (RT 408.2). La table qui
  /// compte le fait ; l'invité en lecture seule attend l'hôte.
  void _tick() {
    if (!mounted) return;
    final state = widget.state;
    if (!widget.readOnly &&
        state.mode.isTournament &&
        !state.timeCalled &&
        state.remainingTime(DateTime.now()) == Duration.zero) {
      _game.callTime();
    }
    setState(() {});
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
  /// commun posé entre eux. Le disque central s'adapte à l'écran pour laisser
  /// aux panneaux la place de rester lisibles (nom, XP).
  Widget _teamRow(int team) {
    final members = widget.state.teamPlayers(team);
    if (members.isEmpty) return const SizedBox.shrink();
    if (members.length == 1) return _panel(members.first);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scoreWidth = (constraints.maxWidth * 0.24).clamp(78.0, 116.0);
        return Row(
          children: [
            Expanded(child: _panel(members[0], showScore: false)),
            const SizedBox(width: 8),
            _TeamScore(
              state: widget.state,
              team: team,
              width: scoreWidth,
              onAdd: () => _game.addPoint(members[0].id),
              onRemove: () => _game.removePoint(members[0].id),
            ),
            const SizedBox(width: 8),
            Expanded(child: _panel(members[1], showScore: false)),
          ],
        );
      },
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
    // La rangée du haut est tournée de 180° : son premier enfant finit à
    // DROITE de l'écran. Sièges 2 puis 3 pour que l'ordre des tours fasse le
    // tour de la table (bas-gauche → bas-droite → haut-droite → haut-gauche)
    // au lieu de zigzaguer en diagonale.
    return Column(
      children: [
        Expanded(
          child: _rotated(
            Row(
              children: [
                Expanded(child: _panel(players[2])),
                const SizedBox(width: 8),
                Expanded(child: _panel(players[3])),
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
    onCallTime: _confirmCallTime,
    onDismissHint: _game.markHintSeen,
  );

  /// L'arbitre annonce la fin du temps : irréversible, on demande confirmation.
  Future<void> _confirmCallTime() async {
    final call = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annoncer la fin du temps ?'),
        content: const Text(
          'Le tour en cours s’achève, puis trois tours supplémentaires sont '
          'joués. Deux points d’avance gagnent le match, sinon égalité. '
          'Cette annonce ne s’annule pas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Pas encore'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Temps écoulé'),
          ),
        ],
      ),
    );
    if (call == true) _game.callTime();
  }

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
    this.width = 116,
  });

  final GameState state;
  final int team;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final double width;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final color = Player.fallbackColors[team % Player.fallbackColors.length];
    final score = state.scoreOfTeam(team);
    return SizedBox(
      width: width,
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
                  diameter: width + 16,
                  child: BigScore(
                    value: score,
                    color: color,
                    size: width * 0.57,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ScoreGems(
                    score: score,
                    target: state.mode.victoryScore,
                    color: color,
                    size: width < 100 ? 6.5 : 8,
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

/// Puce du joueur actif, au centre de la table : elle dit à qui c'est de
/// jouer — en 2c2 comme à quatre, la lueur d'un panneau ne suffit pas — et un
/// appui passe la main. Le suivi du tour devient un vrai outil, pas un décor.
class _TurnChip extends StatelessWidget {
  const _TurnChip({required this.state, required this.onTap});

  final GameState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final player = state.activePlayer;
    final color = player.color;
    return Semantics(
      button: true,
      label: 'Passer au joueur suivant',
      child: Tooltip(
        message: 'Passer au joueur suivant',
        child: PressScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: RiftMotion.quick,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(RiftRadius.full),
              border: Border.all(color: color.withValues(alpha: 0.75)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActiveDot(color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AU TOUR DE',
                        style: text.eyebrow.copyWith(fontSize: 8),
                      ),
                      Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyStrong.copyWith(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.skip_next_rounded,
                  size: 20,
                  color: RiftColors.goldSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Version en lecture seule (l'invité regarde l'hôte compter) : le joueur
/// actif reste annoncé, sans geste.
class _ActiveTurnLabel extends StatelessWidget {
  const _ActiveTurnLabel({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final player = state.activePlayer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActiveDot(color: player.color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyStrong.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 8),
      ],
    ),
  );
}

/// Barre centrale : tour, chronomètre, joueur actif, annuler, menu. Jamais
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
    required this.onCallTime,
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
  final VoidCallback onCallTime;
  final VoidCallback onDismissHint;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final showHint = !state.hintSeen && state.turnNumber == 1;
    final now = DateTime.now();
    final elapsed = now.difference(state.startedAt);
    final canCallTime =
        state.mode.isTournament && !state.timeCalled && !readOnly;
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
              // Le chrono est borné : la puce du joueur actif garde sa
              // place, c'est elle qui s'ellipse à police agrandie.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: state.mode.isTournament
                    ? _TournamentClock(state: state, now: now)
                    : Column(
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
                      ? _ActiveTurnLabel(state: state)
                      : _TurnChip(state: state, onTap: onNextTurn),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Menu de la partie',
                onSelected: (value) => switch (value) {
                  'round' => onNewRound(),
                  'reset' => onReset(),
                  'time' => onCallTime(),
                  _ => onQuit(),
                },
                itemBuilder: (context) => [
                  if (canCallTime)
                    const PopupMenuItem(
                      value: 'time',
                      child: Text('Annoncer la fin du temps'),
                    ),
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

/// Horloge de la ronde en tournoi : le temps restant plutôt que le temps
/// écoulé, puis le décompte des tours supplémentaires une fois le temps
/// annoncé (RT 408.2). Passe à l'or sous cinq minutes.
class _TournamentClock extends StatelessWidget {
  const _TournamentClock({required this.state, required this.now});

  final GameState state;
  final DateTime now;

  static const _warning = Duration(minutes: 5);

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final String eyebrow;
    final String value;
    Color? color;
    if (state.timeCalled) {
      eyebrow = 'TEMPS ÉCOULÉ';
      final left = state.overtimeTurnsLeft;
      value = left > kTournamentExtraTurns
          ? 'fin du tour'
          : left <= 0
          ? 'terminé'
          : '+${kTournamentExtraTurns - left + 1}/$kTournamentExtraTurns';
      color = RiftColors.goldSoft;
    } else {
      final remaining = state.remainingTime(now);
      if (remaining == null) {
        eyebrow = 'M${state.round} · TOUR ${state.turnNumber}';
        value = formatChrono(now.difference(state.startedAt));
      } else {
        eyebrow = 'M${state.round} · RONDE';
        value = formatChrono(remaining);
        if (remaining <= _warning) color = RiftColors.goldSoft;
      }
    }
    return Semantics(
      label: state.timeCalled
          ? 'Temps écoulé, tours supplémentaires'
          : 'Temps restant de la ronde',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eyebrow,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.eyebrow.copyWith(fontSize: 9.5, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.monoStrong.copyWith(fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }
}
