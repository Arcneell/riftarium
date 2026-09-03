/// Les cinq formats officiels (règles 481 à 489), plus le match de tournoi
/// (règles de tournoi 404 à 408, 604).
///
/// Chaque mode fixe le nombre de joueurs, le score de victoire, le nombre de
/// manches gagnantes, l'ordre des tours et les ajustements du premier tour
/// rappelés en début de partie.
enum GameMode {
  /// 481 — 1 contre 1, une manche sèche.
  duel,

  /// 482 — 1 contre 1 en deux manches gagnantes.
  match,

  /// Tournoi (RT 404) — 1 contre 1 en deux manches gagnantes, ronde
  /// chronométrée, joueur désigné qui choisit de commencer, perdant qui
  /// choisit ensuite, fin de match au temps.
  tournament,

  /// 486 — chacun pour soi à trois.
  skirmish,

  /// 487 — chacun pour soi à quatre.
  war,

  /// 489 — deux équipes de deux, points partagés.
  magmaChamber;

  /// Clé stable écrite dans la sauvegarde JSON.
  String get id => switch (this) {
    GameMode.duel => 'duel',
    GameMode.match => 'match',
    GameMode.tournament => 'tournament',
    GameMode.skirmish => 'skirmish',
    GameMode.war => 'war',
    GameMode.magmaChamber => 'magma_chamber',
  };

  static GameMode? byId(Object? id) {
    for (final mode in GameMode.values) {
      if (mode.id == id) return mode;
    }
    return null;
  }

  String get label => switch (this) {
    GameMode.duel => 'Duel',
    GameMode.match => 'Match',
    GameMode.tournament => 'Tournoi',
    GameMode.skirmish => 'Escarmouche',
    GameMode.war => 'Guerre',
    GameMode.magmaChamber => 'Chambre magmatique',
  };

  String get tagline => switch (this) {
    GameMode.duel => 'Un contre un, une manche sèche.',
    GameMode.match => 'Un contre un, deux manches gagnantes.',
    GameMode.tournament =>
      'Deux manches gagnantes, ronde chronométrée, fin de match au temps.',
    GameMode.skirmish => 'Trois joueurs, chacun pour soi.',
    GameMode.war => 'Quatre joueurs, chacun pour soi.',
    GameMode.magmaChamber => 'Deux équipes de deux, points partagés.',
  };

  int get playerCount => switch (this) {
    GameMode.duel || GameMode.match || GameMode.tournament => 2,
    GameMode.skirmish => 3,
    GameMode.war || GameMode.magmaChamber => 4,
  };

  /// Score à atteindre lors d'un nettoyage pour l'emporter (472).
  int get victoryScore => this == GameMode.magmaChamber ? 11 : 8;

  /// Manches à gagner pour remporter la rencontre.
  int get roundsToWin =>
      this == GameMode.match || this == GameMode.tournament ? 2 : 1;

  bool get isTeamPlay => this == GameMode.magmaChamber;

  /// Règles de tournoi appliquées : ronde chronométrée, tours
  /// supplémentaires, joueur désigné, perdant qui choisit.
  bool get isTournament => this == GameMode.tournament;

  /// Nombre de camps : deux équipes, ou un camp par joueur.
  int get campCount => isTeamPlay ? 2 : playerCount;

  /// Camp d'un siège. Hors 2c2, chaque joueur est son propre camp : les scores
  /// et les manches gagnées se rangent partout de la même façon.
  int defaultTeam(int seat) => isTeamPlay ? seat ~/ 2 : seat;

  /// Rappel discret affiché au premier tour.
  List<String> get firstTurnNotes => switch (this) {
    GameMode.duel || GameMode.match => const [
      'Le second joueur canalise une rune de plus à sa première canalisation.',
    ],
    GameMode.tournament => const [
      'Le second joueur canalise une rune de plus à sa première canalisation.',
      'Pas de réserve en première partie. Chaque changement de score '
          's’annonce et s’approuve à deux.',
    ],
    GameMode.skirmish || GameMode.war => const [
      'Le premier joueur ne pioche pas à sa première pioche.',
      'Le dernier joueur canalise une rune de plus à sa première canalisation.',
    ],
    GameMode.magmaChamber => const [
      'Les tours alternent entre les deux équipes.',
      'Les coéquipiers marquent, gagnent et perdent ensemble.',
    ],
  };
}

/// Durée recommandée d'une ronde suisse en tournoi (RT 604.1).
const Duration kTournamentRoundLimit = Duration(minutes: 60);

/// Tours joués après l'annonce de la fin du temps, une fois le tour en cours
/// terminé (RT 408.2.a).
const int kTournamentExtraTurns = 3;

/// Avance nécessaire pour l'emporter au temps (RT 408.2.b).
const int kTournamentTimeLead = 2;

/// Nom d'un camp : « A » ou « B » en 2c2, sinon le siège.
String teamLetter(int team) => String.fromCharCode(65 + team);
