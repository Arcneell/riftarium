import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage du jeton de session. Abstrait pour être remplacé en test.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keychain (iOS) / Keystore (Android) via flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? _defaultStorage;

  static const _key = 'riftarium_session_token';

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: iosOptions,
  );

  /// Android : AES-GCM adossé au Keystore, et remise à zéro du conteneur si
  /// le déchiffrement échoue (Keystore réinitialisé) — mieux vaut redemander
  /// la connexion qu'une erreur fatale au démarrage.
  static const androidOptions = AndroidOptions(
    storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    resetOnError: true,
  );

  /// iOS : jeton lisible seulement après le premier déverrouillage, jamais
  /// recopié vers un autre appareil (donc ni iCloud ni restauration).
  static const iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    final value = await _storage.read(key: _key);
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// Jeton en mémoire uniquement : tests et prévisualisations.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
