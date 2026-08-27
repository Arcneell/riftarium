import 'card.dart';

/// Libellés français des valeurs renvoyées par l'API, alignés sur le site
/// (`apps/web/src/api.js` et `cardText.js`).

const Map<String, String> kDomainLabels = {
  'Fury': 'Fureur',
  'Calm': 'Calme',
  'Mind': 'Esprit',
  'Body': 'Corps',
  'Chaos': 'Chaos',
  'Order': 'Ordre',
  'Colorless': 'Neutre',
};

const Map<String, String> kTypeLabels = {
  'Unit': 'Unité',
  'Spell': 'Sort',
  'Gear': 'Équipement',
  'Rune': 'Rune',
  'Legend': 'Légende',
  'Battlefield': 'Champ de bataille',
};

/// Ordre officiel Riot : commun → épique, puis impressions spéciales.
const Map<String, String> kRarityLabels = {
  'Common': 'Commun',
  'Uncommon': 'Peu commun',
  'Rare': 'Rare',
  'Epic': 'Épique',
  'Showcase': 'Showcase',
  'Promo': 'Promo',
};

/// Coûts proposés au filtre ; « 7+ » regroupe le haut de courbe (l'API
/// interprète le suffixe `+` comme « supérieur ou égal »).
const List<String> kEnergyCosts = ['0', '1', '2', '3', '4', '5', '6', '7+'];

/// Domaines filtrables : « Colorless » n'est pas proposé (comme sur le site).
List<String> get kFilterableDomains =>
    kDomainLabels.keys.where((domain) => domain != 'Colorless').toList();

String domainLabel(String value) => kDomainLabels[value] ?? value;

String typeLabel(String value) => kTypeLabels[value] ?? value;

String rarityLabel(String value) => kRarityLabels[value] ?? value;

/// « Showcase » n'est pas une cinquième rareté fonctionnelle : c'est la famille
/// des impressions spéciales, que l'API reconstruit à partir des drapeaux
/// (alternate_art, overnumbered, signature) quand les données source ne la
/// codent pas.
const String kShowcaseHint =
    'Showcase regroupe les impressions spéciales : alt-arts, overnumbered '
    '(n° au-delà du set) et signatures d’artiste.';

String energyLabel(String value) => value == '7+' ? '7 et plus' : value;

/// « Fureur / Ordre », ou `null` si la carte n'a aucun domaine.
String? domainsLabel(List<String> domains) =>
    domains.isEmpty ? null : domains.map(domainLabel).join(' / ');

/// Nature de l'impression, pour distinguer les variantes entre elles.
String variantLabel(RiftCard card) {
  if (card.signature) return 'Signature';
  if (card.overnumbered) return 'Overnumbered';
  if (card.alternateArt) return 'Alt';
  return 'Normale';
}

/// Tri de la cartothèque : valeur du paramètre `sort` de `GET /api/cards`.
const Map<String?, String> kSortLabels = {
  null: 'Set et numéro',
  'rarity': 'Rareté',
  'random': 'Aléatoire',
};

String sortLabel(String? value) => kSortLabels[value] ?? 'Set et numéro';

/// Filtre « possédées / manquantes » (paramètre `owned`, compte connecté).
const Map<String?, String> kOwnedLabels = {
  null: 'Toutes',
  '1': 'Possédées',
  '0': 'Manquantes',
};

String ownedLabel(String? value) => kOwnedLabels[value] ?? 'Toutes';

/// « 12,34 € ». L'application n'embarque pas `intl` : le format français est
/// écrit à la main — deux décimales, virgule décimale et espace insécable
/// (\u00A0) avant le symbole, écrit en clair pour ne pas dépendre de l'encodage
/// du fichier.
String formatEuro(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')}\u00A0€';

/// « 3 cartes », « 1 carte », « Aucune carte ».
String cardCountLabel(int total) {
  if (total <= 0) return 'Aucune carte';
  return total == 1 ? '1 carte' : '$total cartes';
}
