# Profils publics, hauts faits et amis — contrat d'API (v1)

Source de vérité pour l'API (FastAPI), l'application mobile (Flutter) et le site
(Vue). Complète `suivi-des-matchs.md`. Toute évolution passe d'abord par ce fichier.

## Principes

- Un **réseau social sans publication** : on ne poste rien, on **montre** son
  profil (pseudo, avatar, bio, ancienneté), ses **hauts faits**, ses **stats de
  duels** (matchs suivis uniquement) et, si on l'autorise, sa **collection** et
  ses **decks publics**.
- Réglages de confidentialité par compte, tous **désactivés par défaut** sauf
  le profil de base : `show_stats`, `show_collection`, `show_decks`
  (decks publics du site déjà visibles par nature : ce réglage ne concerne que
  la liste sur le profil), `show_achievements`.
- Les hauts faits liés aux parties ne comptent que les **matchs suivis
  confirmés** (`matches.status = confirmed`) et les abandons de l'adversaire
  (`abandoned` gagné). Jamais la partie libre.
- **Amis** = suivis (« Suivre » unilatéral, comme un carnet). Sert à retrouver
  vite un adversaire et à l'inviter dans un salon. Pas de messagerie.

## Modèles (migration Alembic `0010_profiles`)

```
users            + bio (existe), + show_stats bool default false,
                 + show_collection bool default false, + show_decks bool default true,
                 + show_achievements bool default true
achievements     id, user_id → users (cascade), key (str 64), unlocked_at,
                 progress (int, valeur atteinte au déblocage), unique (user_id, key)
follows          id, follower_id → users (cascade), followed_id → users (cascade),
                 created_at, unique (follower_id, followed_id), check follower ≠ followed
```

## Catalogue des hauts faits (code, `app/achievements.py`)

Chaque haut fait a `key`, `title`, `description`, `icon` (nom d'icône Material
partagé mobile/web), `tier` (`bronze`|`silver`|`gold`|`prism`), `threshold`,
`family` et une **métrique** calculée côté API. Progression = `current /
threshold`. Déblocage évalué à la lecture du profil et après chaque événement
(match confirmé, mise à jour de collection, deck créé) ; la date de déblocage
est enregistrée une fois pour toutes (`achievements`).

| family | key | seuil | métrique |
| --- | --- | --- | --- |
| duels | `first_blood` | 1 | victoires en matchs suivis |
| duels | `veteran_10` / `veteran_50` / `veteran_200` | 10 / 50 / 200 | matchs suivis joués |
| duels | `winner_10` / `winner_50` / `winner_100` | 10 / 50 / 100 | victoires |
| duels | `streak_3` / `streak_5` / `streak_10` | 3 / 5 / 10 | meilleure série de victoires |
| duels | `six_domains` | 6 | domaines distincts de légendes jouées en victoire |
| duels | `giant_slayer` | 1 | victoire contre un joueur ayant ≥ 20 victoires de plus |
| duels | `marathon` | 1 | match en format `match` remporté 2–1 |
| collection | `collector_100` / `collector_500` / `collector_1000` | 100 / 500 / 1000 | cartes distinctes possédées |
| collection | `set_complete` | 1 | un set complété à 100 % (hors showcase) |
| collection | `showcase_10` | 10 | impressions showcase (alt-art/overnumbered/signature) possédées |
| decks | `architect_1` / `architect_5` / `architect_20` | 1 / 5 / 20 | decks créés |
| decks | `crowd_favorite` | 10 | likes reçus (somme) |
| decks | `legal_eagle` | 1 | deck public légal en tournoi |
| social | `sociable_5` | 5 | joueurs suivis |
| social | `regular` | 30 | jours distincts avec un match suivi |

`tier` : bronze pour le premier palier d'une famille, silver / gold pour les
suivants, `prism` pour `six_domains`, `set_complete`, `giant_slayer`.

## Endpoints

### Profil et réglages (compte connecté)

