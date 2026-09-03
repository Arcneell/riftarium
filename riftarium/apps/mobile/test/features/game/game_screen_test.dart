import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/game/domain/game_engine.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';
import 'package:riftarium_mobile/features/game/ui/widgets/confetti.dart';
import 'package:riftarium_mobile/features/game/ui/widgets/draw_overlay.dart';
import 'package:riftarium_mobile/features/game/ui/widgets/player_panel.dart';

import 'support/game_app.dart';
import 'support/in_memory_game_store.dart';

void main() {
  /// Panneau du joueur nommé `name` : les tests visent une place précise
  /// autour de la table, pas un rang dans l'arbre de widgets.
  Finder panelOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PlayerPanel));

  /// Confettis effectivement peints à l'écran.
  Iterable<CustomPaint> confettiPainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .where((paint) => paint.painter is ConfettiPainter);

  /// Un repère de niveau allumé se lit « sélectionné » dans l'arbre
  /// d'accessibilité.
  void expectLevel(
    WidgetTester tester,
    Finder panel,
    int level, {
    required bool reached,
  }) {
    expect(
      tester.getSemantics(
        find.descendant(
          of: panel,
          matching: find.bySemanticsLabel('Niveau $level'),
        ),
      ),
      isSemantics(label: 'Niveau $level', isSelected: reached),
    );
  }

  /// Tape la moitié haute (un point de plus) ou basse (un de moins).
  Future<void> tapHalf(
    WidgetTester tester,
    Finder panel, {
    required bool top,
  }) async {
    final center = tester.getCenter(panel);
    await tester.tapAt(center + Offset(0, top ? -70 : 70));
    await tester.pumpAndSettle();
  }

  testWidgets('la configuration mène à la table', (tester) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();

    expect(find.text('Compteur de partie'), findsOneWidget);
    expect(find.text('Duel'), findsOneWidget);
    expect(find.text('Chambre magmatique'), findsOneWidget);
    expect(find.text('Victoire 11'), findsOneWidget);

    // Le tirage occupe tout l'écran et annonce qui commence.
    await tester.tap(find.text('Tirer le premier joueur'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawOverlay), findsOneWidget);
    expect(find.text('PREMIER JOUEUR'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DrawOverlay),
        matching: find.textContaining('commence.'),
      ),
      findsOneWidget,
    );
    // La fermeture de la roue lance la partie sans second geste : un tap
    // n'importe où sur l'écran suffit.
    await tester.tap(find.text('PREMIER JOUEUR'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawOverlay), findsNothing);

    final game = gameOf(tester);
    expect(game, isNotNull);
    expect(game!.mode, GameMode.duel);
    expect(game.players.length, 2);
    expect(game.players.every((player) => player.legend == null), isTrue);
    // La puce centrale annonce le joueur actif : le suivi du tour se lit.
    expect(find.text('AU TOUR DE'), findsOneWidget);
    expect(find.byType(PlayerPanel), findsNWidgets(2));
  });

  testWidgets('un tap ajoute puis retire un point', (tester) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();
    await startGame(tester);

    final panel = panelOf('Joueur 1');
    await tapHalf(tester, panel, top: true);
    expect(gameOf(tester)!.scoreOfTeam(0), 1);
    expect(
      find.descendant(of: panel, matching: find.text('1')),
      findsOneWidget,
    );

    await tapHalf(tester, panel, top: true);
    expect(gameOf(tester)!.scoreOfTeam(0), 2);

    await tapHalf(tester, panel, top: false);
    expect(gameOf(tester)!.scoreOfTeam(0), 1);
    expect(gameOf(tester)!.scoreOfTeam(1), 0);
  });

  testWidgets('la puce du joueur actif passe la main, « annuler » la rend', (
    tester,
  ) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();
    await startGame(tester);

    final game = gameOf(tester)!;
    final first = game.activePlayer.id;
    // La puce porte le nom du joueur actif…
    expect(find.byTooltip('Passer au joueur suivant'), findsOneWidget);
    await tester.tap(find.byTooltip('Passer au joueur suivant'));
    await tester.pumpAndSettle();

    // …et l'appui passe la main : elle affiche le suivant.
    expect(gameOf(tester)!.activePlayer.id, isNot(first));
    expect(gameOf(tester)!.turnNumber, 2);

    await tester.tap(find.byTooltip('Annuler'));
    await tester.pumpAndSettle();
    expect(gameOf(tester)!.activePlayer.id, first);
    expect(gameOf(tester)!.turnNumber, 1);
  });

  testWidgets('la victoire s’affiche au huitième point', (tester) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();
    await startGame(tester);

    final panel = panelOf('Joueur 1');
    for (var point = 0; point < 8; point++) {
      await tapHalf(tester, panel, top: true);
    }

    expect(gameOf(tester)!.winnerTeam, 0);
    expect(find.text('Victoire'), findsOneWidget);
    expect(find.text('Joueur 1'), findsWidgets);
    expect(find.text('Score 8'), findsOneWidget);
    expect(find.text('Nouvelle partie'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);
    // Mouvement réduit : pas de confettis, et l'écran se stabilise.
    expect(confettiPainters(tester), isEmpty);
    expect(find.text('Encore !'), findsNothing);
  });

  testWidgets('l’XP gagnée allume le repère de niveau', (tester) async {
    // L'arbre d'accessibilité porte l'état des repères : un niveau atteint
    // est un élément « sélectionné ».
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();
    await startGame(tester);

    final panel = panelOf('Joueur 1');
    expectLevel(tester, panel, 1, reached: false);

    await tester.tap(
      find.descendant(of: panel, matching: find.byTooltip('Gagner 1 XP')),
    );
    await tester.pumpAndSettle();

    final game = gameOf(tester)!;
    expect(game.xpOf(game.playerById('p0')!), 1);
    expect(game.xpOf(game.playerById('p1')!), 0);
    expectLevel(tester, panel, 1, reached: true);
    expectLevel(tester, panel, 2, reached: false);

    // Le score, lui, n'a pas bougé : l'XP est une ressource à part.
    expect(game.scoreOfTeam(0), 0);
    semantics.dispose();
  });

  testWidgets('en 2c2, le score est commun mais pas l’XP', (tester) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chambre magmatique'));
    await tester.pumpAndSettle();
    await startGame(tester);

    final game = gameOf(tester)!;
    expect(game.mode, GameMode.magmaChamber);
    expect(find.byType(PlayerPanel), findsNWidgets(4));
    // Un score partagé par équipe, posé entre les deux coéquipiers.
    expect(find.text('ÉQUIPE'), findsNWidgets(2));

    await tester.tap(
      find.descendant(
        of: panelOf('Joueur 1'),
        matching: find.byTooltip('Gagner 1 XP'),
      ),
    );
    await tester.pumpAndSettle();

    final after = gameOf(tester)!;
    expect(after.xpOf(after.playerById('p0')!), 1);
    expect(
      after.xpOf(after.playerById('p1')!),
      0,
      reason: 'XP jamais partagée',
    );
  });

  testWidgets('l’appui long ouvre la feuille et applique l’exténuation', (
    tester,
  ) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();
    await startGame(tester);

    await tester.longPressAt(
      tester.getCenter(panelOf('Joueur 1')) - const Offset(0, 70),
    );
    await tester.pumpAndSettle();

    expect(find.text('EXTÉNUATION'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Chasse 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Chasse 2'));
    await tester.pumpAndSettle();
    expect(gameOf(tester)!.xpOf(gameOf(tester)!.playerById('p0')!), 2);

    // Piocher dans un deck vide donne un point à l'adversaire, pas à soi.
    await tester.tap(find.widgetWithText(ActionChip, 'Joueur 2'));
    await tester.pumpAndSettle();

    final game = gameOf(tester)!;
    expect(game.scoreOfTeam(1), 1);
    expect(game.scoreOfTeam(0), 0);
  });

  testWidgets('à quatre sur petit écran, chaque panneau garde sa barre d’XP', (
    tester,
  ) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guerre'));
    await tester.pumpAndSettle();
    await startGame(tester);

    // Taille téléphone : les quatre panneaux se partagent l'écran. Un
    // débordement ferait échouer le test ; l'XP doit rester visible partout.
    tester.view.physicalSize = const Size(400, 780);
    await tester.pumpAndSettle();

    expect(find.byType(PlayerPanel), findsNWidgets(4));
    expect(find.byType(XpBar), findsNWidgets(4));
    expect(find.byTooltip('Gagner 1 XP'), findsNWidgets(4));

    // L'ordre des tours fait le tour de la table : J1 bas-gauche, J2
    // bas-droite, J3 haut-droite, J4 haut-gauche — pas de diagonale.
    final j1 = tester.getCenter(panelOf('Joueur 1'));
    final j2 = tester.getCenter(panelOf('Joueur 2'));
    final j3 = tester.getCenter(panelOf('Joueur 3'));
    final j4 = tester.getCenter(panelOf('Joueur 4'));
    expect(j1.dy, greaterThan(j3.dy));
    expect(j2.dy, greaterThan(j4.dy));
    expect(j1.dx, lessThan(j2.dx));
    expect(j3.dx, greaterThan(j4.dx));

    // Même exigence en 2c2, où les panneaux sont encore plus étroits.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Quitter'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(520, 2600);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chambre magmatique'));
    await tester.pumpAndSettle();
    await startGame(tester);

    tester.view.physicalSize = const Size(400, 780);
    await tester.pumpAndSettle();
    expect(find.byType(XpBar), findsNWidgets(4));
  });

  testWidgets('la table retient ses joueurs pour la partie suivante', (
    tester,
  ) async {
    final store = InMemoryGameStore();
    await tester.pumpWidget(gameApp(tester: tester, store: store));
    await tester.pumpAndSettle();

    // Trois joueurs nommés, puis la partie démarre.
    await tester.tap(find.text('Escarmouche'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Nathan');
    await tester.enterText(find.byType(TextField).at(1), 'Léa');
    await startGame(tester);
    expect(gameOf(tester), isNotNull);

    // Quitter efface la partie en cours, pas la table.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Quitter'));
    await tester.pumpAndSettle();
    expect(gameOf(tester), isNull);

    // La configuration revient préremplie : noms retrouvés, et le format
    // aussi (l'escarmouche affiche trois champs de nom).
    expect(find.widgetWithText(TextField, 'Nathan'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Léa'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('la table allume l’écran, quitter rend la veille', (
    tester,
  ) async {
    final awake = FakeScreenAwake();
    await tester.pumpWidget(gameApp(tester: tester, awake: awake));
    await tester.pumpAndSettle();
    expect(awake.enables, 0, reason: 'la configuration n’allume rien');

    await startGame(tester);
    expect(awake.enables, 1);
    expect(awake.disables, 0);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Quitter'));
    await tester.pumpAndSettle();

    expect(gameOf(tester), isNull);
    expect(awake.disables, 1, reason: 'la veille du système reprend la main');
  });

  testWidgets('une partie sauvegardée se reprend', (tester) async {
    var saved = GameEngine.start(
      mode: GameMode.skirmish,
      players: GameEngine.defaultPlayers(GameMode.skirmish),
      firstPlayerId: 'p1',
    );
    saved = GameEngine.addPoint(saved, playerId: 'p2');
    saved = GameEngine.addPoint(saved, playerId: 'p2');
    saved = GameEngine.addXp(saved, playerId: 'p1', amount: 3);
    final store = InMemoryGameStore(
      jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
    );

    await tester.pumpWidget(gameApp(tester: tester, store: store));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre la partie'), findsOneWidget);
    expect(find.text('Escarmouche'), findsWidgets);

    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();

    final game = gameOf(tester)!;
    expect(game.mode, GameMode.skirmish);
    expect(game.players.length, 3);
    expect(game.scoreOfTeam(2), 2);
    expect(game.xpOf(game.playerById('p1')!), 3);
    expect(game.activePlayer.id, 'p1');
    expect(find.byType(PlayerPanel), findsNWidgets(3));
  });
}
