import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components.dart';
import '../../../../app/design/reveal.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../application/game_providers.dart';
import '../../data/legends_repository.dart';
import '../../domain/game_engine.dart';
import '../../domain/game_mode.dart';
import '../../domain/game_state.dart';
import '../../domain/player.dart';
import '../../../play/application/play_providers.dart';
import '../../../play/ui/widgets/play_resume_panel.dart';
import '../../../play/ui/widgets/tracked_start_panel.dart';
import 'draw_overlay.dart';
import 'game_theme.dart';
import 'legend_picker_sheet.dart';

/// Première étape : choisir sa façon de jouer, puis le format, nommer les
/// joueurs, leur donner une légende, et tirer au sort qui commence.
///
/// Deux entrées en tête : la **partie libre** (ce compteur, hors ligne et sans
/// compte) et la **partie suivie** (deux comptes, résultat enregistré).
class GameSetupView extends ConsumerStatefulWidget {
  const GameSetupView({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  ConsumerState<GameSetupView> createState() => _GameSetupViewState();
}

class _GameSetupViewState extends ConsumerState<GameSetupView>
    with SingleTickerProviderStateMixin {
  static const _maxPlayers = 4;

  final _random = Random();

  /// Créés d'emblée (et non paresseusement) : `dispose` ne doit jamais avoir
  /// à fabriquer un contrôleur alors que l'arbre est déjà démonté.
  late final List<TextEditingController> _names;
  late final AnimationController _spin;

  GameMode _mode = GameMode.duel;
  late List<Player> _players = GameEngine.defaultPlayers(_mode);

  /// Tournoi : durée de la ronde en minutes, null sans limite.
  int? _roundMinutes = kTournamentRoundLimit.inMinutes;
  String? _firstPlayerId;
  int? _spotlight;
  int _drawTarget = 0;
  int _spinSteps = 0;

  /// Numéro du tirage en cours : un « retirer au sort » pendant l'attente de
  /// 1,8 s invalide le précédent, qui ne doit plus rien lancer.
  int _drawToken = 0;
  bool _drawing = false;
  bool _spinning = false;
  bool _resumeDismissed = false;

  /// L'utilisateur a déjà touché à la configuration : la dernière table
  /// sauvegardée ne vient plus écraser ses choix.
  bool _touched = false;

  /// Faux : le compteur libre. Vrai : le salon d'une partie suivie.
  bool _tracked = false;

  @override
  void initState() {
    super.initState();
    _names = [
      for (var seat = 0; seat < _maxPlayers; seat++)
        TextEditingController(text: 'Joueur ${seat + 1}'),
    ];
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    // Dernière table jouée : les joueurs, leurs légendes et le format sont
    // préremplis — on relance en changeant juste ce qui doit l'être.
    unawaited(_restoreLastTable());
  }

  Future<void> _restoreLastTable() async {
    final table = await ref.read(gameStoreProvider).readTable();
    if (!mounted || _touched || table == null) return;
    final players = [
      for (final player in table.players)
        if (player.seat >= 0 && player.seat < _maxPlayers) player,
    ];
    if (players.length != table.mode.playerCount) return;
    setState(() {
      _mode = table.mode;
      _players = players;
      for (final player in players) {
        _names[player.seat].text = player.name;
      }
      // La durée de ronde n'a de sens qu'en tournoi : là, null veut dire
      // « sans limite » (un choix), et non « rien de retenu ».
      if (table.mode.isTournament) {
        _roundMinutes = table.roundLimit?.inMinutes;
      }
      _firstPlayerId = null;
      _spotlight = null;
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    for (final controller in _names) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectMode(GameMode mode) {
    if (mode == _mode) return;
    _touched = true;
    final previous = {for (final player in _players) player.seat: player};
    setState(() {
      _mode = mode;
      _drawing = false;
      _players = [
        for (var seat = 0; seat < mode.playerCount; seat++)
          Player(
            id: 'p$seat',
            name: 'Joueur ${seat + 1}',
            seat: seat,
            team: mode.defaultTeam(seat),
            legend: previous[seat]?.legend,
          ),
      ];
      _firstPlayerId = null;
      _spotlight = null;
    });
  }

  /// Joueurs prêts à s'asseoir : les noms viennent des champs de saisie.
  List<Player> _seatedPlayers() => [
    for (final player in _players) player.copyWith(name: _nameOf(player.seat)),
  ];

  String _nameOf(int seat) {
    final typed = _names[seat].text.trim();
    return typed.isEmpty ? 'Joueur ${seat + 1}' : typed;
  }

  Future<void> _draw() async {
    final count = _players.length;
    if (count == 0) return;
    final target = _random.nextInt(count);
    final token = ++_drawToken;
    setState(() {
      _drawTarget = target;
      _drawing = true;
      _spinning = true;
      _firstPlayerId = null;
      _spotlight = null;
      // Trois tours complets avant de s'arrêter sur le siège tiré.
      _spinSteps = count * 3 + target;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _settleDraw();
      return;
    }
    await _spin.forward(from: 0);
    if (!mounted || token != _drawToken) return;
    await HapticFeedback.mediumImpact();
    if (!mounted || token != _drawToken) return;
    _settleDraw();
    // Le temps de lire le nom, puis la partie démarre d'elle-même.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted && _drawing && token == _drawToken) _closeDraw();
  }

  void _settleDraw() => setState(() {
    _spinning = false;
    _spotlight = _drawTarget;
    _firstPlayerId = _players[_drawTarget].id;
  });

  /// La roue se referme et la partie démarre aussitôt : pas de second geste.
  /// En tournoi, le tirage désigne qui *choisit* (RT 407.1) : la roue se
  /// referme sur ce choix, la partie attend.
  void _closeDraw() {
    if (!_drawing) return;
    setState(() => _drawing = false);
    if (!_mode.isTournament) _startGame();
  }

  /// Démarre la partie. `firstPlayerId` force le joueur qui commence (tournoi :
  /// le choix du joueur désigné) ; sinon c'est le joueur tiré au sort.
  void _startGame({String? firstPlayerId}) {
    final minutes = _roundMinutes;
    ref
        .read(gameControllerProvider.notifier)
        .start(
          mode: _mode,
          players: _seatedPlayers(),
          firstPlayerId: firstPlayerId ?? _firstPlayerId,
          roundLimit: _mode.isTournament && minutes != null
              ? Duration(minutes: minutes)
              : null,
        );
  }

  /// L'autre joueur d'un duel : celui qui joue en second si le désigné
  /// choisit de commencer, et inversement. Repli sur le joueur lui-même : le
  /// moteur gardera alors l'ordre en place plutôt que de lever.
  String _opponentOf(String playerId) {
    for (final player in _players) {
      if (player.id != playerId) return player.id;
    }
    return playerId;
  }

  /// Nom saisi du joueur `playerId`, vide s'il n'est plus à table.
  String _nameOfId(String playerId) {
    for (final player in _players) {
      if (player.id == playerId) return _nameOf(player.seat);
    }
    return '';
  }

  Future<void> _pickLegend(Player player) async {
    _touched = true;
    final legend = await showLegendPicker(context);
    if (legend == null || !mounted) return;
    setState(() {
      _players = [
        for (final item in _players)
          item.id == player.id ? item.copyWith(legend: legend) : item,
      ];
    });
  }

  void _setTeam(Player player, int team) {
    _touched = true;
    setState(() {
      _players = [
        for (final item in _players)
          item.id == player.id ? item.copyWith(team: team) : item,
      ];
      _firstPlayerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final saved = ref.watch(savedGameProvider).valueOrNull;
    // Le panneau de reprise s'efface quand il n'y a rien à reprendre :
    // l'écart qui le suit ne doit apparaître qu'avec lui.
    final play = ref.watch(currentPlayProvider).valueOrNull;
    final hasResume = play != null && !play.isEmpty;
    final drawn = _firstPlayerId;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(onClose: widget.onClose),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            children: [
              const PlayResumePanel(),
              if (hasResume) const SizedBox(height: 22),
              _PlayChoice(
                tracked: _tracked,
                onSelect: (tracked) => setState(() => _tracked = tracked),
              ),
              const SizedBox(height: 22),
              if (_tracked)
                const TrackedStartPanel()
              else ...[
                if (saved != null && !_resumeDismissed) ...[
                  _ResumePanel(
                    saved: saved,
                    onResume: () =>
                        ref.read(gameControllerProvider.notifier).resume(saved),
                    onDismiss: () async {
                      setState(() => _resumeDismissed = true);
                      await ref.read(gameStoreProvider).clear();
                      if (mounted) ref.invalidate(savedGameProvider);
                    },
                  ),
                  const SizedBox(height: 22),
                ],
                Text('FORMAT', style: text.eyebrow),
                const SizedBox(height: 10),
                for (var index = 0; index < GameMode.values.length; index++)
                  Reveal(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModeCard(
                        mode: GameMode.values[index],
                        selected: GameMode.values[index] == _mode,
                        onTap: () => _selectMode(GameMode.values[index]),
                      ),
                    ),
                  ),
                if (_mode.isTournament) ...[
                  const SizedBox(height: 18),
                  Text('RONDE', style: text.eyebrow),
                  const SizedBox(height: 10),
                  _RoundLimitPicker(
                    minutes: _roundMinutes,
                    onSelect: (minutes) => setState(() {
                      _touched = true;
                      _roundMinutes = minutes;
                    }),
                  ),
                ],
                const SizedBox(height: 18),
                Text('JOUEURS', style: text.eyebrow),
                const SizedBox(height: 10),
                for (final player in _players)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlayerRow(
                      player: player,
                      name: _names[player.seat],
                      teamPlay: _mode.isTeamPlay,
                      highlighted: _spotlight == player.seat,
                      onPickLegend: () => _pickLegend(player),
                      onClearLegend: () => setState(() {
                        _players = [
                          for (final item in _players)
                            item.id == player.id
                                ? item.copyWith(clearLegend: true)
                                : item,
                        ];
                      }),
                      onTeam: (team) => _setTeam(player, team),
                    ),
                  ),
                const SizedBox(height: 20),
                if (drawn != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: Text(
                        _mode.isTournament
                            ? '${_nameOfId(drawn)} est le joueur désigné : '
                                  'à lui de choisir.'
                            : '${_nameOfId(drawn)} commence.',
                        textAlign: TextAlign.center,
                        style: text.bodyStrong.copyWith(
                          color: RiftColors.goldSoft,
                        ),
                      ),
                    ),
                  ),
                if (drawn != null && _mode.isTournament) ...[
                  GoldButton(
                    label: '${_nameOfId(drawn)} commence',
                    icon: Icons.play_arrow_rounded,
                    onPressed: _spinning
                        ? null
                        : () => _startGame(firstPlayerId: drawn),
                  ),
                  const SizedBox(height: 8),
                  GhostButton(
                    label: '${_nameOfId(drawn)} joue en second',
                    icon: Icons.swap_horiz_rounded,
                    onPressed: _spinning
                        ? null
                        : () => _startGame(firstPlayerId: _opponentOf(drawn)),
                  ),
                ] else
                  // Hors tournoi, la roue lance la partie en se refermant :
                  // il n'y a jamais de second geste à faire ici.
                  GoldButton(
                    label: _mode.isTournament
                        ? 'Tirer le joueur désigné'
                        : 'Tirer le premier joueur',
                    icon: Icons.casino_outlined,
                    onPressed: _spinning ? null : _draw,
                  ),
                if (drawn != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextButton(
                      onPressed: _spinning ? null : _draw,
                      child: const Text('Retirer au sort'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );

    return Stack(
      children: [
        body,
        if (_drawing)
          DrawOverlay(
            players: _players,
            nameOf: (player) => _nameOf(player.seat),
            // En mouvement réduit, la roue est déjà arrêtée sur le résultat.
            animation: reduceMotion ? kAlwaysCompleteAnimation : _spin,
            steps: _spinSteps,
            target: _drawTarget,
            note: _mode.isTournament
                ? 'Le joueur désigné choisit de jouer en premier ou en second '
                      '(règles de tournoi 407.1).'
                : _mode.firstTurnNotes.join(' '),
            title: _mode.isTournament ? 'JOUEUR DÉSIGNÉ' : 'PREMIER JOUEUR',
            resultOf: _mode.isTournament
                ? (name) => '$name choisit.'
                : (name) => '$name commence.',
            onDismiss: _closeDraw,
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TABLE DE JEU', style: text.eyebrow),
                const SizedBox(height: 4),
                Text('Compteur de partie', style: text.displayMedium),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
          ),
        ],
      ),
    );
  }
}

class _ResumePanel extends StatelessWidget {
  const _ResumePanel({
    required this.saved,
    required this.onResume,
    required this.onDismiss,
  });

  final GameState saved;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final score = saved.teams
        .map((team) => '${saved.scoreOfTeam(team)}')
        .join(' – ');
    return RiftPanel(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('EN COURS', style: text.eyebrow),
          const SizedBox(height: 4),
          Text('Reprendre la partie', style: text.displaySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MonoBadge(label: saved.mode.label),
              MonoBadge(label: 'Tour ${saved.turnNumber}'),
              MonoBadge(label: score),
            ],
          ),
          const SizedBox(height: 14),
          GoldButton(
            label: 'Reprendre',
            icon: Icons.play_arrow_rounded,
            onPressed: onResume,
          ),
          TextButton(
            onPressed: onDismiss,
            child: const Text('Repartir de zéro'),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return ActiveGlow(
      active: selected,
      child: RiftPanel(
        onTap: onTap,
        raised: selected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(mode.label, style: text.displaySmall)),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    color: RiftColors.gold,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (mode.isTeamPlay) const MonoBadge(label: '2 équipes'),
                MonoBadge(label: '${mode.playerCount} joueurs'),
                MonoBadge(label: 'Victoire ${mode.victoryScore}'),
                MonoBadge(
                  label: mode.roundsToWin == 1
                      ? '1 manche'
                      : '${mode.roundsToWin} manches gagnantes',
                ),
                if (mode.isTournament)
                  const MonoBadge(label: 'Ronde chronométrée'),
              ],
            ),
            if (mode.isTournament) ...[
              const SizedBox(height: 8),
              Text(mode.tagline, style: text.small),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tournoi : durée de la ronde. Les règles recommandent 60 minutes en ronde
/// suisse (RT 604.1) et aucune limite en élimination directe (604.2) ; le
/// temps peut aussi être annoncé à la main depuis la table.
class _RoundLimitPicker extends StatelessWidget {
  const _RoundLimitPicker({required this.minutes, required this.onSelect});

  final int? minutes;
  final void Function(int? minutes) onSelect;

  static const _choices = <int?>[null, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in _choices)
                ChoiceChip(
                  label: Text(choice == null ? 'Sans limite' : '$choice min'),
                  selected: choice == minutes,
                  onSelected: (_) => onSelect(choice),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            minutes == null
                ? 'Élimination directe : la partie va à son terme. L’arbitre '
                      'peut annoncer la fin du temps depuis le menu de la table.'
                : 'Au bout du temps : le tour en cours s’achève, puis trois '
                      'tours supplémentaires. Deux points d’avance gagnent le '
                      'match, sinon égalité.',
            style: text.small,
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.player,
    required this.name,
    required this.teamPlay,
    required this.highlighted,
    required this.onPickLegend,
    required this.onClearLegend,
    required this.onTeam,
  });

  final Player player;
  final TextEditingController name;
  final bool teamPlay;
  final bool highlighted;
  final VoidCallback onPickLegend;
  final VoidCallback onClearLegend;
  final void Function(int team) onTeam;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final legend = player.legend;
    final variant = legend == null ? null : legendVariantLabel(legend);
    return ActiveGlow(
      active: highlighted,
      child: RiftPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: PressScale(
                onTap: onPickLegend,
                child: legend == null
                    ? Container(
                        height: 67,
                        decoration: BoxDecoration(
                          color: player.color.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(RiftRadius.card),
                          border: Border.all(
                            color: player.color.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Icon(Icons.add, color: player.color, size: 20),
                      )
                    : CardImage(
                        card: legend,
                        thumbWidth: CardArtSize.tile,
                        foil: variant != null,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    style: text.title,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Joueur ${player.seat + 1}',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (legend == null)
                    TextButton.icon(
                      onPressed: onPickLegend,
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Choisir sa légende'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(legend.name, style: text.bodyStrong),
                        if (variant != null)
                          MonoBadge(label: variant, color: RiftColors.hex),
                        TextButton(
                          onPressed: onClearLegend,
                          child: const Text('Retirer'),
                        ),
                      ],
                    ),
                  if (teamPlay) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Équipe', style: text.small),
                        const SizedBox(width: 8),
                        for (var team = 0; team < 2; team++)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _TeamChip(
                              team: team,
                              selected: player.team == team,
                              onTap: () => onTeam(team),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.team,
    required this.selected,
    required this.onTap,
  });

  final int team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Player.teamColor(team);
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: RiftMotion.quick,
        width: 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.24) : Colors.transparent,
          borderRadius: BorderRadius.circular(RiftRadius.full),
          border: Border.all(
            color: selected ? color : Theme.of(context).colorScheme.outline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          teamLetter(team),
          style: riftText(
            context,
          ).monoStrong.copyWith(color: selected ? color : null),
        ),
      ),
    );
  }
}

/// Les deux façons de jouer, côte à côte en tête de l'écran. La partie libre
/// est retenue par défaut : elle ne demande rien, ni compte ni réseau.
class _PlayChoice extends StatelessWidget {
  const _PlayChoice({required this.tracked, required this.onSelect});

  final bool tracked;
  final void Function(bool tracked) onSelect;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    // Dans une liste, la hauteur n'est pas bornée : `stretch` a besoin qu'on
    // lui donne la hauteur du plus grand des deux choix.
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _ChoiceCard(
            title: 'Partie libre',
            detail: 'Sans compte, rien n’est enregistré.',
            icon: Icons.sports_esports_outlined,
            selected: !tracked,
            onTap: () => onSelect(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ChoiceCard(
            title: 'Partie suivie',
            detail: 'À deux comptes, résultat gardé.',
            icon: Icons.wifi_tethering_rounded,
            selected: tracked,
            onTap: () => onSelect(true),
          ),
        ),
      ],
    ),
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return ActiveGlow(
      active: selected,
      child: RiftPanel(
        onTap: onTap,
        raised: selected,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? RiftColors.gold : text.muted,
            ),
            const SizedBox(height: 10),
            Text(title, style: text.title),
            const SizedBox(height: 4),
            Text(detail, style: text.small.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
