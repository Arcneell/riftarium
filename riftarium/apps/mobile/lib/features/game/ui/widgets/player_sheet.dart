import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../application/game_providers.dart';
import '../../domain/game_engine.dart';
import '../../domain/player.dart';
import 'legend_picker_sheet.dart';

/// Feuille d'un joueur (appui long sur son panneau) : renommer, changer de
/// légende, régler son XP, appliquer l'exténuation.
Future<void> showPlayerSheet(BuildContext context, {required Player player}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RiftColors.night,
      builder: (context) => Theme(
        data: buildTheme(Brightness.dark),
        child: _PlayerSheet(playerId: player.id),
      ),
    );

class _PlayerSheet extends ConsumerStatefulWidget {
  const _PlayerSheet({required this.playerId});

  final String playerId;

  @override
  ConsumerState<_PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends ConsumerState<_PlayerSheet> {
  late final TextEditingController _name;
  late final TextEditingController _xp;

  @override
  void initState() {
    super.initState();
    final state = ref.read(gameControllerProvider);
    final player = state?.playerById(widget.playerId);
    _name = TextEditingController(text: player?.name ?? '');
    _xp = TextEditingController(
      text: '${state == null || player == null ? 0 : state.xpOf(player)}',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _xp.dispose();
    super.dispose();
  }

  GameController get _game => ref.read(gameControllerProvider.notifier);

  void _bumpXp(int amount) {
    HapticFeedback.selectionClick();
    _game.addXp(widget.playerId, amount);
    final state = ref.read(gameControllerProvider);
    if (state == null) return;
    _xp.text = '${state.xpOf(state.playerById(widget.playerId))}';
  }

  Future<void> _changeLegend() async {
    final legend = await showLegendPicker(context);
    if (legend == null) return;
    _game.setLegend(widget.playerId, legend);
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final state = ref.watch(gameControllerProvider);
    if (state == null) return const SizedBox.shrink();
    final player = state.playerById(widget.playerId);
    final legend = player.legend;
    final xp = state.xpOf(player);
    final opponents = state.players
        .where((other) => other.team != player.team)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        4,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (legend != null) ...[
                  SizedBox(
                    width: 44,
                    child: CardImage(
                      card: legend,
                      thumbWidth: CardArtSize.tile,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('JOUEUR', style: text.eyebrow),
                      const SizedBox(height: 2),
                      Text(
                        player.name,
                        style: text.displaySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) => _game.renamePlayer(
                player.id,
                value.trim().isEmpty
                    ? 'Joueur ${player.seat + 1}'
                    : value.trim(),
              ),
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('XP', style: text.eyebrow),
                const SizedBox(width: 10),
                Text('$xp', style: text.monoStrong.copyWith(fontSize: 20)),
                const Spacer(),
                Text(
                  xp >= 1
                      ? 'Niveau ${xp.clamp(0, GameEngine.maxLevel)} atteint'
                      : 'Aucun niveau',
                  style: text.small,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final amount in const [1, 2, 3])
                  ActionChip(
                    label: Text('Chasse $amount'),
                    avatar: const Icon(Icons.add, size: 15),
                    onPressed: () => _bumpXp(amount),
                  ),
                ActionChip(
                  label: const Text('Dépenser 1'),
                  avatar: const Icon(Icons.remove, size: 15),
                  onPressed: () => _bumpXp(-1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _xp,
              keyboardType: TextInputType.number,
              onSubmitted: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null) _game.setXp(player.id, parsed);
              },
              decoration: const InputDecoration(labelText: 'XP exacte'),
            ),
            const SizedBox(height: 18),
            GhostButton(
              label: legend == null
                  ? 'Choisir sa légende'
                  : 'Changer de légende',
              icon: Icons.auto_awesome,
              onPressed: _changeLegend,
            ),
            if (opponents.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('EXTÉNUATION', style: text.eyebrow),
              const SizedBox(height: 4),
              Text(
                'Piocher dans un deck vide donne 1 point à un adversaire.',
                style: text.small,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opponent in opponents)
                    ActionChip(
                      label: Text(opponent.name),
                      onPressed: () {
                        _game.exhaustion(
                          fromPlayerId: player.id,
                          toPlayerId: opponent.id,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}
