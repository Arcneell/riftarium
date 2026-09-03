import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/game/ui/widgets/player_panel.dart';

import 'support/play_app.dart';
import 'support/play_fixtures.dart';

void main() {
  /// Panneau du joueur `name` : les tests visent une place à la table.
  Finder panelOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PlayerPanel));

  /// Tape la moitié haute (un point de plus) ou basse (un de moins).
  Future<void> tapHalf(
    WidgetTester tester,
    Finder panel, {
    bool top = true,
  }) async {
    final center = tester.getCenter(panel);
    await tester.tapAt(center + Offset(0, top ? -70 : 70));
    await tester.pumpAndSettle();
  }

  /// Laisse passer l'anti-rebond de 300 ms puis l'aller-retour réseau.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('l’hôte compte et son geste part en PUT state', (tester) async {
    final server = PlayFakeApi({
      'GET /play/matches/1': matchJson(version: 3),
      'PUT /play/matches/1/state': matchJson(version: 4),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/partie/match/1',
        size: const Size(520, 1000),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Passer au joueur suivant'), findsOneWidget);
    await tapHalf(tester, panelOf('ezreal'));
    await settle(tester);

    final put = server.last('PUT', '/play/matches/1/state')!;
    expect(put.body['version'], 3);
    expect((put.body['state'] as Map)['scores'], {'7': 1, '8': 0});
    expect(find.text('Synchronisé'), findsOneWidget);
  });

  testWidgets('l’invité regarde : table figée et bandeau explicite', (
    tester,
  ) async {
    final server = PlayFakeApi({
      // L'hôte est le compte 8 : je ne tiens pas le compte.
      'GET /play/matches/1': matchJson(
        hostId: 8,
        firstPlayerId: 8,
        state: matchStateJson(scores: {'7': 2, '8': 1}),
      ),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/partie/match/1',
        size: const Size(520, 1000),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('L’hôte tient le compte.'), findsOneWidget);
    // Aucun geste de comptage : la puce du tour est en lecture seule,
    // et aucun point ne se marque.
    expect(find.byTooltip('Passer au joueur suivant'), findsNothing);
    await tapHalf(tester, panelOf('ezreal'));
    await settle(tester);
    expect(server.on('PUT', '/play/matches/1/state'), isEmpty);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('l’invité confirme le résultat', (tester) async {
    final server = PlayFakeApi({
      'GET /play/matches/1': matchJson(
        hostId: 8,
        firstPlayerId: 8,
        status: 'awaiting_confirmation',
        winnerUserId: 8,
        players: [
          matchPlayerJson(userId: 8, handle: 'jinx', seat: 0, score: 8),
          matchPlayerJson(seat: 1, score: 5),
        ],
      ),
      'POST /play/matches/1/confirm': matchJson(
        hostId: 8,
        status: 'confirmed',
        winnerUserId: 8,
      ),
      'GET /play/current': currentPlayJson(),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/partie/match/1',
        size: const Size(520, 1200),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Défaite'), findsOneWidget);
    expect(find.text('Contester'), findsOneWidget);

    await tester.tap(find.text('Confirmer le résultat'));
    await tester.pumpAndSettle();

    expect(server.on('POST', '/play/matches/1/confirm').length, 1);
    expect(find.text('Résultat confirmé'), findsOneWidget);
    expect(find.text('Voir l’historique'), findsOneWidget);

    // La confirmation invalide « ma partie en cours » : on laisse ce
    // rafraîchissement de fond finir, sinon sa requête reste en vol.
    await tester.pumpAndSettle();
  });

  testWidgets('l’hôte, déjà confirmé, attend la réponse de l’invité', (
    tester,
  ) async {
    final server = PlayFakeApi({
      'GET /play/matches/1': matchJson(
        status: 'awaiting_confirmation',
        winnerUserId: 7,
        players: [
          matchPlayerJson(seat: 0, score: 8, confirmed: true),
          matchPlayerJson(userId: 8, handle: 'jinx', seat: 1, score: 6),
        ],
      ),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/partie/match/1',
        size: const Size(520, 1200),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Victoire'), findsOneWidget);
    expect(find.text('En attente de confirmation de jinx.'), findsOneWidget);
    expect(find.text('Confirmer le résultat'), findsNothing);
  });
}
