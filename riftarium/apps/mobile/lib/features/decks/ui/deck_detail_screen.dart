import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/common.dart';

/// Écran temporaire : remplacé par la phase 4 (voir WORKFLOW.md §8).
class DeckDetailScreen extends StatelessWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final int deckId;

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Deck',
      body: EmptyView(
        title: 'Deck',
        detail: 'Bientôt disponible dans l’application.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
