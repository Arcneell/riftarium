import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/design/components.dart';

import 'support/play_app.dart';
import 'support/play_fixtures.dart';

void main() {
  /// Le salon tient sans défiler sur un écran allongé (la liste reste
  /// paresseuse en production).
  const tall = Size(520, 2200);

  Map<String, dynamic> room({
    bool hostReady = false,
    bool guest = true,
    bool guestReady = false,
  }) => roomJson(
    players: [
      roomPlayerJson(ready: hostReady, legend: legendJson()),
      if (guest)
        roomPlayerJson(userId: 8, handle: 'jinx', seat: 1, ready: guestReady),
    ],
  );

  testWidgets('le code s’affiche en grand, avec copie et partage', (
    tester,
  ) async {
    final server = PlayFakeApi({'GET /play/rooms/ABC234': room()});
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/salon/ABC234',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.text('Duel'), findsOneWidget);
    expect(find.text('Victoire 8'), findsOneWidget);
    expect(find.text('ezreal'), findsOneWidget);
    expect(find.text('jinx'), findsOneWidget);
    // Le nom de la légende : sur la vignette (substitut sans réseau) et
    // sous elle.
    expect(find.text('Ahri'), findsWidgets);
  });

  testWidgets('sans adversaire, le salon attend et le lancement est fermé', (
    tester,
  ) async {
    final server = PlayFakeApi({'GET /play/rooms/ABC234': room(guest: false)});
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/salon/ABC234',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('En attente de l’adversaire…'), findsOneWidget);
    final button = tester.widget<GoldButton>(
      find.widgetWithText(GoldButton, 'Lancer la partie'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('« Prêt » part au serveur et ouvre le lancement', (tester) async {
    final server = PlayFakeApi({
      'GET /play/rooms/ABC234': room(guestReady: true),
      'PUT /play/rooms/ABC234/me': room(hostReady: true, guestReady: true),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/salon/ABC234',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<GoldButton>(
            find.widgetWithText(GoldButton, 'Lancer la partie'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final call = server.last('PUT', '/play/rooms/ABC234/me')!;
    expect(call.body, {
      'legend_card_id': 'OGN-001',
      'deck_id': null,
      'ready': true,
    });
    // Les deux prêts : l'hôte peut lancer.
    expect(
      tester
          .widget<GoldButton>(
            find.widgetWithText(GoldButton, 'Lancer la partie'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('un salon expiré le dit et renvoie au jeu', (tester) async {
    final server = PlayFakeApi({
      'GET /play/rooms/ABC234': roomJson(
        status: 'open',
        expiresAt: '2020-01-01T00:00:00Z',
      ),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/salon/ABC234',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Salon expiré'), findsOneWidget);
    expect(find.text('Revenir au jeu'), findsOneWidget);
  });

  testWidgets('un salon inconnu affiche le message de l’API', (tester) async {
    final server = PlayFakeApi({
      'GET /play/rooms/ZZZ999': const PlayFakeError(404, 'Salon introuvable.'),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/salon/ZZZ999',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Salon introuvable.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
