import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';
import 'package:riftarium_mobile/features/game/ui/widgets/player_panel.dart';

import 'support/game_app.dart';

void main() {
  Finder panelOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(PlayerPanel));

  /// Un point de plus sur un panneau. Le panneau du haut est tourné de 180° :
  /// sa moitié « plus » est en bas de l'écran.
  Future<void> addPoint(
    WidgetTester tester,
    Finder panel, {
    required bool rotated,
  }) async {
    final center = tester.getCenter(panel);
    await tester.tapAt(center + Offset(0, rotated ? 70 : -70));
    await tester.pumpAndSettle();
  }

  /// Ouvre la configuration en mode Tournoi et tire le joueur désigné. Renvoie
  /// le nom du joueur désigné.
  Future<String> drawDesignated(WidgetTester tester) async {
    await tester.pumpWidget(gameApp(tester: tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tournoi'));
    await tester.pumpAndSettle();
    expect(find.text('RONDE'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget);

    await tester.tap(find.text('Tirer le joueur désigné'));
    await tester.pumpAndSettle();
    expect(find.text('JOUEUR DÉSIGNÉ'), findsOneWidget);
    await tester.tap(find.text('JOUEUR DÉSIGNÉ'));
    await tester.pumpAndSettle();

    // La roue refermée, la partie n'a pas démarré : le désigné choisit.
    expect(gameOf(tester), isNull);
    final choice = tester.widget<Text>(find.textContaining('joue en second'));
    return choice.data!.replaceFirst(' joue en second', '');
  }

  Future<void> passTurn(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Passer au joueur suivant'));
    await tester.pumpAndSettle();
  }

  testWidgets('le joueur désigné choisit de jouer en second', (tester) async {
    final designated = await drawDesignated(tester);
    await tester.tap(find.text('$designated joue en second'));
    await tester.pumpAndSettle();

    final game = gameOf(tester)!;
    expect(game.mode, GameMode.tournament);
    expect(game.roundLimit, kTournamentRoundLimit);
    expect(game.activePlayer.name, isNot(designated));
    expect(find.text('M1 · RONDE'), findsOneWidget);
  });

  testWidgets('le joueur désigné choisit de commencer', (tester) async {
    final designated = await drawDesignated(tester);
    await tester.tap(find.text('$designated commence'));
    await tester.pumpAndSettle();
    expect(gameOf(tester)!.activePlayer.name, designated);
  });

  testWidgets('fin du temps annoncée : trois tours puis égalité et match nul', (
    tester,
  ) async {
    final designated = await drawDesignated(tester);
    await tester.tap(find.text('$designated commence'));
    await tester.pumpAndSettle();

    // 6 à 5 : moins de deux points d'écart.
    for (var point = 0; point < 6; point++) {
      await addPoint(tester, panelOf('Joueur 1'), rotated: false);
    }
    for (var point = 0; point < 5; point++) {
      await addPoint(tester, panelOf('Joueur 2'), rotated: true);
    }
    expect(gameOf(tester)!.scoreOfTeam(0), 6);
    expect(gameOf(tester)!.scoreOfTeam(1), 5);

    await tester.tap(find.byTooltip('Menu de la partie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annoncer la fin du temps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temps écoulé'));
    await tester.pumpAndSettle();

    expect(gameOf(tester)!.timeCalled, isTrue);
    expect(find.text('TEMPS ÉCOULÉ'), findsOneWidget);
    expect(find.text('fin du tour'), findsOneWidget);

    await passTurn(tester);
    expect(find.text('+1/3'), findsOneWidget);
    await passTurn(tester);
    await passTurn(tester);
    expect(find.text('+3/3'), findsOneWidget);
    expect(gameOf(tester)!.isOver, isFalse);

    await passTurn(tester);
    final game = gameOf(tester)!;
    expect(game.drawn, isTrue);
    expect(game.isMatchDrawn, isTrue);
    expect(find.text('Égalité'), findsOneWidget);
    expect(find.text('Match nul'), findsOneWidget);
    expect(find.text('Manche suivante'), findsNothing);
  });

  testWidgets('deux points d’avance au temps : victoire au temps et match', (
    tester,
  ) async {
    final designated = await drawDesignated(tester);
    await tester.tap(find.text('$designated commence'));
    await tester.pumpAndSettle();

    for (var point = 0; point < 3; point++) {
      await addPoint(tester, panelOf('Joueur 1'), rotated: false);
    }
    await tester.tap(find.byTooltip('Menu de la partie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annoncer la fin du temps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temps écoulé'));
    await tester.pumpAndSettle();
    for (var turn = 0; turn < 4; turn++) {
      await passTurn(tester);
    }

    final game = gameOf(tester)!;
    expect(game.winnerTeam, 0);
    expect(game.matchWinnerTeam, 0);
    expect(find.text('Victoire au temps'), findsOneWidget);
    expect(find.text('Joueur 1 remporte le match'), findsOneWidget);
  });

  testWidgets('le perdant de la manche choisit qui commence la suivante', (
    tester,
  ) async {
    final designated = await drawDesignated(tester);
    await tester.tap(find.text('$designated commence'));
    await tester.pumpAndSettle();

    for (var point = 0; point < 8; point++) {
      await addPoint(tester, panelOf('Joueur 1'), rotated: false);
    }
    expect(gameOf(tester)!.winnerTeam, 0);
    expect(find.text('Victoire'), findsOneWidget);
    expect(
      find.text('Joueur 2 a perdu la manche : il choisit qui commence.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Joueur 2 commence'));
    await tester.pumpAndSettle();

    final game = gameOf(tester)!;
    expect(game.round, 2);
    expect(game.activePlayer.name, 'Joueur 2');
    expect(game.scoreOfTeam(0), 0);
    expect(game.roundsWonBy(0), 1);
    expect(find.text('M2 · RONDE'), findsOneWidget);
  });
}
