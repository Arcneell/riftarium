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
import 'draw_overlay.dart';
import 'game_theme.dart';
import 'legend_picker_sheet.dart';

/// Première étape : choisir le format, nommer les joueurs, leur donner une
/// légende, puis tirer au sort qui commence.
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
  String? _firstPlayerId;
  int? _spotlight;
  int _drawTarget = 0;
  int _spinSteps = 0;
  bool _drawing = false;
  bool _spinning = false;
  bool _resumeDismissed = false;

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
    final target = _random.nextInt(count);
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
    if (!mounted) return;
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    _settleDraw();
    // Le temps de lire le nom, puis la roue s'efface d'elle-même.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted && _drawing) _closeDraw();
  }

  void _settleDraw() => setState(() {
    _spinning = false;
    _spotlight = _drawTarget;
    _firstPlayerId = _players[_drawTarget].id;
  });

  void _closeDraw() => setState(() => _drawing = false);

  void _startGame() {
    ref
        .read(gameControllerProvider.notifier)
        .start(
          mode: _mode,
          players: _seatedPlayers(),
          firstPlayerId: _firstPlayerId,
        );
  }

  Future<void> _pickLegend(Player player) async {
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
                      '${_nameOf(_players.firstWhere((p) => p.id == drawn).seat)} commence.',
                      style: text.bodyStrong.copyWith(
                        color: RiftColors.goldSoft,
                      ),
                    ),
                  ),
                ),
              GoldButton(
                label: drawn == null
                    ? 'Tirer le premier joueur'
                    : 'Commencer la partie',
                icon: drawn == null
                    ? Icons.casino_outlined
                    : Icons.play_arrow_rounded,
                onPressed: _spinning
                    ? null
                    : (drawn == null ? _draw : _startGame),
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
            note: _mode.firstTurnNotes.join(' '),
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
            child: const Text('Effacer et repartir de zéro'),
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
            const SizedBox(height: 4),
            Text(mode.tagline, style: text.small),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MonoBadge(label: '${mode.playerCount} joueurs'),
                MonoBadge(label: 'Victoire ${mode.victoryScore}'),
                MonoBadge(
                  label: mode.roundsToWin == 1
                      ? '1 manche'
                      : '${mode.roundsToWin} manches gagnantes',
                ),
              ],
            ),
          ],
        ),
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
    final color = Player.fallbackColors[team % Player.fallbackColors.length];
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
