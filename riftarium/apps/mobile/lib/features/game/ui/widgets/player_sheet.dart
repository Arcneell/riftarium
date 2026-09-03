import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../application/game_providers.dart';
import '../../domain/game_engine.dart';
import '../../domain/player.dart';
import 'game_theme.dart';
import 'legend_picker_sheet.dart';

/// Feuille d'un joueur (appui long sur son panneau) : renommer, changer de
/// légende, régler son XP, appliquer l'exténuation.
Future<void> showPlayerSheet(BuildContext context, {required Player player}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RiftColors.night,
      builder: (context) => gameTheme(child: _PlayerSheet(playerId: player.id)),
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

  /// Le nom n'est appliqué qu'une fois la frappe posée : renommer à chaque
  /// caractère pousserait une sauvegarde par lettre.
  Timer? _rename;
  static const _renameDelay = Duration(milliseconds: 400);

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
    _rename?.cancel();
    _name.dispose();
    _xp.dispose();
    super.dispose();
  }

  GameController get _game => ref.read(gameControllerProvider.notifier);

  void _bumpXp(int amount) {
    HapticFeedback.selectionClick();
    _game.addXp(widget.playerId, amount);
    final state = ref.read(gameControllerProvider);
    final player = state?.playerById(widget.playerId);
    if (state == null || player == null) return;
    _xp.text = '${state.xpOf(player)}';
  }

  /// Frappe en cours : on attend une pause avant de renommer.
  void _scheduleRename(String value) {
    _rename?.cancel();
    _rename = Timer(_renameDelay, () => _applyName(value));
  }

  /// Nom posé (validation, fermeture) : appliqué tout de suite.
  void _applyName(String value) {
    _rename?.cancel();
    if (!mounted) return;
    final state = ref.read(gameControllerProvider);
    final player = state?.playerById(widget.playerId);
    if (player == null) return;
    final typed = value.trim();
    _game.renamePlayer(
      player.id,
      typed.isEmpty ? 'Joueur ${player.seat + 1}' : typed,
    );
  }

  /// Ferme la feuille en gardant le nom saisi.
  void _close() {
    _applyName(_name.text);
    Navigator.of(context).pop();
  }

  Future<void> _changeLegend() async {
    final legend = await showLegendPicker(context);
    if (!mounted || legend == null) return;
    _game.setLegend(widget.playerId, legend);
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final state = ref.watch(gameControllerProvider);
    final player = state?.playerById(widget.playerId);
    // Partie quittée pendant que la feuille était ouverte : plus rien à
    // régler, la feuille se vide sans faire de bruit.
    if (state == null || player == null) return const SizedBox.shrink();
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
              onChanged: _scheduleRename,
              onSubmitted: _applyName,
              textInputAction: TextInputAction.done,
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
                        _close();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            TextButton(onPressed: _close, child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }
}
