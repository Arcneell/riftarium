import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/auth/ui/login_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late InMemoryTokenStore store;

  Widget app() => ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      initialLocationProvider.overrideWithValue(AppRoutes.profile),
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

  final unverified = {...profileJson, 'email_verified': false};

  testWidgets('e-mail non vérifié : bouton de renvoi, appel API', (
    tester,
  ) async {
    store = InMemoryTokenStore('jwt');
    adapter = FakeHttpAdapter({
      'GET /auth/me': FakeResponse(200, unverified),
      'POST /auth/resend-verification': const FakeResponse(204, {}),
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('non vérifié'), findsOneWidget);
    final resend = find.text("Renvoyer l'e-mail de vérification");
    await tester.scrollUntilVisible(resend, 200);
    await tester.ensureVisible(resend);
    await tester.pumpAndSettle();
    await tester.tap(resend);
    await tester.pumpAndSettle();

    expect(adapter.requests.last.path, '/auth/resend-verification');
    expect(find.text('E-mail envoyé'), findsOneWidget);
  });

  testWidgets(
    'changement de mot de passe : validation locale puis déconnexion',
    (tester) async {
      store = InMemoryTokenStore('jwt');
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
        'POST /auth/password': const FakeResponse(200, sessionJson),
      });
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final entry = find.text('Changer le mot de passe');
      await tester.scrollUntilVisible(entry, 200);
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'ancien-12');
      await tester.enterText(fields.at(1), 'nouveau-12');
      await tester.enterText(fields.at(2), 'different');
      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();
      expect(
        find.text('Les deux saisies ne correspondent pas.'),
        findsOneWidget,
      );
      expect(
        adapter.requests.where((r) => r.path == '/auth/password'),
        isEmpty,
      );

      await tester.enterText(fields.at(2), 'nouveau-12');
      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();

      expect(adapter.requests.last.path, '/auth/password');
      expect(find.text('Mot de passe changé'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Session fermée : l'onglet Profil invite à se reconnecter.
      expect(find.text('Se connecter'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(await store.read(), isNull);
    },
  );

  testWidgets('suppression du compte : le pseudo doit correspondre', (
    tester,
  ) async {
    store = InMemoryTokenStore('jwt');
    adapter = FakeHttpAdapter({
      'GET /auth/me': const FakeResponse(200, profileJson),
      'DELETE /auth/me': const FakeResponse(204, {}),
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final entry = find.text('Supprimer mon compte');
    await tester.scrollUntilVisible(entry, 200);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'secret-12');
    await tester.enterText(fields.at(1), 'autre');
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Le pseudo ne correspond pas.'), findsOneWidget);

    await tester.enterText(fields.at(1), 'ezreal');
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(adapter.requests.last.method, 'DELETE');
    expect(find.text('Compte supprimé'), findsOneWidget);
  });
}
