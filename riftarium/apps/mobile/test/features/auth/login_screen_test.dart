import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/auth/ui/login_screen.dart';
import 'package:riftarium_mobile/features/home/ui/home_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late InMemoryTokenStore store;

  Widget app() {
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.login),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: adapter,
          ),
        ),
      ],
      child: const RiftariumApp(),
    );
  }

  setUp(() {
    store = InMemoryTokenStore();
  });

  testWidgets('sans session, l’écran de connexion s’affiche', (tester) async {
    adapter = FakeHttpAdapter({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('validation locale avant tout appel réseau', (tester) async {
    adapter = FakeHttpAdapter({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Indique une adresse e-mail valide.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  testWidgets('connexion réussie : redirection vers le profil', (tester) async {
    adapter = FakeHttpAdapter({
      'POST /auth/login': const FakeResponse(200, sessionJson),
      'GET /auth/me': const FakeResponse(200, profileJson),
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'ezreal@piltover.re');
    await tester.enterText(find.byType(TextField).at(1), 'secret-12');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await store.read(), 'jwt-de-test');
  });

  testWidgets('identifiants refusés : le message de l’API s’affiche', (
    tester,
  ) async {
    adapter = FakeHttpAdapter({
      'POST /auth/login': const FakeResponse(401, {
        'detail': 'Identifiants invalides',
      }),
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'ezreal@piltover.re');
    await tester.enterText(find.byType(TextField).at(1), 'faux');
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Identifiants invalides'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('sur iOS, les champs sont des CupertinoTextField', (
    tester,
  ) async {
    adapter = FakeHttpAdapter({});
    // ThemeData.platform suit defaultTargetPlatform : c'est ce que lisent les
    // widgets adaptatifs.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
