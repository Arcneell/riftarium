# Suivi des matchs — contrat d'API `/api/play` (v1)

Source de vérité pour l'API (FastAPI), l'application mobile (Flutter) et le site
(Vue). Toute évolution passe d'abord par ce fichier.

## Principes

- Le compteur reste un **pense-bête** : les joueurs saisissent eux-mêmes points,
  XP et tours. Aucune règle n'est résolue par le serveur (politique Riot : pas de
  simulation du jeu).
- Un match suivi exige **deux comptes** (hôte + invité). La « partie libre »
  (compteur hors ligne, sans compte) continue d'exister telle quelle.
- Le **résultat compte dans les statistiques uniquement s'il est confirmé par
  les deux joueurs**. Contesté = exclu des stats. Abandon = défaite de celui qui
  abandonne, sans confirmation.
- v1 = formats à deux joueurs : `duel` (8 points, 1 manche) et `match` (8 points,
  2 manches gagnantes). Les modes à 3–4 joueurs viendront après.
- Temps réel par **polling** (2 s côté mobile, 5 s côté web) sur un `version`
  entier ; le serveur ne pousse rien en v1.

## Modèles (SQLAlchemy, migration Alembic `0009_play`)

```
rooms          id, code (6 car., unique, alphabet sans 0/O/1/I), host_id → users,
               mode ('duel'|'match'), status ('open'|'playing'|'finished'|'cancelled'),
               match_id → matches (nullable), created_at, expires_at (created + 2 h),
               version (int, +1 à chaque modification)
room_players   id, room_id, user_id, seat (0 hôte, 1 invité), legend_card_id → cards
               (nullable, type Legend), deck_id → decks (nullable, owner = user),
               ready (bool), unique (room_id, user_id), unique (room_id, seat)
matches        id, room_id (nullable), mode, status ('live'|'awaiting_confirmation'|
               'confirmed'|'disputed'|'abandoned'), host_id, first_player_id,
               started_at, ended_at, winner_user_id (nullable),
               state (JSON : instantané du compteur), version (int),
               result (JSON, nullable : scores finaux, manches)
match_players  id, match_id, user_id, seat, legend_card_id (nullable),
               deck_id (nullable), score (int), rounds_won (int), confirmed_at (nullable)
```

Un utilisateur ne peut avoir qu'**un seul salon `open`/`playing`** à la fois.
Les salons `open` dont `expires_at` est dépassé sont lus comme `cancelled`.

Pas de clé étrangère sur `rooms.match_id`, `*.host_id`, `first_player_id`,
`winner_user_id` ni `*.deck_id` : matchs et salons doivent survivre à la
suppression d'un compte ou d'un deck (le deck devient `null`, l'adversaire
`null`). `by_deck` ignore les decks supprimés. Code de salon normalisé en
majuscules à la lecture. `current_streak` = victoires consécutives se terminant
au dernier match compté ; `best_streak` = plus longue série.

## Instantané du compteur (`matches.state`)

```json
{
  "round": 1,
  "turn": 3,
  "active_user_id": 12,
  "scores": {"12": 3, "27": 1},
  "xp": {"12": 2, "27": 0},
  "rounds_won": {"12": 0, "27": 0}
}
```
Clés = `user_id` en chaîne. Le serveur valide la forme (entiers ≥ 0, joueurs du
match) et rejette une version stale (409). Le résultat final (`result`) reprend
`scores` et `rounds_won`.

## Endpoints (tous authentifiés, Bearer ou cookie)

