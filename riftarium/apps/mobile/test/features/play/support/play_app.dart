import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/game/application/game_providers.dart';
import 'package:riftarium_mobile/features/play/application/play_providers.dart';
import 'package:riftarium_mobile/main.dart';

import '../../game/support/in_memory_game_store.dart';
import 'play_fixtures.dart';

/// Surcharges communes aux tests de partie suivie : faux serveur, session déjà
/// ouverte, sauvegarde en mémoire, aucun sondage (les battements sont
/// déclenchés à la main) et pas de plugin de veille.
List<Override> playOverrides({
  required PlayFakeApi server,
  required TokenStore tokens,
  bool signedIn = true,
}) => [
  tokenStoreProvider.overrideWithValue(tokens),
  dioProvider.overrideWith(
    (ref) => createApiClient(
      readToken: tokens.read,
      baseUrl: 'https://api.test/api',
      adapter: server,
    ),
  ),
  if (signedIn) authControllerProvider.overrideWith(SignedInAuthController.new),
  playPollIntervalProvider.overrideWithValue(Duration.zero),
  gameStoreProvider.overrideWithValue(InMemoryGameStore()),
  screenAwakeProvider.overrideWithValue(const NoScreenAwake()),
];

/// Conteneur de providers pour les tests de contrôleurs (sans widgets).
ProviderContainer playContainer({
  required PlayFakeApi server,
  bool signedIn = true,
}) {
  final container = ProviderContainer(
    overrides: playOverrides(
      server: server,
      tokens: InMemoryTokenStore(signedIn ? 'jwt' : null),
      signedIn: signedIn,
    ),
  );
  addTearDown(container.dispose);
  return container;
}

/// L'application montée sur un écran de partie suivie.
///
/// Le mouvement est réduit partout (filets qui respirent, révélations en
/// cascade) : sans cela, `pumpAndSettle` n'en verrait jamais la fin.
Widget playApp({
  required WidgetTester tester,
  required PlayFakeApi server,
  required String location,
  bool signedIn = true,
  Size size = const Size(520, 1400),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  return MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: ProviderScope(
      overrides: [
        ...playOverrides(
          server: server,
          tokens: InMemoryTokenStore(signedIn ? 'jwt' : null),
          signedIn: signedIn,
        ),
        initialLocationProvider.overrideWithValue(location),
      ],
      child: const RiftariumApp(),
    ),
  );
}
