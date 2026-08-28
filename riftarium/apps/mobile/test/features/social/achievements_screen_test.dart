import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/design/components.dart';

import '../play/support/play_app.dart';
import '../play/support/play_fixtures.dart';
import 'support/social_fixtures.dart';

void main() {
  const tall = Size(520, 2200);

  testWidgets('les hauts faits se rangent par famille, débloqués en tête', (
    tester,
  ) async {
    final server = PlayFakeApi({'GET /me/achievements': achievementsJson()});
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/profil/hauts-faits',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 sur 3'), findsOneWidget);
    expect(find.text('Duels'), findsOneWidget);
    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('Premier sang'), findsOneWidget);
    expect(find.text('Débloqué le 20/08/2026'), findsNWidgets(2));
    // Verrouillé : sa progression remplace la date.
    expect(find.text('Vétéran'), findsOneWidget);
    expect(find.text('4 / 10'), findsOneWidget);

    // Dans la famille « duels », le débloqué passe devant le verrouillé.
    expect(
      tester.getTopLeft(find.text('Premier sang')).dy,
      lessThan(tester.getTopLeft(find.text('Vétéran')).dy),
    );
    // Une barre de progression par haut fait, plus celle du résumé.
    expect(find.byType(PrismBar), findsNWidgets(4));
  });

  testWidgets('sans hauts faits, l’écran invite à jouer', (tester) async {
    final server = PlayFakeApi({
      'GET /me/achievements': const <Map<String, dynamic>>[],
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/profil/hauts-faits',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rien à décrocher pour l’instant'), findsOneWidget);
  });

  testWidgets('une erreur d’API propose de réessayer', (tester) async {
    final server = PlayFakeApi({
      'GET /me/achievements': const PlayFakeError(503, 'Service indisponible.'),
    });
    await tester.pumpWidget(
      playApp(
        tester: tester,
        server: server,
        location: '/profil/hauts-faits',
        size: tall,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Service indisponible.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