| Méthode | Chemin | Rôle | Effet |
| --- | --- | --- | --- |
| POST | `/api/play/rooms` `{mode}` | tout compte | **201**, crée un salon, renvoie `RoomOut` (avec `code`). 409 si un salon actif existe déjà. |
| GET | `/api/play/rooms/{code}` | tout compte | `RoomOut` (le code vaut secret). 404 si inconnu. |
| POST | `/api/play/rooms/{code}/join` | tout compte ≠ hôte | rejoint le siège 1. 409 si plein / pas `open` / expiré / déjà un salon actif / hôte ; déjà assis → 200 sans effet. |
| PUT | `/api/play/rooms/{code}/me` `{legend_card_id?, deck_id?, ready}` | participant | choix perso. 422 si la carte n'est pas une Legend (variantes alt-art/signature acceptées) ou si le deck n'appartient pas au joueur ; 409 si le salon n'est plus `open`. |
| POST | `/api/play/rooms/{code}/leave` | invité | **200** + `RoomOut` ; salon redevient `open` avec l'hôte seul ; 409 si le salon n'est plus `open`. |
| DELETE | `/api/play/rooms/{code}` | hôte | **200** + `RoomOut` (`cancelled`). |
| POST | `/api/play/rooms/{code}/start` `{first_player_id}` | hôte | **201**. 409 si les deux ne sont pas `ready`. Crée le match (`live`), copie légendes/decks, salon → `playing`. Renvoie `MatchOut`. |
| GET | `/api/play/matches/{id}` | participant | `MatchOut` (joueurs, `state`, `version`, statut). |
| PUT | `/api/play/matches/{id}/state` `{version, state}` | hôte, match `live` | remplace l'instantané ; 409 si `version` ≠ version courante ; renvoie `MatchOut` (version + 1). |
| POST | `/api/play/matches/{id}/finish` `{winner_user_id, result}` | hôte, match `live` | `result` a exactement la forme de `state` (tous les champs obligatoires) et est stocké à part de `state`. → `awaiting_confirmation`, l'hôte est confirmé d'office, `ended_at` posé, salon → `finished`. |
| POST | `/api/play/matches/{id}/confirm` | participant | confirme ; les deux confirmés → `confirmed`. |
| POST | `/api/play/matches/{id}/dispute` | participant, match `awaiting_confirmation` | → `disputed` (exclu des stats) ; 409 sinon. |
| POST | `/api/play/matches/{id}/abandon` | participant, match `live` ou `awaiting_confirmation` | → `abandoned`, `winner_user_id` = l'autre joueur, `result` = copie du `state` courant, compté sans confirmation. |
| GET | `/api/play/history?page&size` | tout compte | `{total, page, size, items: [HistoryItem]}`, `size` ≤ 50 ; mes matchs terminés (`confirmed`, `disputed`, `abandoned`), plus récents d'abord. |
| GET | `/api/play/stats` | tout compte | `StatsOut` (voir ci-dessous). |
| GET | `/api/play/current` | tout compte | mon salon actif et/ou mon match `live` / `awaiting_confirmation`, sinon `{room: null, match: null}` (reprise après fermeture de l'app). |

Limites : création de salon et `join` passent par le limiteur existant
(`limit_auth`-like, 20 / min / IP). `PUT state` non limité (2 s de polling).

## Schémas de sortie

```
RoomPlayerOut  user {id, handle, avatar_url}, seat, legend (card_out ou null),
               deck {id, name, format} ou null, ready
RoomOut        code, mode, status, host_id, players [RoomPlayerOut], match_id,
               expires_at, version, victory_score (8), rounds_to_win (1 ou 2)
MatchPlayerOut user {id, handle, avatar_url}, seat, legend, deck, score,
               rounds_won, confirmed (bool)
MatchOut       id, room_code, mode, status, host_id, first_player_id,
               started_at, ended_at, winner_user_id, players [MatchPlayerOut],
               state, result, version
HistoryItem    match_id, mode, status, played_at, opponent {id, handle, avatar_url} | null,
               my_legend / opponent_legend (card_out | null),
               my_deck / opponent_deck ({id, name, format} | null, deck supprimé = null),
               my_score, opponent_score, my_rounds, opponent_rounds,
               outcome ('win'|'loss'|'disputed')
StatsOut       totals {played, won, lost, win_rate, current_streak, best_streak},
               by_format [{mode, played, won, lost}],
               by_deck [{deck_id, name, format, played, won, lost, win_rate}],
               by_legend [{card_id, name, image_url, played, won, lost}],
               by_opponent_legend [{card_id, name, image_url, played, won, lost}],
               recent [{day, played, won}] (30 derniers jours)
```

Les stats ne comptent que `confirmed` et `abandoned`. Suppression de compte :
les lignes `room_players`/`match_players` du compte sont supprimées, les matchs
restent anonymisés côté adversaire (`opponent: null`).

## Parcours

1. Hôte (mobile ou web) : « Partie suivie » → format → salon créé, code affiché
   + lien `https://riftarium.re/salon/CODE` partageable.
2. Invité : saisit le code (ou ouvre le lien) → rejoint → choisit légende + deck →
   « Prêt ». L'hôte fait de même.
3. Hôte : tirage au sort local → `start` avec `first_player_id`. Les deux
   téléphones affichent le compteur ; seul l'hôte modifie (`PUT state`), l'invité
   voit en lecture (polling). Chacun peut abandonner.
4. Victoire (score atteint et strictement supérieur, manches en mode `match`) →
   l'hôte envoie `finish` → l'invité confirme ou conteste.
5. Historique et statistiques : profil mobile et pages web `/historique`,
   `/statistiques`. Un deck du site affiche ses W/L.
