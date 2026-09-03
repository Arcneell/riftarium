import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/scan/data/scan_collection_api.dart';
import 'package:riftarium_mobile/features/scan/data/scan_index.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;

  Dio client() => createApiClient(
    readToken: () async => 'jwt',
    baseUrl: 'https://api.test/api',
    adapter: adapter,
  );

  const hashesJson = {
    'algo': 'dhash16',
    'count': 3,
    'items': [
      {'id': 'OGN-209', 'rid': 'ogn-209-298', 'h': null},
      {'id': 'OGN-209s', 'rid': 'ogn-209*-298', 'h': 'ff00'},
      {'id': 'UNL-229', 'rid': 'unl-229-219', 'h': null},
      // Ligne abîmée : ignorée sans faire échouer le chargement.
      {'id': 'CASSE', 'h': null},
    ],
  };

  group('ScanIndexApi', () {
    test('charge l’index et en déduit les totaux d’impression', () async {
      adapter = FakeHttpAdapter({
        'GET /cards/hashes': const FakeResponse(200, hashesJson),
      });

      final index = await ScanIndexApi(client()).fetch();

      expect(index.entries.length, 3);
      expect(index.totals, {298, 219});
      expect(index.isUsable, isTrue);
      expect(adapter.requests.single.options.queryParameters, {'v': 2});
    });

    test('résout un code lu en carte de l’index', () async {
      adapter = FakeHttpAdapter({
        'GET /cards/hashes': const FakeResponse(200, hashesJson),
      });
      final index = await ScanIndexApi(client()).fetch();

      final code = index.read(const ['Riot Games', 'OGN 209/298'])!;
      expect(code.number, 209);
      expect(code.total, 298);
      expect(index.resolve(code)?.id, 'OGN-209');
    });

    test('code étoilé : la variante étoilée l’emporte', () async {
      adapter = FakeHttpAdapter({
        'GET /cards/hashes': const FakeResponse(200, hashesJson),
      });
      final index = await ScanIndexApi(client()).fetch();

      final code = index.read(const ['OGN 209*/298'])!;
      expect(index.resolve(code)?.id, 'OGN-209s');
    });

    test('total absent de l’index : aucune lecture', () async {
      adapter = FakeHttpAdapter({
        'GET /cards/hashes': const FakeResponse(200, hashesJson),
      });
      final index = await ScanIndexApi(client()).fetch();

      expect(index.read(const ['XYZ 12/144']), isNull);
    });

    test('index vide : le scanner ne peut rien reconnaître', () async {
      adapter = FakeHttpAdapter({
        'GET /cards/hashes': const FakeResponse(200, {
          'algo': 'dhash16',
          'count': 0,
          'items': [],
        }),
      });

      final index = await ScanIndexApi(client()).fetch();
      expect(index.isUsable, isFalse);
      expect(index.read(const ['OGN 209/298']), isNull);
    });

    test('erreur serveur : ApiException avec le message de l’API', () async {
      adapter = FakeHttpAdapter({
        'GET /cards/hashes': const FakeResponse(500, {
          'detail': 'Index en panne',
        }),
      });

      expect(
        () => ScanIndexApi(client()).fetch(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Index en panne',
          ),
        ),
      );
    });
  });

  group('ScanCollectionApi', () {
    test(
      '« +1 » : POST /collection/{id}/entries et quantité renvoyée',
      () async {
        adapter = FakeHttpAdapter({
          'POST /collection/OGN-209/entries': const FakeResponse(200, {
            'card_id': 'OGN-209',
            'total_qty': 3,
            'entries': [
              {'id': 11, 'qty': 3, 'condition': 'NM', 'lang': 'EN'},
            ],
          }),
        });

        final total = await ScanCollectionApi(client()).add('OGN-209');

        expect(total, 3);
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/collection/OGN-209/entries');
        expect(request.jsonBody, {'qty': 1, 'condition': 'NM', 'lang': 'EN'});
      },
    );

    test('carte inconnue : ApiException', () async {
      adapter = FakeHttpAdapter({
        'POST /collection/NOPE/entries': const FakeResponse(404, {
          'detail': 'Carte introuvable',
        }),
      });

      expect(
        () => ScanCollectionApi(client()).add('NOPE'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Carte introuvable',
          ),
        ),
      );
    });
  });
}
