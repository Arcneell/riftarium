import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/design/banners.dart';

void main() {
  group('cardThumb', () {
    test('remplace la largeur déjà demandée au CDN', () {
      expect(
        cardThumb('https://cdn.test/x.png?auto=format&w=1080', width: 360),
        'https://cdn.test/x.png?auto=format&w=360',
      );
    });

    test('ne touche qu’au premier paramètre w', () {
      expect(
        cardThumb('https://cdn.test/x.png?w=10&w=20', width: 360),
        'https://cdn.test/x.png?w=360&w=20',
      );
    });

    test('ajoute le cadrage et le format webp quand w est absent', () {
      expect(
        cardThumb('https://cdn.test/x.png', width: 280),
        'https://cdn.test/x.png?fit=max&fm=webp&w=280',
      );
    });

    test('respecte une requête déjà présente', () {
      expect(
        cardThumb('https://cdn.test/x.png?auto=format', width: 280),
        'https://cdn.test/x.png?auto=format&fit=max&fm=webp&w=280',
      );
    });

    test('largeur par défaut : 280 px', () {
      expect(cardThumb('https://cdn.test/x.png'), endsWith('w=280'));
    });

    test('une URL vide reste vide', () {
      expect(cardThumb(''), '');
    });

    test('une largeur partielle (wxxx) n’est pas confondue avec w=', () {
      expect(
        cardThumb('https://cdn.test/x.png?width=99', width: 360),
        'https://cdn.test/x.png?width=99&fit=max&fm=webp&w=360',
      );
    });
  });

  group('RiftBanners', () {
    test('url : format automatique et largeur téléphone', () {
      expect(
        RiftBanners.url('abc-1x1.png'),
        'https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/'
        'abc-1x1.png?auto=format&w=1080',
      );
    });
  });
}
