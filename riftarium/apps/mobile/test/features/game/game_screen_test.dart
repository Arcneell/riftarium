import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/game/data/game_store.dart';
import 'package:riftarium_mobile/features/game/domain/game_engine.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';
import 'package:riftarium_mobile/features/game/ui/widgets/player_panel.dart';

import 'support/game_app.dart';

void main() {
  /// Panneau du joueur nommé `name` : les tests visent une place précise
  /// autour de la table, pas un rang dans l'arbre de widgets.
  Finder panelOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PlayerPanel));

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

    await startGame(tester);

    final game = gameOf(tester);
    expect(game, isNotNull);
    expect(game!.mode, GameMode.duel);
    expect(game.players.length, 2);
    expect(game.players.every((player) => player.legend == null), isTrue);
    expect(find.text('Tour suivant'), findsOneWidget);
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

  testWidgets('« Tour suivant » passe la main et « annuler » la rend', (
    tester,
  ) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();
    await startGame(tester);

    final first = gameOf(tester)!.activePlayer.id;
    await tester.tap(find.text('Tour suivant'));
    await tester.pumpAndSettle();

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
    expect(game.xpOf(game.playerById('p0')), 1);
    expect(game.xpOf(game.playerById('p1')), 0);
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
    expect(after.xpOf(after.playerById('p0')), 1);
    expect(after.xpOf(after.playerById('p1')), 0, reason: 'XP jamais partagée');
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
    expect(gameOf(tester)!.xpOf(gameOf(tester)!.playerById('p0')), 2);

    // Piocher dans un deck vide donne un point à l'adversaire, pas à soi.
    await tester.tap(find.widgetWithText(ActionChip, 'Joueur 2'));
    await tester.pumpAndSettle();

    final game = gameOf(tester)!;
    expect(game.scoreOfTeam(1), 1);
    expect(game.scoreOfTeam(0), 0);
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
    expect(game.xpOf(game.playerById('p1')), 3);
    expect(game.activePlayer.id, 'p1');
    expect(find.byType(PlayerPanel), findsNWidgets(3));
  });
}
