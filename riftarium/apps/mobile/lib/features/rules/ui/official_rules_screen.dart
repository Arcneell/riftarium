import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/common.dart';

/// Écran temporaire : remplacé par la refonte des règles (guides).
class OfficialRulesScreen extends StatelessWidget {
  const OfficialRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Règles officielles',
      body: EmptyView(
        title: 'Règles officielles',
        detail: 'Bientôt disponible dans l’application.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
