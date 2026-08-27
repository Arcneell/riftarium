import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/rules/data/rules_repository.dart';
import 'package:riftarium_mobile/features/rules/domain/rules.dart';

import '../../support/fakes.dart';
import 'rules_fixture.dart';

/// Asset simulé : renvoie la fixture au lieu de `rootBundle`.
class _FakeAssets implements RulesAssetLoader {
  _FakeAssets(this.source);

  final String source;
  final List<String> loaded = [];

  @override
  Future<String> load(String key) async {
    loaded.add(key);
    return source;
  }
}

/// Cache en mémoire à la place du dossier documents.
class _MemoryCache implements RulesCacheStore {
  _MemoryCache([this.stored]);

  String? stored;
  int writes = 0;

  @override
  Future<String?> read() async => stored;

  @override
  Future<bool> write(String source) async {
    writes++;
    stored = source;
    return true;
  }
}

void main() {
  const remoteUrl = 'https://riftarium.test/data/rules-fr.json';
  const routeKey = 'GET $remoteUrl';

  // Décodage synchrone : `compute` lancerait une isolate dans les tests.
  Future<RulesDocument> parse(String source) async =>
      parseRulesDocument(source);

  RulesRepository build({
    required _FakeAssets assets,
    required _MemoryCache cache,
    FakeHttpAdapter? adapter,
  }) => RulesRepository(
    assets: assets,
    cache: cache,
    parse: parse,
    assetKey: 'assets/rules/rules-fr.json',
    remoteUrl: remoteUrl,
    dio: Dio()..httpClientAdapter = adapter ?? FakeHttpAdapter({}),
  );

  test('sans cache, l’asset embarqué est utilisé', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache();
    final document = await build(assets: assets, cache: cache).load();

    expect(assets.loaded, ['assets/rules/rules-fr.json']);
    expect(document.core?.updated, '16 juillet 2026');
  });

  test('le fichier du dossier documents est prioritaire sur l’asset', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache(jsonEncode(rulesFixtureUpdated()));
    final document = await build(assets: assets, cache: cache).load();

    expect(assets.loaded, isEmpty);
    expect(document.core?.updated, '20 août 2026');
  });

  test('un cache illisible ne bloque pas : retour à l’asset', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache('{ ceci n’est pas du JSON');
    final document = await build(assets: assets, cache: cache).load();

    expect(assets.loaded, isNotEmpty);
    expect(document.core?.ruleCount, 5);
  });

  test('même version en ligne : rien n’est écrit', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache();
    final repository = build(
      assets: assets,
      cache: cache,
      adapter: FakeHttpAdapter({
        routeKey: const FakeResponse(200, kRulesFixture),
      }),
    );

    final current = await repository.load();
    expect(await repository.fetchUpdate(current), isNull);
    expect(cache.writes, 0);
  });

  test(
    'version en ligne différente : elle est servie et enregistrée',
    () async {
      final assets = _FakeAssets(kRulesFixtureSource);
      final cache = _MemoryCache();
      final repository = build(
        assets: assets,
        cache: cache,
        adapter: FakeHttpAdapter({
          routeKey: FakeResponse(200, rulesFixtureUpdated()),
        }),
      );

      final current = await repository.load();
      final fresh = await repository.fetchUpdate(current);

      expect(fresh?.core?.updated, '20 août 2026');
      expect(cache.writes, 1);

      // Au démarrage suivant, c'est la version enregistrée qui est lue.
      final next = await build(assets: assets, cache: cache).load();
      expect(next.core?.updated, '20 août 2026');
    },
  );

  test('réseau absent : l’erreur remonte, la version locale reste', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache();
    final repository = build(
      assets: assets,
      cache: cache,
      adapter: FakeHttpAdapter({routeKey: const FakeResponse.networkError()}),
    );

    final current = await repository.load();
    await expectLater(
      repository.fetchUpdate(current),
      throwsA(isA<DioException>()),
    );
    expect(cache.writes, 0);
    expect(current.core?.updated, '16 juillet 2026');
  });

  test('le décodage dans une isolate renvoie un document utilisable', () async {
    // `compute` transfère l'objet entre isolates : on vérifie que les modèles
    // (champs `late final` compris) traversent bien la frontière.
    final document = await parseRulesInIsolate(kRulesFixtureSource);

    expect(document.core?.title, 'Règles du jeu');
    expect(document.locate('198.1.')?.entry?.id, '198-1');
    expect(searchRules(document, 'gachette'), hasLength(1));
  });
}
