import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../play/support/play_app.dart';
import '../play/support/play_fixtures.dart';
import 'support/social_fixtures.dart';

void main() {
  const tall = Size(520, 1800);

  PlayFakeApi serverWith({Object? rooms}) => PlayFakeApi({
    'GET /me/follows': followsJson(),
    'GET /users/search': [socialUserJson(id: 11, handle: 'jinxy')],
    'POST /play/rooms': rooms ?? roomJson(),
    'GET /play/current': currentPlayJson(),
  });

  Future<void> open(WidgetTester tester, PlayFakeApi server) async {
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/profil/amis',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('les suivis et les abonnés tiennent en deux onglets', (
    tester,
  ) async {
    await open(tester, serverWith());

    expect(find.text('Suivis (1)'), findsOneWidget);
    expect(find.text('Abonnés (1)'), findsOneWidget);
    expect(find.text('jinx'), findsOneWidget);
    expect(find.text('vi'), findsNothing);

    await tester.tap(find.text('Abonnés (1)'));
    await tester.pumpAndSettle();

    expect(find.text('vi'), findsOneWidget);
    // On n'invite que ceux qu'on suit.
    expect(find.text('Inviter'), findsNothing);
  });

  testWidgets('la recherche interroge l’API et mène au profil', (tester) async {
    final server = serverWith();
    await open(tester, server);

    await tester.enterText(find.byType(TextField), 'jin');
    await tester.pumpAndSettle();

    expect(server.last('GET', '/users/search')!.query, {'q': 'jin'});
    expect(find.text('jinxy'), findsOneWidget);

    server.set('GET /users/jinxy', publicProfileJson(handle: 'jinxy'));
    server.set('GET /users/jinxy/collection', profileCollectionJson());
    server.set('GET /users/jinxy/history', historyPageJson());
    await tester.tap(find.text('jinxy'));
    await tester.pumpAndSettle();

    expect(find.text('Boum.'), findsOneWidget);
  });

  testWidgets('« Inviter » crée un salon et partage son code', (tester) async {
    final server = serverWith();
    await open(tester, server);

    await tester.tap(find.text('Inviter'));
    await tester.pumpAndSettle();

    expect(server.last('POST', '/play/rooms')!.body, {'mode': 'duel'});
    expect(find.text('Inviter jinx'), findsOneWidget);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('Ouvrir le salon'), findsOneWidget);
  });

  testWidgets('un salon déjà ouvert est réutilisé', (tester) async {
    final server = serverWith(
      rooms: const PlayFakeError(409, 'Tu as déjà un salon ouvert.'),
    );
    server.set('GET /play/current', currentPlayJson(room: roomJson()));
    await open(tester, server);

    await tester.tap(find.text('Inviter'));
    await tester.pumpAndSettle();

    expect(server.paths, contains('GET /play/current'));
    expect(find.text('ABC234'), findsOneWidget);
  });
}
