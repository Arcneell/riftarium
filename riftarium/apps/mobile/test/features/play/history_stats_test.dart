import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/play/ui/stats_screen.dart';

import 'support/play_app.dart';
import 'support/play_fixtures.dart';

void main() {
  const tall = Size(520, 2400);

  group('historique', () {
    testWidgets('chaque partie montre adversaire, score et issue', (
      tester,
    ) async {
      final server = PlayFakeApi({
        'GET /play/history': historyPageJson(
          items: [
            historyItemJson(),
            historyItemJson(
              matchId: 2,
              mode: 'match',
              outcome: 'loss',
              myRounds: 0,
              opponentRounds: 2,
            ),
            historyItemJson(
              matchId: 3,
              outcome: 'disputed',
              status: 'disputed',
              anonymousOpponent: true,
            ),
          ],
        ),
      });
      await tester.pumpWidget(
        playApp(
          tester: tester,
          server: server,
          location: '/profil/historique',
          size: tall,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historique'), findsWidgets);
      expect(find.text('Victoire'), findsOneWidget);
      expect(find.text('Défaite'), findsOneWidget);
      expect(find.text('Contesté'), findsOneWidget);
      // Duel : les points (deux lignes). Match : les manches.
      expect(find.text('8 – 5'), findsNWidgets(2));
      expect(find.text('0 – 2'), findsOneWidget);
      // Compte supprimé : la ligne reste, l'adversaire est anonymisé.
      expect(find.text('Joueur retiré'), findsOneWidget);
      expect(find.text('jinx'), findsNWidgets(2));
    });

    testWidgets('le pseudo de l’adversaire mène à son profil public', (
      tester,
    ) async {
      final server = PlayFakeApi({
        'GET /play/history': historyPageJson(),
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
          location: '/profil/historique',
          size: tall,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('jinx').first);
      await tester.pumpAndSettle();

      expect(server.paths, contains('GET /users/jinx'));
      expect(find.text('Boum.'), findsOneWidget);
    });

    testWidgets('« Charger la suite » demande la page suivante', (
      tester,
    ) async {
      final server = PlayFakeApi({
        'GET /play/history': PlayFakeSequence([
          historyPageJson(items: [historyItemJson()], total: 2),
          historyPageJson(
            items: [historyItemJson(matchId: 2, handle: 'vi', outcome: 'loss')],
            total: 2,
            page: 2,
          ),
        ]),
      });
      await tester.pumpWidget(
        playApp(
          tester: tester,
          server: server,
          location: '/profil/historique',
          size: tall,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Charger la suite'), findsOneWidget);
      // La première page ne demande que 20 lignes : plus de `size: 50`.
      expect(server.last('GET', '/play/history')!.query['size'], 20);

      await tester.tap(find.text('Charger la suite'));
      await tester.pumpAndSettle();

      expect(server.on('GET', '/play/history').length, 2);
      expect(server.last('GET', '/play/history')!.query['page'], 2);
      expect(find.text('vi'), findsWidgets);
      // Les deux lignes sont là : plus rien à charger.
      expect(find.text('Charger la suite'), findsNothing);
    });

    testWidgets('sans partie, l’écran invite à en lancer une', (tester) async {
      final server = PlayFakeApi({
        'GET /play/history': historyPageJson(items: [], total: 0),
      });
      await tester.pumpWidget(
        playApp(
          tester: tester,
          server: server,
          location: '/profil/historique',
          size: tall,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucune partie suivie'), findsOneWidget);
      expect(find.text('Jouer une partie suivie'), findsOneWidget);
    });
  });

  group('statistiques', () {
    testWidgets('totaux, formats, decks, légendes et 30 derniers jours', (
      tester,
    ) async {
      final server = PlayFakeApi({'GET /play/stats': statsJson()});
      await tester.pumpWidget(
        playApp(
          tester: tester,
          server: server,
          location: '/profil/statistiques',
          size: tall,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      expect(find.text('Joués'), findsOneWidget);
      expect(find.text('60 %'), findsOneWidget);
      expect(find.text('Série 2'), findsOneWidget);
      expect(find.text('Meilleure 4'), findsOneWidget);
      expect(find.text('Par format'), findsOneWidget);
      expect(find.text('Ahri contrôle'), findsOneWidget);
      expect(find.text('4 V – 2 D'), findsWidgets);
      expect(find.text('Légendes affrontées'), findsOneWidget);

      // L'histogramme des trente derniers jours est bien peint.
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((paint) => paint.painter is RecentPlayPainter);
      expect(painters, isNotEmpty);
      expect(find.text('5 partie(s)'), findsOneWidget);
    });

    testWidgets('sans partie comptée, l’écran reste une invitation', (
      tester,
    ) async {
      final server = PlayFakeApi({
        'GET /play/stats': statsJson(played: 0, won: 0, lost: 0),
      });
      await tester.pumpWidget(
        playApp(
          tester: tester,
          server: server,
          location: '/profil/statistiques',
          size: tall,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucune partie suivie confirmée'), findsOneWidget);
    });
  });
}
