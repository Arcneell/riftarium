import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/common.dart';

/// Écran temporaire : remplacé par la refonte des règles (guides).
class AdvancedHelpScreen extends StatelessWidget {
  const AdvancedHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Aide avancée',
      body: EmptyView(
        title: 'Aide avancée',
        detail: 'Bientôt disponible dans l’application.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
