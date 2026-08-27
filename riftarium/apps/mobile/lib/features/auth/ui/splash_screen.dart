import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Affiché pendant la restauration de la session au démarrage.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Riftarium',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: kRiftariumGold,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator.adaptive(),
          ],
        ),
      ),
    );
  }
}
