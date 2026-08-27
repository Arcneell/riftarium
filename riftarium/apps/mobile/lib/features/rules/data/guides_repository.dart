import 'package:flutter/foundation.dart';

import '../domain/guides.dart';
import 'rules_repository.dart';

/// Guides embarqués (déclarés dans `pubspec.yaml`), export de
/// `apps/web/src/rules/topics.js` + `guide.js`.
const String kGuidesAssetKey = 'assets/rules/guides-fr.json';

/// Décodage du JSON : injecté pour que les tests restent synchrones.
typedef GuidesParser = Future<GuidesDocument> Function(String source);

/// Décodage hors du thread UI (175 Ko de JSON).
Future<GuidesDocument> parseGuidesInIsolate(String source) =>
    compute(parseGuidesDocument, source);

/// Accès aux guides : uniquement l'asset embarqué (ils suivent la version de
/// l'application, contrairement au texte officiel qui se met à jour en ligne).
class GuidesRepository {
  const GuidesRepository({
    RulesAssetLoader assets = const BundleRulesAssetLoader(),
    GuidesParser parse = parseGuidesInIsolate,
    String assetKey = kGuidesAssetKey,
  }) : _assets = assets,
       _parse = parse,
       _assetKey = assetKey;

  final RulesAssetLoader _assets;
  final GuidesParser _parse;
  final String _assetKey;

  Future<GuidesDocument> load() async => _parse(await _assets.load(_assetKey));
}
