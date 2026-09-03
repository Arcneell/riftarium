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

  testWidgets('choisir un deck envoie la légende telle qu’elle y figure', (
    tester,
  ) async {
    final server = PlayFakeApi({
      'GET /play/rooms/ABC234': room(),
      'PUT /play/rooms/ABC234/me': room(),
      'GET /decks/mine': [deckJson()],
      'GET /decks/3': deckJson(),
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

    await tester.tap(find.text('Mon deck'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahri contrôle'));
    await tester.pumpAndSettle();

    // Le deck a été relu pour y prendre la carte de zone Légende : la variante
    // du deck (`OGN-001-alt`) l'emporte sur celle déjà posée dans le salon.
    expect(server.paths, contains('GET /decks/3'));
    expect(server.last('PUT', '/play/rooms/ABC234/me')!.body, {
      'legend_card_id': 'OGN-001-alt',
      'deck_id': 3,
      'ready': false,
    });
  });

  testWidgets('le pseudo d’un joueur du salon mène à son profil', (
    tester,
  ) async {
    final server = PlayFakeApi({
      'GET /play/rooms/ABC234': room(),
      'GET /users/jinx': {
        'id': 8,
        'handle': 'jinx',
        'avatar_url': null,
        'bio': 'Boum.',
        'created_at': '2026-01-15T10:00:00Z',
        'is_me': false,
        'is_followed': false,
        'followers_count': 0,
        'following_count': 0,
        'visibility': const <String, dynamic>{},
      },
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

    await tester.tap(find.text('jinx'));
    await tester.pumpAndSettle();

    expect(server.paths, contains('GET /users/jinx'));
    expect(find.text('Boum.'), findsOneWidget);
  });

  testWidgets('une place libre se prend depuis le salon', (tester) async {
    final open = roomJson(
      hostId: 8,
      players: [
        roomPlayerJson(userId: 8, handle: 'jinx', seat: 0, ready: true),
      ],
    );
    final server = PlayFakeApi({
      'GET /play/rooms/ABC234': open,
      'POST /play/rooms/ABC234/join': roomJson(
        hostId: 8,
        version: 2,
        players: [
          roomPlayerJson(userId: 8, handle: 'jinx', seat: 0, ready: true),
          roomPlayerJson(seat: 1),
        ],
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

    expect(find.text('Rejoindre ce salon'), findsOneWidget);

    await tester.tap(find.text('Rejoindre ce salon'));
    await tester.pumpAndSettle();

    expect(server.paths, contains('POST /play/rooms/ABC234/join'));
    // Assis au siège de l'invité : plus d'invitation, mais de quoi repartir.
    expect(find.text('Rejoindre ce salon'), findsNothing);
    expect(find.text('Quitter le salon'), findsOneWidget);
  });

  testWidgets('un salon complet se consulte en spectateur', (tester) async {
    final server = PlayFakeApi({
      'GET /play/rooms/ABC234': roomJson(
        hostId: 8,
        players: [
          roomPlayerJson(userId: 8, handle: 'jinx', seat: 0),
          roomPlayerJson(userId: 9, handle: 'vi', seat: 1),
        ],
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

    expect(
      find.text('Salon complet : tu le consultes en spectateur.'),
      findsOneWidget,
    );
    expect(find.text('Rejoindre ce salon'), findsNothing);
    expect(find.text('Revenir au jeu'), findsOneWidget);
  });

  testWidgets('un salon déjà lancé mène droit au compteur', (tester) async {
    final server = PlayFakeApi({
      'GET /play/rooms/ABC234': roomJson(
        status: 'playing',
        matchId: 1,
        players: [
          roomPlayerJson(ready: true),
          roomPlayerJson(userId: 8, handle: 'jinx', seat: 1, ready: true),
        ],
      ),
      'GET /play/matches/1': matchJson(),
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

    expect(server.paths, contains('GET /play/matches/1'));
    expect(find.text('CODE DU SALON'), findsNothing);
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
