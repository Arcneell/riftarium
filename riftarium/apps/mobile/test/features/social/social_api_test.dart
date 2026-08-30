import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/social/data/social_api.dart';

import '../play/support/play_fixtures.dart';
import 'support/social_fixtures.dart';

void main() {
  SocialApi apiWith(PlayFakeApi server) => SocialApi(
    createApiClient(
      readToken: () async => 'jwt',
      baseUrl: 'https://api.test/api',
      adapter: server,
    ),
  );

  test('les hauts faits arrivent avec leur progression', () async {
    final server = PlayFakeApi({'GET /me/achievements': achievementsJson()});

    final items = await apiWith(server).achievements();

    expect(server.paths, ['GET /me/achievements']);
    expect(items, hasLength(3));
    expect(items.first.key, 'first_blood');
    expect(items.first.isUnlocked, isTrue);
    expect(items.first.progress, 1);
    final veteran = items[1];
    expect(veteran.isUnlocked, isFalse);
    expect(veteran.progressLabel, '4 / 10');
    expect(veteran.progress, closeTo(0.4, 0.001));
  });

  test('le profil public lit les sections ouvertes', () async {
    final server = PlayFakeApi({'GET /users/jinx': publicProfileJson()});

    final profile = await apiWith(server).profile('jinx');

    expect(server.paths, ['GET /users/jinx']);
    expect(profile.handle, 'jinx');
    expect(profile.followersCount, 4);
    expect(profile.visibility.showStats, isTrue);
    expect(profile.stats?.totals.played, 10);
    expect(profile.achievements, hasLength(1));
    expect(profile.collection?.uniqueCards, 120);
    expect(profile.decks?.single.name, 'Ahri contrôle');
  });

  test('les sections masquées arrivent nulles', () async {
    final server = PlayFakeApi({
      'GET /users/jinx': publicProfileJson(visible: false),
    });

    final profile = await apiWith(server).profile('jinx');

    expect(profile.visibility.showStats, isFalse);
    expect(profile.visibility.showDecks, isFalse);
    expect(profile.stats, isNull);
    expect(profile.achievements, isNull);
    expect(profile.collection, isNull);
    expect(profile.decks, isNull);
  });

  test('collection et historique passent par les chemins du joueur', () async {
    final server = PlayFakeApi({
      'GET /users/jinx/collection': profileCollectionJson(),
      'GET /users/jinx/history': historyPageJson(),
    });
    final api = apiWith(server);

    final cards = await api.collection('jinx', page: 2, size: 30);
    final history = await api.history('jinx');

    expect(cards.items.single.totalQty, 3);
    expect(server.last('GET', '/users/jinx/collection')!.query, {
      'page': 2,
      'size': 30,
    });
    expect(history.items.single.matchId, 1);
    expect(server.last('GET', '/users/jinx/history')!.query, {
      'page': 1,
      'size': 20,
    });
  });

  test('la recherche envoie le pseudo saisi', () async {
    final server = PlayFakeApi({
      'GET /users/search': [socialUserJson()],
    });

    final users = await apiWith(server).search('jin');

    expect(users.single.handle, 'jinx');
    expect(server.last('GET', '/users/search')!.query, {'q': 'jin'});
  });

  test('les amis se lisent en deux listes', () async {
    final server = PlayFakeApi({'GET /me/follows': followsJson()});

    final follows = await apiWith(server).follows();

    expect(follows.following.single.handle, 'jinx');
    expect(follows.followers.single.handle, 'vi');
  });

  test('suivre et ne plus suivre : PUT puis DELETE', () async {
    final server = PlayFakeApi({
      'PUT /users/jinx/follow': const <String, dynamic>{},
      'DELETE /users/jinx/follow': const <String, dynamic>{},
    });
    final api = apiWith(server);

    await api.follow('jinx');
    await api.unfollow('jinx');

    expect(server.paths, [
      'PUT /users/jinx/follow',
      'DELETE /users/jinx/follow',
    ]);
  });

  test('un pseudo inconnu remonte le message de l’API', () async {
    final server = PlayFakeApi({
      'GET /users/zed': const PlayFakeError(404, 'Joueur introuvable.'),
    });

    await expectLater(
      apiWith(server).profile('zed'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'Joueur introuvable.'),
      ),
    );
  });
}
