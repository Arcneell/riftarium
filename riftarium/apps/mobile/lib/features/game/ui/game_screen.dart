import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/common.dart';

/// Écran temporaire : remplacé par le compteur de partie.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Partie',
      body: EmptyView(
        title: 'Compteur de partie',
        detail: 'Bientôt disponible dans l’application.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
