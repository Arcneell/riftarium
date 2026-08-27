import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/auth/ui/splash_screen.dart';
import 'package:riftarium_mobile/features/home/ui/home_screen.dart';
import 'package:riftarium_mobile/features/profile/ui/profile_screen.dart';
import 'package:riftarium_mobile/main.dart';

import 'support/fakes.dart';

void main() {
  ProviderScope app({
    required InMemoryTokenStore store,
    required FakeHttpAdapter adapter,
    String? initialLocation,
  }) => ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      dioProvider.overrideWith(
        (ref) => createApiClient(
          readToken: store.read,
          baseUrl: 'https://api.test/api',
          adapter: adapter,
        ),
      ),
      if (initialLocation != null)
        initialLocationProvider.overrideWithValue(initialLocation),
    ],
    child: const RiftariumApp(),
  );

  testWidgets('avec une session : écran d’attente puis accueil', (
    tester,
  ) async {
    final store = InMemoryTokenStore('jwt');
    final adapter = FakeHttpAdapter({
      'GET /auth/me': const FakeResponse(200, profileJson),
    });

    await tester.pumpWidget(app(store: store, adapter: adapter));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('sans session : l’accueil reste accessible', (tester) async {
    await tester.pumpWidget(
      app(store: InMemoryTokenStore(), adapter: FakeHttpAdapter({})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('sans session : l’onglet Profil invite à se connecter', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        store: InMemoryTokenStore(),
        adapter: FakeHttpAdapter({}),
        initialLocation: AppRoutes.profile,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('avec une session : le profil affiche le compte', (tester) async {
    final store = InMemoryTokenStore('jwt');
    final adapter = FakeHttpAdapter({
      'GET /auth/me': const FakeResponse(200, profileJson),
    });

    await tester.pumpWidget(
      app(store: store, adapter: adapter, initialLocation: AppRoutes.profile),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('ezreal'), findsWidgets);
    expect(find.text('ezreal@piltover.re'), findsOneWidget);
  });
}
