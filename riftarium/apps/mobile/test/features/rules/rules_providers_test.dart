import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/rules/application/rules_providers.dart';
import 'package:riftarium_mobile/features/rules/data/rules_repository.dart';
import 'package:riftarium_mobile/features/rules/domain/rules.dart';

import '../../support/fakes.dart';
import 'rules_fixture.dart';

/// Asset qui n'arrive jamais : le document reste en chargement.
class _PendingAssets implements RulesAssetLoader {
  final Completer<String> _completer = Completer<String>();

  @override
  Future<String> load(String key) => _completer.future;
}

/// Asset servi immédiatement depuis la fixture.
class _FixtureAssets implements RulesAssetLoader {
  const _FixtureAssets();

  @override
  Future<String> load(String key) async => kRulesFixtureSource;
}

class _NoCache implements RulesCacheStore {
  _NoCache({this.writable = true});

  final bool writable;

  @override
  Future<String?> read() async => null;

  @override
  Future<bool> write(String source) async => writable;

  @override
  Future<void> clear() async {}
}

void main() {
  const remoteUrl = 'https://riftarium.test/data/rules-fr.json';
  const routeKey = 'GET $remoteUrl';

  ProviderContainer containerFor(RulesRepository repository) {
    final container = ProviderContainer(
      overrides: [rulesRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  RulesRepository repositoryWith({
    required RulesAssetLoader assets,
    RulesCacheStore? cache,
    FakeHttpAdapter? adapter,
  }) => RulesRepository(
    assets: assets,
    cache: cache ?? _NoCache(),
    parse: (source) async => parseRulesDocument(source),
    remoteUrl: remoteUrl,
    dio: Dio()..httpClientAdapter = adapter ?? FakeHttpAdapter({}),
  );

  test('« Actualiser » sans document : réponse neutre', () async {
    // Le chargement local n'est pas terminé : rien ne permet d'annoncer une
    // mise à jour, l'écran relance simplement le chargement.
    final container = containerFor(repositoryWith(assets: _PendingAssets()));
    final controller = container.read(rulesProvider.notifier);

    expect(await controller.refresh(), RulesRefreshOutcome.reloading);
  });

  test('« Actualiser » sans nouveauté en ligne : déjà à jour', () async {
    final container = containerFor(
      repositoryWith(
        assets: const _FixtureAssets(),
        adapter: FakeHttpAdapter({
          routeKey: const FakeResponse(200, kRulesFixture),
        }),
      ),
    );
    await container.read(rulesProvider.future);

    expect(
      await container.read(rulesProvider.notifier).refresh(),
      RulesRefreshOutcome.upToDate,
    );
  });

  test(
    'cache non écrit : la mise à jour est annoncée comme temporaire',
    () async {
      // Route absente au démarrage : la vérification de fond échoue, le
      // document local reste en place. Elle est ouverte juste avant
      // « Actualiser » pour que le test porte sur ce seul appel.
      final adapter = FakeHttpAdapter({});
      final container = containerFor(
        repositoryWith(
          assets: const _FixtureAssets(),
          cache: _NoCache(writable: false),
          adapter: adapter,
        ),
      );
      await container.read(rulesProvider.future);
      adapter.routes[routeKey] = FakeResponse(200, rulesFixtureUpdated());

      final controller = container.read(rulesProvider.notifier);
      expect(await controller.refresh(), RulesRefreshOutcome.updatedNotStored);
      // Le document rapatrié est tout de même affiché.
      expect(
        container.read(rulesProvider).valueOrNull?.core?.updated,
        '20 août 2026',
      );
    },
  );
}
