import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/auth/ui/splash_screen.dart';
import 'package:riftarium_mobile/features/profile/ui/profile_screen.dart';
import 'package:riftarium_mobile/main.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('démarre sur l’écran d’attente puis restaure la session', (
    tester,
  ) async {
    final store = InMemoryTokenStore('jwt');
    final adapter = FakeHttpAdapter({
      'GET /auth/me': const FakeResponse(200, profileJson),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          dioProvider.overrideWith(
            (ref) => createApiClient(
              readToken: store.read,
              baseUrl: 'https://api.test/api',
              adapter: adapter,
            ),
          ),
        ],
        child: const RiftariumApp(),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('ezreal'), findsWidgets);
  });
}
