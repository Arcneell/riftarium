import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../play/support/play_app.dart';
import '../play/support/play_fixtures.dart';
import 'support/social_fixtures.dart';

void main() {
  /// Le profil public est long : un écran très haut construit toutes les
  /// sections d'un coup (les listes restent paresseuses en production).
  const tall = Size(520, 3000);

  PlayFakeApi serverWith({bool visible = true, bool isFollowed = false}) =>
      PlayFakeApi({
        'GET /users/jinx': publicProfileJson(
          visible: visible,
          isFollowed: isFollowed,
        ),
        'GET /users/jinx/collection': profileCollectionJson(),
        'GET /users/jinx/history': historyPageJson(),
        'PUT /users/jinx/follow': const <String, dynamic>{},
        'DELETE /users/jinx/follow': const <String, dynamic>{},
        'GET /me/follows': followsJson(),
      });

  testWidgets('un profil ouvert montre ses stats, sa collection et ses decks', (
    tester,
  ) async {
    final server = serverWith();
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/joueur/jinx',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boum.'), findsOneWidget);
    expect(find.text('Membre depuis le 15/01/2026'), findsOneWidget);
    expect(find.text('abonnés'), findsOneWidget);
    expect(find.text('suivis'), findsOneWidget);
    expect(find.text('Premier sang'), findsOneWidget);
    expect(find.text('Duels'), findsOneWidget);
    expect(find.text('10'), findsWidgets); // parties jouées
    expect(find.text('Collection'), findsOneWidget);
    expect(
      find.text('120 cartes différentes · 300 exemplaires'),
      findsOneWidget,
    );
    expect(find.text('Decks publics'), findsOneWidget);
    expect(find.text('Ahri contrôle'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Ce joueur garde ceci pour lui.'), findsNothing);
    // Les sections fermées n'auraient rien demandé de plus.
    expect(server.paths, contains('GET /users/jinx/collection'));
    expect(server.paths, contains('GET /users/jinx/history'));
  });

  testWidgets('un profil fermé le dit sans en dire plus', (tester) async {
    final server = serverWith(visible: false);
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/joueur/jinx',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    // Hauts faits, duels, collection, decks, historique.
    expect(find.text('Ce joueur garde ceci pour lui.'), findsNWidgets(5));
    expect(find.text('Ahri contrôle'), findsNothing);
    expect(server.paths, isNot(contains('GET /users/jinx/collection')));
    expect(server.paths, isNot(contains('GET /users/jinx/history')));
  });

  testWidgets('« Suivre » part au serveur et met le compteur à jour', (
    tester,
  ) async {
    final server = serverWith();
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/joueur/jinx',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suivre'), findsOneWidget);
    await tester.tap(find.text('Suivre'));
    await tester.pumpAndSettle();

    expect(server.paths, contains('PUT /users/jinx/follow'));
    expect(find.text('Ne plus suivre'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('Ne plus suivre'));
    await tester.pumpAndSettle();

    expect(server.paths, contains('DELETE /users/jinx/follow'));
    expect(find.text('Suivre'), findsOneWidget);
  });

  testWidgets('un joueur inconnu affiche le message de l’API', (tester) async {
    final server = PlayFakeApi({
      'GET /users/zed': const PlayFakeError(404, 'Joueur introuvable.'),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/joueur/zed',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Joueur introuvable.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
