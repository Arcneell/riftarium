import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/game/application/game_providers.dart';
import 'package:riftarium_mobile/features/game/data/game_store.dart';
import 'package:riftarium_mobile/features/game/domain/game_state.dart';
import 'package:riftarium_mobile/main.dart';

import '../../../support/fakes.dart';

/// Compteur de partie câblé sur une sauvegarde en mémoire et sans plugin de
/// veille : la table de jeu se teste entièrement hors ligne.
///
/// L'écran de test est allongé pour que la configuration tienne sans
/// défiler (la liste reste paresseuse en production).
///
/// Le mouvement est réduit partout : les panneaux respirent en continu (filet
/// or du joueur actif, repères d'XP), un `pumpAndSettle` n'en verrait jamais
/// la fin.
Widget gameApp({
  required WidgetTester tester,
  GameStore? store,
  Size size = const Size(520, 2600),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final tokens = InMemoryTokenStore();
  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: tokens.read,
            baseUrl: 'https://api.test/api',
            adapter: FakeHttpAdapter({}),
          ),
        ),
        initialLocationProvider.overrideWithValue(AppRoutes.game),
        gameStoreProvider.overrideWithValue(store ?? InMemoryGameStore()),
        screenAwakeProvider.overrideWithValue(const NoScreenAwake()),
      ],
      child: const RiftariumApp(),
    ),
  );
}

/// Partie en cours, telle que la lirait le contrôleur.
GameState? gameOf(WidgetTester tester) {
  final element = tester.element(find.byType(RiftariumApp));
  return ProviderScope.containerOf(element).read(gameControllerProvider);
}

/// Passe la configuration : tirage du premier joueur, fermeture de la roue,
/// puis départ. En mouvement réduit la roue s'affiche déjà arrêtée.
Future<void> startGame(WidgetTester tester) async {
  await tester.tap(find.text('Tirer le premier joueur'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('PREMIER JOUEUR'));
  await tester.pumpAndSettle();
}
