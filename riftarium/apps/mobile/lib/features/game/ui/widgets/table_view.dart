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
    // Table sans joueur : impossible en pratique (la configuration et la
    // relecture en exigent au moins un). On le dit plutôt que de tomber.
    if (players.isEmpty) return const _EmptyTable();
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

  Widget _bar() {
    final state = widget.state;
    return _ControlBar(
      state: state,
      readOnly: widget.readOnly,
      notice: widget.notice,
      quitLabel: widget.quitLabel,
      allowRestart: widget.allowRestart,
      now: ref.watch(nowProvider),
      onNextTurn: () {
        HapticFeedback.selectionClick();
        _game.nextTurn();
      },
      onUndo: state.canUndo ? _game.undo : null,
      onReset: _confirmReset,
      onQuit: _confirmQuit,
      onCallTime: _confirmCallTime,
      // Fin de la ronde atteinte : la table qui compte annonce le temps
      // d'elle-même (RT 408.2) ; l'invité en lecture seule attend l'hôte.
      onTimeExpired:
          !widget.readOnly && state.mode.isTournament && !state.timeCalled
          ? _game.callTime
          : null,
      onDismissHint: _game.markHintSeen,
    );
  }

  /// Boîte de confirmation de la table : un titre, une phrase, deux boutons.
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return answer == true;
  }

  /// L'arbitre annonce la fin du temps : irréversible, on demande confirmation.
  Future<void> _confirmCallTime() async {
    final call = await _confirm(
      title: 'Annoncer la fin du temps ?',
      message:
          'Le tour en cours s’achève, puis trois tours supplémentaires sont '
          'joués. Deux points d’avance gagnent le match, sinon égalité. '
          'Cette annonce ne s’annule pas.',
      confirmLabel: 'Temps écoulé',
      cancelLabel: 'Pas encore',
    );
    if (!mounted || !call) return;
    _game.callTime();
  }

  /// Remise à zéro des scores. En tournoi, l'horloge de la ronde ne repart
  /// pas : le moteur garde son départ.
  Future<void> _confirmReset() async {
    final reset = await _confirm(
      title: 'Réinitialiser les scores ?',
      message: widget.state.mode.isTournament
          ? 'Points, XP et manches repartent de zéro. Le chronomètre de la '
                'ronde continue de tourner.'
          : 'Points, XP et manches repartent de zéro, avec les mêmes joueurs.',
      confirmLabel: 'Réinitialiser',
      cancelLabel: 'Annuler',
    );
    if (!mounted || !reset) return;
    _game.reset();
  }

  Future<void> _confirmQuit() async {
    final custom = widget.confirmQuit;
    if (custom != null) {
      if (!await custom()) return;
      if (!mounted) return;
      _game.quit();
      widget.onQuit?.call();
      return;
    }
    final leave = await _confirm(
      title: 'Quitter la partie ?',
      message: 'Les scores en cours seront effacés.',
      confirmLabel: 'Quitter',
      cancelLabel: 'Rester',
    );
    if (!mounted || !leave) return;
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
    final color = Player.teamColor(team);
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
                ScoreDisplay(
                  score: score,
                  color: color,
                  target: state.mode.victoryScore,
                  diameter: width + 16,
                  digitSize: width * 0.57,
                  gemSize: width < 100 ? 6.5 : 8,
                  gemPadding: const EdgeInsets.symmetric(horizontal: 6),
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
    required this.now,
    required this.onNextTurn,
    required this.onUndo,
    required this.onReset,
    required this.onQuit,
    required this.onCallTime,
    required this.onTimeExpired,
    required this.onDismissHint,
  });

  final GameState state;
  final bool readOnly;
  final Widget? notice;
  final String quitLabel;
  final bool allowRestart;

  /// Horloge de la table, injectable : les tests fixent l'instant courant.
  final DateTime Function() now;
  final VoidCallback onNextTurn;
  final VoidCallback? onUndo;
  final VoidCallback onReset;
  final VoidCallback onQuit;
  final VoidCallback onCallTime;

  /// Fin de la ronde atteinte, null si personne n'a à l'annoncer ici.
  final VoidCallback? onTimeExpired;
  final VoidCallback onDismissHint;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final showHint = !state.hintSeen && state.turnNumber == 1;
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
                child: _TableClock(
                  state: state,
                  now: now,
                  onExpired: onTimeExpired,
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
                  'reset' => onReset(),
                  'time' => onCallTime(),
                  _ => onQuit(),
                },
                // Pas de « nouvelle manche » ici : le moteur ne l'accepte
                // qu'une fois la manche finie, et c'est l'écran de fin de
                // manche qui la lance — avec le choix du premier joueur en
                // tournoi (RT 407.4).
                itemBuilder: (context) => [
                  if (canCallTime)
                    const PopupMenuItem(
                      value: 'time',
                      child: Text('Annoncer la fin du temps'),
                    ),
                  if (allowRestart && !readOnly)
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Réinitialiser les scores'),
                    ),
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

/// Table sans joueur : le seul état d'erreur possible de la table.
class _EmptyTable extends StatelessWidget {
  const _EmptyTable();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Cette table n’a aucun joueur.',
      textAlign: TextAlign.center,
      style: riftText(context).body,
    ),
  );
}

/// Le seul élément qui bat à la seconde : isolé dans son propre widget, son
/// rafraîchissement ne reconstruit ni les panneaux des joueurs ni le reste de
/// la barre. Il surveille aussi la fin de la ronde en tournoi (RT 408.2) :
/// arrivé à zéro, il annonce le temps de lui-même.
///
/// En mouvement réduit (et donc dans les tests), aucun minuteur ne tourne :
/// l'affichage suit les changements de la partie, et une ronde déjà expirée
/// se voit dès la première image.
class _TableClock extends StatefulWidget {
  const _TableClock({
    required this.state,
    required this.now,
    required this.onExpired,
  });

  final GameState state;
  final DateTime Function() now;
  final VoidCallback? onExpired;

  @override
  State<_TableClock> createState() => _TableClockState();
}

class _TableClockState extends State<_TableClock> {
  Timer? _timer;
  late DateTime _now = widget.now();
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _scheduleExpiryCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _TableClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    _now = widget.now();
    _syncTimer();
    _scheduleExpiryCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Manche finie : le compte est acquis, l'horloge s'arrête.
  void _syncTimer() {
    final shouldTick = !_reduceMotion && !widget.state.isOver;
    if (shouldTick) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _now = widget.now());
    _checkExpiry();
  }

  /// Jamais pendant le build : annoncer le temps change l'état de la partie.
  void _scheduleExpiryCheck() {
    if (widget.onExpired == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkExpiry();
    });
  }

  void _checkExpiry() {
    if (widget.state.remainingTime(_now) == Duration.zero) {
      widget.onExpired?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.mode.isTournament) {
      return _TournamentClock(state: state, now: _now);
    }
    final text = riftText(context);
    return Column(
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
          formatChrono(_now.difference(state.startedAt)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.monoStrong.copyWith(fontSize: 14),
        ),
      ],
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
