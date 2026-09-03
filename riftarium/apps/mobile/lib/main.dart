import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: RiftariumApp()));
}

/// Racine de l'application : thème adaptatif et routeur piloté par la session.
class RiftariumApp extends ConsumerWidget {
  const RiftariumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Riftarium',
      debugShowCheckedModeBanner: false,
      // Thème unique, nuit de Piltover (mémoïsé dans `buildTheme`) : le
      // réglage clair du système ne doit pas repeindre l'application.
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // Les écrans iOS vivent dans des CupertinoPageScaffold : sans ancêtre
      // Material, les Text prennent le style de secours (jaune, doublement
      // souligné) et les effets d'encre n'ont pas de support. Ce Material
      // transparent fournit les deux sans rien peindre.
      builder: (context, child) =>
          Material(type: MaterialType.transparency, child: child!),
    );
  }
}