| Méthode | Chemin | Effet |
| --- | --- | --- |
| PATCH | `/api/auth/me` | existe (`handle`, `email`, `bio`, `avatar_card_id`, `notify_moderation`, `current_password`) ; **ajoute** `show_stats`, `show_collection`, `show_decks`, `show_achievements`. Réponse `user_out` étendue avec ces 4 booléens. |
| GET | `/api/auth/avatars` | existe : légendes proposées comme avatar. Le mobile l'utilise pour le sélecteur. |
| GET | `/api/me/achievements` | tous les hauts faits du catalogue avec `unlocked_at` (ou null), `current`, `threshold`, `tier`, `family`, `title`, `description`, `icon`. Évalue et enregistre les déblocages manquants. |

### Profils publics (lecture, connecté ou non)

| Méthode | Chemin | Effet |
| --- | --- | --- |
| GET | `/api/users/{handle}` | `PublicProfileOut` : `id, handle, avatar_url, bio, created_at, is_me, is_followed (si connecté), followers_count, following_count, visibility {show_stats, show_collection, show_decks, show_achievements}, stats (StatsOut allégé : `totals`, `by_legend` top 5 — null si masqué), achievements (débloqués seulement, ordre de déblocage — null si masqué), collection_summary {unique_cards, total_cards, sets [{set_id, name, owned, total}]} (null si masqué), decks [résumé des decks publics : id, name, format, legend card_out, likes] (null si masqué)`. 404 si pseudo inconnu ou compte suspendu. |
| GET | `/api/users/{handle}/collection?q&set_id&page&size` | même forme que `GET /api/collection` mais sans entrées détaillées (cartes + `total_qty`), 403 si `show_collection` faux et ≠ moi. |
| GET | `/api/users/{handle}/history?page&size` | historique des matchs suivis (même `HistoryItem`, du point de vue du profil consulté), 403 si `show_stats` faux et ≠ moi. |
| GET | `/api/users/search?q=` | jusqu'à 10 comptes dont le pseudo commence par `q` (≥ 2 caractères) : `{id, handle, avatar_url}`. Limité (20 / min / IP). |

### Amis (compte connecté)

| Méthode | Chemin | Effet |
| --- | --- | --- |
| GET | `/api/me/follows` | `{following: [{id, handle, avatar_url, last_match_at}], followers: [{id, handle, avatar_url}]}` |
| PUT | `/api/users/{handle}/follow` | suit (idempotent, 204). 409 si soi-même. |
| DELETE | `/api/users/{handle}/follow` | ne suit plus (204). |

### Statistiques publiques dans l'existant

- `GET /api/play/history` : `HistoryItem.opponent` porte déjà `handle` → lien
  vers le profil public.
- `GET /api/play/rooms/{code}` : `RoomPlayerOut.user` idem.
- `GET /api/community/decks` : `owner.handle` → lien vers le profil.

## Écrans

**Mobile** (onglet Profil) : mon profil (avatar, pseudo, bio, badges débloqués
en tête, stats de duels, Mes parties, réglages de confidentialité, « Modifier »
: pseudo, bio, avatar parmi `/api/auth/avatars`, réglages) ; profil public
(route interne `/joueur/:handle`, lien profond public `/u/:handle` comme sur le
site) : bannière avec l'avatar en grand, bio, badges, stats,
collection (grille si autorisée), decks publics, bouton Suivre ; « Amis »
(`/profil/amis`) : suivis + abonnés, recherche par pseudo, « Inviter dans mon
salon » (crée le salon puis partage le code). Depuis l'historique et les salons,
tap sur un adversaire → son profil.

**Web** : `/u/:handle` (profil public), section « Hauts faits » et
« Confidentialité » sur `/profil`, lien vers les profils depuis la communauté,
l'historique et les salons, page `/amis`.

## Suppression de compte

`follows` et `achievements` supprimés en cascade ; l'export RGPD gagne
`achievements` et `follows`.
