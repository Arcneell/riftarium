import 'package:flutter/material.dart';

/// Couleurs reprises de la charte web (`apps/web/src/style.css`) : or
/// Riftarium et fond parchemin. À centraliser dans `lib/theme/` dès que le
/// thème dépasse deux couleurs.
const Color kRiftariumGold = Color(0xFFB08A3E);
const Color kRiftariumParchment = Color(0xFFF5EFE1);

void main() {
  runApp(const RiftariumApp());
}

/// Racine de l'application. Squelette volontairement vide : l'écran d'accueil
/// réel arrive avec la première fonctionnalité (voir WORKFLOW.md, phase 1).
class RiftariumApp extends StatelessWidget {
  const RiftariumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riftarium',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kRiftariumGold,
          surface: kRiftariumParchment,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('Riftarium'))),
    );
  }
}
