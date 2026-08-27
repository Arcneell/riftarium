import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/common.dart';

/// Écran temporaire : remplacé par la refonte des règles (guides).
class AdvancedTopicScreen extends StatelessWidget {
  const AdvancedTopicScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Mécanique',
      body: EmptyView(
        title: 'Mécanique',
        detail: 'Bientôt disponible dans l’application.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
