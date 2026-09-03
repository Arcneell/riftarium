import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riftarium_mobile/core/token_store.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('InMemoryTokenStore', () {
    test('écrit, relit, puis oublie le jeton', () async {
      final store = InMemoryTokenStore();
      expect(await store.read(), isNull);

      await store.write('jwt');
      expect(await store.read(), 'jwt');

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('accepte un jeton de départ (prévisualisations)', () async {
      expect(await InMemoryTokenStore('jwt').read(), 'jwt');
    });
  });

  group('SecureTokenStore', () {
    late _MockSecureStorage storage;
    late SecureTokenStore store;

    setUp(() {
      storage = _MockSecureStorage();
      store = SecureTokenStore(storage);
    });

    test('lit la clé du jeton', () async {
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => 'jwt');

      expect(await store.read(), 'jwt');
      verify(() => storage.read(key: 'riftarium_session_token')).called(1);
    });

    test('un jeton absent ou vide vaut « pas de session »', () async {
      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      expect(await store.read(), isNull);

      when(
        () => storage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => '');
      expect(await store.read(), isNull);
    });

    test('écrit et supprime la même clé', () async {
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      await store.write('jwt');
      await store.clear();

      verify(
        () => storage.write(key: 'riftarium_session_token', value: 'jwt'),
      ).called(1);
      verify(() => storage.delete(key: 'riftarium_session_token')).called(1);
    });

    test(
      'options de plateforme : rien de restaurable sur un autre appareil',
      () {
        expect(SecureTokenStore.androidOptions.params['resetOnError'], 'true');
        expect(
          SecureTokenStore.iosOptions.accessibility,
          KeychainAccessibility.first_unlock_this_device,
        );
      },
    );
  });
}
