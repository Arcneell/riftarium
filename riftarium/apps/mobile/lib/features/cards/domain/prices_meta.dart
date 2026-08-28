/// Météo des prix (`GET /api/prices/meta`).
///
/// Réponse de l'API : `{updated_day, rate, rate_date, priced_cards, source,
/// currency_note}`. `updated_day` et `rate_date` sont des jours `AAAA-MM-JJ`.
class PricesMeta {
  const PricesMeta({
    this.updatedDay,
    this.rate,
    this.rateDate,
    this.pricedCards = 0,
    this.source,
    this.currencyNote,
  });

  factory PricesMeta.fromJson(Map<String, dynamic> json) => PricesMeta(
    updatedDay: json['updated_day']?.toString(),
    rate: (json['rate'] as num?)?.toDouble(),
    rateDate: json['rate_date']?.toString(),
    pricedCards: (json['priced_cards'] as num?)?.toInt() ?? 0,
    source: json['source'] as String?,
    currencyNote: json['currency_note'] as String?,
  );

  final String? updatedDay;
  final double? rate;
  final String? rateDate;
  final int pricedCards;
  final String? source;
  final String? currencyNote;

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
