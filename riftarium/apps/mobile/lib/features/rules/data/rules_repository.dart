import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config.dart';
import '../domain/rules.dart';

/// Copie embarquée du texte officiel (déclarée dans `pubspec.yaml`).
const String kRulesAssetKey = 'assets/rules/rules-fr.json';

/// Version rapatriée depuis le site, dans le dossier documents.
const String kRulesCacheFileName = 'rules-fr.json';

/// Fichier statique servi par nginx (hors `/api`).
const String kRulesRemoteUrl = '${AppConfig.webBaseUrl}/data/rules-fr.json';

/// Décodage du JSON : injecté pour que les tests restent synchrones.
typedef RulesParser = Future<RulesDocument> Function(String source);

/// Décodage hors du thread UI (783 Ko de JSON).
Future<RulesDocument> parseRulesInIsolate(String source) =>
    compute(parseRulesDocument, source);

/// Lecture des assets, remplaçable dans les tests.
abstract class RulesAssetLoader {
  Future<String> load(String key);
}

class BundleRulesAssetLoader implements RulesAssetLoader {
  const BundleRulesAssetLoader();

  @override
  Future<String> load(String key) => rootBundle.loadString(key);
}

/// Copie locale de la dernière version téléchargée.
abstract class RulesCacheStore {
  /// Contenu en cache, ou null s'il n'y en a pas (ou s'il est illisible).
  Future<String?> read();

  /// Écrit le cache ; renvoie false si l'écriture a échoué (disque plein…).
  Future<bool> write(String source);
}

class FileRulesCacheStore implements RulesCacheStore {
  const FileRulesCacheStore();

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}'
      '$kRulesCacheFileName',
    );
  }

  @override
  Future<String?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } on Object {
      // Dossier inaccessible : l'asset embarqué prend le relais.
      return null;
    }
  }

  @override
  Future<bool> write(String source) async {
    try {
      final file = await _file();
      await file.writeAsString(source, flush: true);
      return true;
    } on Object {
      return false;
    }
  }
}

/// Accès aux règles : asset embarqué d'abord (donc jamais d'écran vide hors
/// ligne), puis mise à jour opportuniste depuis le site.
///
/// Priorité de lecture : fichier du dossier documents > asset.
class RulesRepository {
  RulesRepository({
    RulesAssetLoader assets = const BundleRulesAssetLoader(),
    RulesCacheStore cache = const FileRulesCacheStore(),
    Dio? dio,
    RulesParser parse = parseRulesInIsolate,
    String assetKey = kRulesAssetKey,
    String remoteUrl = kRulesRemoteUrl,
  }) : _assets = assets,
       _cache = cache,
       _parse = parse,
       _assetKey = assetKey,
       _remoteUrl = remoteUrl,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 30),
               responseType: ResponseType.plain,
             ),
           );

  final RulesAssetLoader _assets;
  final RulesCacheStore _cache;
  final RulesParser _parse;
  final String _assetKey;
  final String _remoteUrl;
  final Dio _dio;

  /// Charge la version locale la plus récente. Ne touche pas au réseau.
  Future<RulesDocument> load() async {
    final cached = await _cache.read();
    if (cached != null && cached.isNotEmpty) {
      final parsed = await _tryParse(cached);
      if (parsed != null && parsed.books.isNotEmpty) return parsed;
    }
    return _parse(await _assets.load(_assetKey));
  }

  /// Télécharge la version en ligne et la conserve si elle diffère de
  /// `current` (`updated` ou `ruleCount` différent). Renvoie null quand rien
  /// n'a changé ; lève une exception si le réseau échoue.
  Future<RulesDocument?> fetchUpdate(RulesDocument current) async {
    final response = await _dio.get<String>(
      _remoteUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final source = response.data;
    if (source == null || source.isEmpty) return null;
    final fresh = await _tryParse(source);
    if (fresh == null || fresh.books.isEmpty) return null;
    if (fresh.signature == current.signature) return null;
    await _cache.write(source);
    return fresh;
  }

  Future<RulesDocument?> _tryParse(String source) async {
    try {
      return await _parse(source);
    } on Object {
      // JSON tronqué ou format inattendu : on se rabat sur l'autre source.
      return null;
    }
  }
}
