import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../play/support/play_app.dart';
import '../play/support/play_fixtures.dart';

void main() {
  const tall = Size(520, 2200);

  /// `user_out` du compte de test (`testProfile`), avec les quatre réglages.
  Map<String, dynamic> meJson({
    String handle = 'ezreal',
    String bio = '',
    String? avatarCardId,
    bool showStats = false,
  }) => {
    'id': 7,
    'handle': handle,
    'bio': bio,
    'avatar_card_id': avatarCardId,
    'avatar_url': null,
    'created_at': '2026-08-01T10:00:00Z',
    'email': 'ezreal@piltover.re',
    'email_verified': true,
    'is_admin': false,
    'stats': const <String, dynamic>{},
    'show_stats': showStats,
    'show_collection': false,
    'show_decks': true,
    'show_achievements': true,
  };

  List<Map<String, dynamic>> avatarsJson() => [
    {
      'id': 'OGN-001',
      'name': 'Ahri',
      'image_url': null,
      'orientation': 'portrait',
      'domains': ['Mind'],
    },
  ];

  PlayFakeApi serverWith() => PlayFakeApi({
    'GET /auth/avatars': avatarsJson(),
    'GET /auth/me': meJson(),
    'PATCH /auth/me': meJson(bio: 'Explorateur', showStats: true),
  });

  Future<void> open(WidgetTester tester, PlayFakeApi server) async {
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/profil/modifier',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bio et confidentialité partent dans un seul PATCH', (
    tester,
  ) async {
    final server = serverWith();
    await open(tester, server);

    expect(find.text('Confidentialité'), findsOneWidget);
    expect(find.text('Mes statistiques de duels'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Explorateur');
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(server.last('PATCH', '/auth/me')!.body, {
      'bio': 'Explorateur',
      'show_stats': true,
      'show_collection': false,
      'show_decks': true,
      'show_achievements': true,
    });
    // Le profil est relu après l'enregistrement.
    expect(server.paths, contains('GET /auth/me'));
    expect(find.text('Profil enregistré.'), findsOneWidget);
  });

  testWidgets('changer de pseudo exige le mot de passe actuel', (tester) async {
    final server = serverWith();
    await open(tester, server);

    await tester.enterText(find.byType(TextField).first, 'ezrealito');
    await tester.pumpAndSettle();

    // Le champ mot de passe n'apparaît qu'une fois le pseudo modifié.
    expect(find.text('Mot de passe actuel'), findsOneWidget);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ton mot de passe actuel est demandé pour changer de pseudo.'),
      findsOneWidget,
    );
    expect(server.on('PATCH', '/auth/me'), isEmpty);

    await tester.enterText(find.byType(TextField).at(1), 'secret-12');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(server.last('PATCH', '/auth/me')!.body, {
      'handle': 'ezrealito',
      'current_password': 'secret-12',
    });
  });

  testWidgets('le portrait choisi part en avatar_card_id', (tester) async {
    final server = serverWith();
    await open(tester, server);

    expect(find.text('Ahri'), findsOneWidget);
    await tester.tap(find.text('Ahri'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(server.last('PATCH', '/auth/me')!.body, {
      'avatar_card_id': 'OGN-001',
    });
  });

  testWidgets('sans modification, rien ne part au serveur', (tester) async {
    final server = serverWith();
    await open(tester, server);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Rien à enregistrer : ton profil est déjà à jour.'),
      findsOneWidget,
    );
    expect(server.on('PATCH', '/auth/me'), isEmpty);
  });
}
