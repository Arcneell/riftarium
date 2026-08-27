import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/common.dart';

/// Écran temporaire : remplacé par la refonte des règles (guides).
class BeginnerGuideScreen extends StatelessWidget {
  const BeginnerGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveScaffold(
      title: 'Guide du débutant',
      body: EmptyView(
        title: 'Guide du débutant',
        detail: 'Bientôt disponible dans l’application.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
