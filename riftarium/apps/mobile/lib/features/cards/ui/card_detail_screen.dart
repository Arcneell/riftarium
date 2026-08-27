import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/common.dart';

/// Écran temporaire : remplacé par la phase 2 (voir WORKFLOW.md §8).
class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Carte',
      body: EmptyView(
        title: 'Carte',
        detail: 'Bientôt disponible dans l’application.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
