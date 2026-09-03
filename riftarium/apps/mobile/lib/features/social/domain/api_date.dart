/// Lecture d'une date ISO renvoyée par l'API.
///
/// L'interpolation d'un champ absent (`'${json['x']}'`) donne la chaîne
/// `"null"`, que `DateTime.tryParse` refuse par chance : on ne compte pas sur
/// ce hasard. Toute valeur qui n'est pas une chaîne datée vaut « pas de date ».
DateTime? parseApiDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
