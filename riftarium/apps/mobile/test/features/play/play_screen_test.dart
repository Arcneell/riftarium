import 'package:flutter_test/flutter_test.dart';

import 'support/play_app.dart';
import 'support/play_fixtures.dart';

void main() {
  testWidgets('l’écran Jouer propose la partie libre et la partie suivie', (
    tester,
  ) async {
    final server = PlayFakeApi({'GET /play/current': currentPlayJson()});
    await tester.pumpWidget(
      playApp(tester: tester, server: server, location: '/partie'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Partie libre'), findsOneWidget);
    expect(find.text('Partie suivie'), findsOneWidget);
    // La partie libre reste retenue par défaut : le compteur est là, entier.
    expect(find.text('Compteur de partie'), findsOneWidget);
    expect(find.text('Chambre magmatique'), findsOneWidget);
    expect(find.text('Tirer le premier joueur'), findsOneWidget);
  });

  testWidgets('la partie suivie mène à la création et au code à saisir', (
    tester,
  ) async {
    final server = PlayFakeApi({'GET /play/current': currentPlayJson()});
    await tester.pumpWidget(
      playApp(tester: tester, server: server, location: '/partie'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Partie suivie'));
    await tester.pumpAndSettle();

    expect(find.text('Créer un salon'), findsOneWidget);
    expect(find.text('Rejoindre un salon'), findsOneWidget);
    // v1 : deux joueurs seulement, les formats à 3 et 4 ne sont pas proposés.
    expect(find.text('Duel'), findsOneWidget);
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Chambre magmatique'), findsNothing);
  });

  testWidgets('un salon en cours ramène dessus depuis l’écran Jouer', (
    tester,
  ) async {
    final server = PlayFakeApi({
      'GET /play/current': currentPlayJson(room: roomJson()),
    });
    await tester.pumpWidget(
      playApp(tester: tester, server: server, location: '/partie'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Salon ouvert'), findsOneWidget);
    expect(find.text('ABC234'), findsOneWidget);
    expect(find.text('Reprendre la partie suivie'), findsOneWidget);
  });

  testWidgets('un match en cours ramène dessus depuis l’écran Jouer', (
    tester,
  ) async {
    final server = PlayFakeApi({
      'GET /play/current': currentPlayJson(match: matchJson()),
    });
    await tester.pumpWidget(
      playApp(tester: tester, server: server, location: '/partie'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Match en cours'), findsOneWidget);
    expect(find.text('contre jinx'), findsOneWidget);
  });

  testWidgets('sans compte, la partie suivie invite à se connecter', (
    tester,
  ) async {
    final server = PlayFakeApi();
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/partie',
        signedIn: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Partie suivie'));
    await tester.pumpAndSettle();

    expect(find.text('COMPTE REQUIS'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    // Rien n'a été demandé au serveur : la partie libre n'attend jamais.
    expect(server.calls, isEmpty);
  });
}
