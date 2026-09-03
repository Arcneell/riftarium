/// Météo des prix (`GET /api/prices/meta`).
///
/// L'API renvoie aussi `rate`, `rate_date`, `priced_cards`, `source` et
/// `currency_note` : la note affichée sous le prix ne s'en sert pas (la source
/// et le taux y sont écrits en clair), seul `updated_day` est lu — un jour
/// `AAAA-MM-JJ`.
class PricesMeta {
  const PricesMeta({this.updatedDay});

  factory PricesMeta.fromJson(Map<String, dynamic> json) =>
      PricesMeta(updatedDay: json['updated_day']?.toString());

  final String? updatedDay;

  /// Note affichée sous le prix, en une ligne : source, conversion, fraîcheur.
  /// Le libellé « Prix indicatif » de la fiche dit déjà le reste.
  String get note {
    final buffer = StringBuffer('Marché US (TCGplayer) · taux BCE');
    if (updatedDay != null && updatedDay!.isNotEmpty) {
      buffer.write(' · ${_frenchDay(updatedDay!)}');
    }
    return buffer.toString();
  }

  /// `2026-08-20` → `20/08/2026` (la valeur est rendue telle quelle si elle
  /// n'a pas la forme attendue).
  static String _frenchDay(String day) {
    final parts = day.split('-');
    if (parts.length != 3) return day;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}
