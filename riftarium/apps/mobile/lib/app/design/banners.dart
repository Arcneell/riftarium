/// Illustrations officielles Riftbound (CDN Riot), mêmes visuels que
/// `apps/web/src/banners.js`. Jamais hébergées en local.
abstract final class RiftBanners {
  static const _news =
      'https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live';

  /// Largeur adaptée au téléphone : 1080 px suffisent (DPR ≤ 3, écran ≤ 430 pt).
  static String url(String hash, {int width = 1080}) =>
      '$_news/$hash?auto=format&w=$width';

  /// Cinématique de lancement : accueil, connexion.
  static final home = url(
    '9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png',
  );

  /// Champion (Riven) : cartothèque.
  static final cards = url(
    '4e9fa6cb967a660994b07ac4a42edafa134324f9-4500x2531.jpg',
  );

  /// Équipage (Gangplank) : decks.
  static final decks = url(
    'c84b72546ca00618ae705f2a7b9239a75111408c-5219x2936.jpg',
  );

  /// Inventaire : collection.
  static final collection = url(
    '2282ecab240f601b611ae89b5ade895e1b6b2de4-4676x2630.jpg',
  );

  /// Table de jeu : communauté.
  static final community = url(
    '91a720561b6cd9c649a9148782f34d96e78cd894-4320x2430.jpg',
  );

  /// Maître Poro : règles.
  static final rules = url(
    'bf44d943577f839588eddde2483fc582c068841c-4800x2700.jpg',
  );
}

/// Redimensionne une URL d'illustration du CDN Riot (`w=`) : les visuels de
/// cartes font 744×1039 px, inutile de les charger en plein format pour une
/// vignette. Reprise de `cardThumb()` du site.
String cardThumb(String? url, {int width = 280}) {
  if (url == null || url.isEmpty) return url ?? '';
  final existing = RegExp(r'([?&])w=\d+');
  if (existing.hasMatch(url)) {
    return url.replaceFirstMapped(existing, (m) => '${m[1]}w=$width');
  }
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}auto=format&fit=max&w=$width';
}
