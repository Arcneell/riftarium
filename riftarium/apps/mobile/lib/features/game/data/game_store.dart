import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/game_state.dart';

/// Nom du fichier de reprise, dans le dossier documents.
const String kGameSaveFileName = 'game-in-progress.json';

/// Dossier de travail, injectable : les tests écrivent dans un dossier
/// temporaire au lieu d'appeler le plugin `path_provider`.
typedef GameDirectoryResolver = Future<Directory> Function();

/// Sauvegarde de la partie en cours : une seule à la fois.
abstract class GameStore {
  /// Partie sauvegardée, ou null s'il n'y en a pas (ou si elle est illisible).
  Future<GameState?> read();

  /// Écrit la partie ; renvoie false si l'écriture a échoué (disque plein…).
  Future<bool> write(GameState state);

  /// Efface la sauvegarde (partie terminée ou abandonnée).
  Future<void> clear();
}

/// Sauvegarde sur disque, dans le dossier documents de l'application.
class FileGameStore implements GameStore {
  const FileGameStore({GameDirectoryResolver? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final GameDirectoryResolver _directory;

  Future<File> _file() async {
    final directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$kGameSaveFileName');
  }

  @override
  Future<GameState?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return GameState.fromJson(jsonDecode(await file.readAsString()));
    } on Object {
      // Fichier tronqué ou dossier inaccessible : on repart d'une table vide.
      return null;
    }
  }

  @override
  Future<bool> write(GameState state) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(state.toJson()), flush: true);
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on Object {
      // Rien à faire : la sauvegarde sera écrasée à la prochaine partie.
    }
  }
}

/// Sauvegarde en mémoire : utilisée par les tests et par tout contexte sans
/// accès disque. Le JSON est bien produit et relu, comme sur disque.
class InMemoryGameStore implements GameStore {
  InMemoryGameStore([Map<String, dynamic>? initial]) : _saved = initial;

  Map<String, dynamic>? _saved;

  /// Nombre d'écritures : pratique pour vérifier qu'une action sauvegarde.
  int writes = 0;

  @override
  Future<GameState?> read() async => GameState.fromJson(_saved);

  @override
  Future<bool> write(GameState state) async {
    _saved = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
    writes++;
    return true;
  }

  @override
  Future<void> clear() async => _saved = null;
}
