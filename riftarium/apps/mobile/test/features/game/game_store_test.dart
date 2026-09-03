import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/game/data/game_store.dart';
import 'package:riftarium_mobile/features/game/domain/game_engine.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';
import 'package:riftarium_mobile/features/game/domain/player.dart';
import 'package:riftarium_mobile/features/game/domain/saved_table.dart';

import 'support/in_memory_game_store.dart';

void main() {
  makeGame() => GameEngine.start(
    mode: GameMode.match,
    players: GameEngine.defaultPlayers(GameMode.match),
  );

  test('la sauvegarde en mémoire relit la partie écrite', () async {
    final store = InMemoryGameStore();
    expect(await store.read(), isNull);

    var state = makeGame();
    state = GameEngine.addPoint(state, playerId: 'p0');
    state = GameEngine.addXp(state, playerId: 'p1', amount: 2);
    expect(await store.write(state), isTrue);
    expect(store.writes, 1);

    final restored = await store.read();
    expect(restored, isNotNull);
    expect(restored!.mode, GameMode.match);
    expect(restored.scoreOfTeam(0), 1);
    expect(restored.xpOf(restored.playerById('p1')!), 2);

    await store.clear();
    expect(await store.read(), isNull);
  });

  test('la sauvegarde sur disque écrit un fichier relisible', () async {
    final directory = await Directory.systemTemp.createTemp('riftarium-game');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileGameStore(directory: () async => directory);

    expect(await store.read(), isNull);
    final state = GameEngine.addPoint(makeGame(), playerId: 'p1');
    expect(await store.write(state), isTrue);

    final file = File(
      '${directory.path}${Platform.pathSeparator}$kGameSaveFileName',
    );
    expect(file.existsSync(), isTrue);

    final restored = await store.read();
    expect(restored?.scoreOfTeam(1), 1);

    await store.clear();
    expect(file.existsSync(), isFalse);
    expect(await store.read(), isNull);
  });

  test(
    'un fichier abîmé est ignoré plutôt que de faire échouer l’écran',
    () async {
      final directory = await Directory.systemTemp.createTemp('riftarium-game');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileGameStore(directory: () async => directory);
      File(
        '${directory.path}${Platform.pathSeparator}$kGameSaveFileName',
      ).writeAsStringSync('{ pas du json');

      expect(await store.read(), isNull);
    },
  );

  test('la table retient légendes, équipes et durée de ronde', () {
    const legend = RiftCard(
      id: 'OGN-001',
      riftboundId: 'RB-JINX',
      name: 'Jinx',
      setId: 'OGN',
      type: 'Legend',
      rarity: 'Épique',
      domains: ['Chaos'],
      tags: [],
      collectorNumber: 12,
      alternateArt: true,
    );
    final table = SavedTable(
      mode: GameMode.magmaChamber,
      players: [
        for (var seat = 0; seat < 4; seat++)
          Player(
            id: 'p\$seat',
            name: 'Joueur \${seat + 1}',
            seat: seat,
            // Équipes croisées : ce n'est pas la répartition par défaut.
            team: seat.isEven ? 1 : 0,
            legend: seat == 0 ? legend : null,
          ),
      ],
      roundLimit: const Duration(minutes: 45),
    );

    final back = SavedTable.fromJson(jsonDecode(jsonEncode(table.toJson())))!;
    expect(back.mode, GameMode.magmaChamber);
    expect(back.players.map((player) => player.team), [1, 0, 1, 0]);
    expect(back.players.first.legend?.name, 'Jinx');
    expect(back.players.first.legend?.alternateArt, isTrue);
    expect(back.players.last.legend, isNull);
    expect(back.roundLimit, const Duration(minutes: 45));

    // Table d'avant ce champ : la durée repart de la valeur par défaut.
    final old = Map<String, dynamic>.from(table.toJson())
      ..remove('round_limit_s');
    expect(SavedTable.fromJson(old)!.roundLimit, isNull);
  });

  test('la dernière table survit à l’effacement de la partie', () async {
    final directory = await Directory.systemTemp.createTemp('riftarium-game');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileGameStore(directory: () async => directory);

    expect(await store.readTable(), isNull);
    final game = makeGame();
    final table = SavedTable(mode: game.mode, players: game.players);
    expect(await store.writeTable(table), isTrue);

    // Quitter la partie efface la reprise, pas la table.
    await store.write(game);
    await store.clear();
    expect(await store.read(), isNull);

    final restored = await store.readTable();
    expect(restored, isNotNull);
    expect(restored!.mode, game.mode);
    expect(
      restored.players.map((player) => player.name),
      game.players.map((player) => player.name),
    );
  });
}
