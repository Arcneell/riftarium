import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../game/ui/widgets/game_theme.dart';
import 'widgets/play_resume_panel.dart';
import 'widgets/tracked_start_panel.dart';

/// Partie suivie, en plein écran : créer un salon ou rejoindre celui d'un
/// adversaire. Même contenu que l'entrée « Partie suivie » de l'écran Jouer,
/// atteignable directement par lien.
class TrackedPlayScreen extends StatelessWidget {
  const TrackedPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return gameTheme(
      child: Scaffold(
        backgroundColor: RiftColors.night,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 8, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PARTIE SUIVIE', style: text.eyebrow),
                          const SizedBox(height: 4),
                          Text('Nouvelle partie', style: text.displayMedium),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      icon: const Icon(Icons.close),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  children: const [
                    PlayResumePanel(),
                    SizedBox(height: 20),
                    TrackedStartPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
