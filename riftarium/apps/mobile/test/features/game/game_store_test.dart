import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/game/data/game_store.dart';
import 'package:riftarium_mobile/features/game/domain/game_engine.dart';
import 'package:riftarium_mobile/features/game/domain/saved_table.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';

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
    expect(restored.xpOf(restored.playerById('p1')), 2);

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
