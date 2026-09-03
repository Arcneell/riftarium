import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/rules/application/guides_providers.dart';
import 'package:riftarium_mobile/features/rules/application/rules_providers.dart';
import 'package:riftarium_mobile/features/rules/data/guides_repository.dart';
import 'package:riftarium_mobile/features/rules/data/rules_repository.dart';
import 'package:riftarium_mobile/features/rules/domain/guides.dart';
import 'package:riftarium_mobile/features/rules/domain/rules.dart';
import 'package:riftarium_mobile/main.dart';

import '../../../support/fakes.dart';
import '../guides_fixture.dart';
import '../rules_fixture.dart';

/// URL du texte officiel en ligne, utilisée par les tests de mise à jour.
const String kTestRemoteRulesUrl = 'https://riftarium.test/data/rules-fr.json';
const String kTestRemoteRulesRoute = 'GET $kTestRemoteRulesUrl';

/// Assets de test : les deux fichiers de règles, servis depuis les fixtures.
class FixtureAssets implements RulesAssetLoader {
  const FixtureAssets();

  @override
  Future<String> load(String key) async =>
      key == kGuidesAssetKey ? kGuidesFixtureSource : kRulesFixtureSource;
}

class NoRulesCache implements RulesCacheStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<bool> write(String source) async => true;

  @override
  Future<void> clear() async {}
}

/// Application complète, câblée sur les fixtures : le routeur réel permet de
/// vérifier la navigation entre les trois paliers.
///
/// `size` : l'écran de test est allongé pour que les longues pages tiennent
/// sans défilement (les listes restent paresseuses en production).
Widget rulesApp({
  required WidgetTester tester,
  String location = AppRoutes.rules,
  FakeHttpAdapter? rulesAdapter,
  Size size = const Size(520, 3200),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store = InMemoryTokenStore();
  return ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      dioProvider.overrideWith(
        (ref) => createApiClient(
          readToken: store.read,
          baseUrl: 'https://api.test/api',
          adapter: FakeHttpAdapter({}),
        ),
      ),
      initialLocationProvider.overrideWithValue(location),
      rulesRepositoryProvider.overrideWithValue(
        RulesRepository(
          assets: const FixtureAssets(),
          cache: NoRulesCache(),
          parse: (source) async => parseRulesDocument(source),
          remoteUrl: kTestRemoteRulesUrl,
          dio: Dio()..httpClientAdapter = rulesAdapter ?? FakeHttpAdapter({}),
        ),
      ),
      guidesRepositoryProvider.overrideWithValue(
        const GuidesRepository(
          assets: FixtureAssets(),
          parse: parseGuidesFixture,
        ),
      ),
    ],
    child: const RiftariumApp(),
  );
}

/// Laisse passer les animations *et* les minuteurs des `Reveal` (apparition
/// en cascade) : un test qui se termine sur un minuteur en attente échoue.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

/// Décodage synchrone : pas d'isolate dans les tests.
Future<GuidesDocument> parseGuidesFixture(String source) async =>
    parseGuidesDocument(source);
