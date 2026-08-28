import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design/components.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../application/play_providers.dart';

/// Panneau « Reprendre » en tête de l'écran Jouer : un salon ouvert ou un match
/// en cours attend quelque part, l'application y ramène en un geste.
///
/// Rien ne s'affiche hors session, ni quand `GET /play/current` ne répond pas :
/// une partie libre ne doit jamais attendre le réseau.
class PlayResumePanel extends ConsumerWidget {
  const PlayResumePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPlayProvider).valueOrNull;
    if (current == null || current.isEmpty) return const SizedBox.shrink();

    final text = riftText(context);
    final match = current.match;
    final room = current.room;
    final badges = <String>[];
    final String title;
    final String destination;

    if (match != null) {
      title = match.isLive ? 'Match en cours' : 'Résultat à confirmer';
      destination = AppRoutes.trackedMatch(match.id);
      badges.add(match.gameMode.label);
      final opponent = match.opponentOf(ref.watch(myUserIdProvider));
      if (opponent != null) badges.add('contre ${opponent.user.displayName}');
      badges.add('Tour ${match.state.turn}');
    } else {
      title = 'Salon ouvert';
      destination = AppRoutes.room(room!.code);
      badges.addAll([room.code, room.modeLabel]);
      badges.add(
        room.guest == null ? 'En attente' : 'Adversaire présent',
      );
    }

    return RiftPanel(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PARTIE SUIVIE', style: text.eyebrow),
          const SizedBox(height: 4),
          Text(title, style: text.displaySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final badge in badges) MonoBadge(label: badge)],
          ),
          const SizedBox(height: 14),
          GoldButton(
            label: 'Reprendre la partie suivie',
            icon: Icons.play_arrow_rounded,
            onPressed: () => context.push(destination),
          ),
        ],
      ),
    );
  }
}
