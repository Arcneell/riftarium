import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/social/ui/widgets/achievement_widgets.dart';

import '../play/support/play_app.dart';
import '../play/support/play_fixtures.dart';
import '../social/support/social_fixtures.dart';

void main() {
  const tall = Size(520, 2600);

  PlayFakeApi serverWith() => PlayFakeApi({
    'GET /me/achievements': achievementsJson(),
    'GET /me/follows': followsJson(),
    'GET /play/stats': statsJson(),
  });

  Future<void> open(WidgetTester tester, PlayFakeApi server) async {
    await tester.pumpWidget(
      playApp(tester: tester, server: server, location: '/profil', size: tall),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('le profil réunit hauts faits, duels, parties et amis', (
    tester,
  ) async {
    await open(tester, serverWith());

    expect(find.text('Modifier le profil'), findsOneWidget);
    expect(find.text('Hauts faits'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byType(AchievementMedallion), findsNWidgets(2));
    expect(find.text('Mes parties'), findsOneWidget);
    expect(find.text('de réussite'), findsOneWidget);
    expect(find.text('60 %'), findsOneWidget);
    expect(find.text('Historique des parties'), findsOneWidget);
    expect(find.text('Amis'), findsOneWidget);
    expect(find.text('1 suivis · 1 abonnés'), findsOneWidget);
    expect(find.text('ezreal@piltover.re'), findsOneWidget);
  });

  testWidgets('les hauts faits mènent à leur liste complète', (tester) async {
    await open(tester, serverWith());

    await tester.tap(find.byType(AchievementMedallion).first);
    await tester.pumpAndSettle();

    expect(find.text('2 sur 3'), findsOneWidget);
    expect(find.text('Vétéran'), findsOneWidget);
  });

  testWidgets('« Modifier le profil » ouvre le formulaire', (tester) async {
    final server = serverWith();
    server.set('GET /auth/avatars', const <Map<String, dynamic>>[]);
    await open(tester, server);

    await tester.tap(find.text('Modifier le profil'));
    await tester.pumpAndSettle();

    expect(find.text('Confidentialité'), findsOneWidget);
    expect(find.text('Mes decks publics'), findsOneWidget);
  });

  testWidgets('API muette : les nouvelles sections s’effacent', (tester) async {
    // Aucune route : les hauts faits, les duels et les amis restent silencieux
    // plutôt que d'afficher une erreur au milieu du compte.
    await open(tester, PlayFakeApi());

    expect(find.text('Hauts faits'), findsNothing);
    expect(find.text('de réussite'), findsNothing);
    expect(find.text('Compte'), findsOneWidget);
    expect(find.text('Modifier le profil'), findsOneWidget);
  });
}
