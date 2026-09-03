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
  _MemoryCache([this.stored, this.writable = true]);

  String? stored;

  /// Simule un disque plein : l'écriture échoue.
  final bool writable;
  int writes = 0;
  int clears = 0;

  @override
  Future<String?> read() async => stored;

  @override
  Future<bool> write(String source) async {
    writes++;
    if (!writable) return false;
    stored = source;
    return true;
  }

  @override
  Future<void> clear() async {
    clears++;
    stored = null;
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

  test('cache plus récent que l’asset : le cache gagne', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache(jsonEncode(rulesFixtureUpdated()));
    final document = await build(assets: assets, cache: cache).load();

    expect(document.core?.updated, '20 août 2026');
    // Le fichier téléchargé reste en place.
    expect(cache.clears, 0);
    expect(cache.stored, isNotNull);
  });

  test('asset plus récent que le cache : le cache périmé est jeté', () async {
    // L'application a été mise à jour avec un texte plus récent que celui
    // téléchargé la dernière fois.
    final assets = _FakeAssets(
      jsonEncode(rulesFixtureUpdated(updated: '5 septembre 2026')),
    );
    final cache = _MemoryCache(
      jsonEncode(rulesFixtureUpdated(updated: '20 août 2026')),
    );
    final document = await build(assets: assets, cache: cache).load();

    expect(document.core?.updated, '5 septembre 2026');
    expect(cache.clears, 1);
    expect(cache.stored, isNull);
  });

  test('même date des deux côtés : le cache est conservé', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache(
      jsonEncode(rulesFixtureUpdated(updated: '16 juillet 2026', ruleCount: 9)),
    );
    final document = await build(assets: assets, cache: cache).load();

    expect(document.core?.ruleCount, 9);
    expect(cache.clears, 0);
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
      final update = await repository.fetchUpdate(current);

      expect(update?.document.core?.updated, '20 août 2026');
      expect(update?.stored, isTrue);
      expect(cache.writes, 1);

      // Au démarrage suivant, c'est la version enregistrée qui est lue.
      final next = await build(assets: assets, cache: cache).load();
      expect(next.core?.updated, '20 août 2026');
    },
  );

  test('écriture du cache impossible : `stored` est faux', () async {
    final assets = _FakeAssets(kRulesFixtureSource);
    final cache = _MemoryCache(null, false);
    final repository = build(
      assets: assets,
      cache: cache,
      adapter: FakeHttpAdapter({
        routeKey: FakeResponse(200, rulesFixtureUpdated()),
      }),
    );

    final current = await repository.load();
    final update = await repository.fetchUpdate(current);

    // Le document est servi (l'écran se met à jour) mais rien n'est conservé.
    expect(update?.document.core?.updated, '20 août 2026');
    expect(update?.stored, isFalse);
    expect(cache.stored, isNull);
  });

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
