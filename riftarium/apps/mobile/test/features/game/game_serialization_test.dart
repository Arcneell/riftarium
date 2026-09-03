import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/game/domain/game_engine.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';
import 'package:riftarium_mobile/features/game/domain/game_state.dart';
import 'package:riftarium_mobile/features/game/domain/player.dart';

const _legend = RiftCard(
  id: 'OGN-001',
  riftboundId: 'RB-JINX',
  name: 'Jinx',
  setId: 'OGN',
  type: 'Legend',
  rarity: 'Épique',
  domains: ['Chaos'],
  tags: [],
  collectorNumber: 12,
  imageUrl: 'https://cdn.test/jinx.png',
  alternateArt: true,
);

void main() {
  final now = DateTime.utc(2026, 8, 28, 20, 30);

  test('une partie fait l’aller-retour par le JSON', () {
    final mode = GameMode.magmaChamber;
    var state = GameEngine.start(
      mode: mode,
      players: [
        for (var seat = 0; seat < 4; seat++)
          Player(
            id: 'p$seat',
            name: 'Joueur ${seat + 1}',
            seat: seat,
            team: mode.defaultTeam(seat),
            legend: seat == 0 ? _legend : null,
          ),
      ],
      firstPlayerId: 'p2',
      startedAt: now.subtract(const Duration(minutes: 7, seconds: 12)),
    );
    state = GameEngine.addPoint(state, playerId: 'p0');
    state = GameEngine.addXp(state, playerId: 'p0', amount: 3);
    state = GameEngine.addXp(state, playerId: 'p3', amount: 1);
    state = GameEngine.nextTurn(state);

    final source = jsonEncode(state.toJson(now: now));
    final restored = GameState.fromJson(jsonDecode(source), now: now);

    expect(restored, isNotNull);
    expect(restored!.mode, GameMode.magmaChamber);
    expect(restored.turnOrder, state.turnOrder);
    expect(restored.turnIndex, state.turnIndex);
    expect(restored.turnNumber, state.turnNumber);
    expect(restored.round, state.round);
    expect(restored.startedAt, state.startedAt);
    expect(restored.scoreOfTeam(0), 1);
    expect(restored.scoreOfTeam(1), 0);
    expect(restored.xpOf(restored.playerById('p0')!), 3);
    expect(restored.xpOf(restored.playerById('p1')!), 0);
    expect(restored.xpOf(restored.playerById('p3')!), 1);
    expect(restored.history.length, state.history.length);
    expect(restored.players[0].legend?.name, 'Jinx');
    expect(restored.players[0].legend?.alternateArt, isTrue);
    expect(restored.players[0].color, state.players[0].color);
    expect(restored.players[1].legend, isNull);
  });

  test('le chronomètre repart de la durée déjà jouée', () {
    final state = GameEngine.start(
      mode: GameMode.duel,
      players: GameEngine.defaultPlayers(GameMode.duel),
      startedAt: now.subtract(const Duration(minutes: 3)),
    );
    final json = state.toJson(now: now);
    expect(json['elapsed_us'], const Duration(minutes: 3).inMicroseconds);

    // Relue une heure plus tard, la partie affiche toujours trois minutes.
    final later = now.add(const Duration(hours: 1));
    final restored = GameState.fromJson(json, now: later)!;
    expect(later.difference(restored.startedAt), const Duration(minutes: 3));
  });

  test('un JSON inexploitable ne casse rien', () {
    expect(GameState.fromJson(null), isNull);
    expect(GameState.fromJson('partie'), isNull);
    expect(GameState.fromJson(const {'mode': 'inconnu'}), isNull);
    expect(GameState.fromJson(const {'mode': 'duel'}), isNull);
    expect(
      GameState.fromJson(const {
        'mode': 'duel',
        'players': [
          {'id': 'p0', 'name': 'A', 'seat': 0, 'team': 0},
        ],
        'turn_order': ['p9'],
      }),
      isNull,
      reason: 'un ordre de tours qui ne cite personne est illisible',
    );
  });
}
