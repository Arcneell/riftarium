# Riftarium

Compagnon communautaire tout-en-un pour **Riftbound**, le TCG de Riot Games :
cartothèque, collection personnelle, deck builder avec validation des règles officielles,
et partage de decks avec likes et modération automatique.

**Projet fan-made à but non lucratif, non affilié à Riot Games.**

## Licence

Le code source est **accessible publiquement**, mais ce projet **n'est pas open
source** : il est publié à des fins de transparence et de consultation uniquement.
Toute copie, reproduction, modification, redistribution ou réutilisation du code,
en tout ou partie, est interdite sans autorisation écrite préalable de l'auteur.
Voir [LICENSE](../LICENSE). Les issues et pull requests sont les bienvenues.

## Fonctionnalités

| Fonction | État |
| --- | --- |
| Cartothèque (recherche, filtres set/domaine/type, fiche carte) | ✅ |
| Comptes (inscription, connexion, JWT) | ✅ |
| Collection (quantités, état, langue) | ✅ |
| Deck builder + validation règles tournoi / mode libre | ✅ |
| Decks publics, likes, vues, filtres communauté | ✅ |
| Modération automatique (filtre lexical V1, statut `pending`) | ✅ |
| Scan mobile, estimation Cardmarket, textes FR, fil social complet | 🔜 |

## Architecture

```
apps/web   Vue 3 + Vite, servi par nginx (proxy /api vers l'API, port 8080 non-root)
apps/api   FastAPI (Python 3.12) : cartes, auth JWT (cookie HTTP-only), collection, decks
db         PostgreSQL 16
redis      Cache des lectures publiques + rate limit, mot de passe obligatoire
```

## Déploiement

```
Internet ──HTTPS──▶ BunkerWeb ──HTTP──▶ nginx (web:8080) ──▶ API (interne)
```

Copier `.env.example` vers `.env` et renseigner `JWT_SECRET`, `DB_PASSWORD`,
`ADMIN_TOKEN` et `REDIS_PASSWORD` (pas de valeurs par défaut en production).
La resync cartes se fait avec l'en-tête `X-Admin-Token`. L'API n'est pas
publiée ; le front n'écoute que `127.0.0.1` (BunkerWeb le joint via le réseau
Docker : `http://riftarium-web:8080`). Réglages WAF : `bunkerweb.env.example`.

```bash
cp .env.example .env
docker compose up -d --build
```

## Performances

- **Redis** : les réponses publiques (`/api/cards*`, `/api/sets`) sont mises en cache
  6 h et invalidées à chaque sync. Les réponses authentifiées (quantités possédées)
  ne sont jamais mises en cache.
- **Cache navigateur** : `Cache-Control: public, max-age=300` sur les lectures anonymes.
- **API Riftcodex ménagée** : une seule sync au premier démarrage, resync manuelle
  limitée à une par 10 minutes (HTTP 429 sinon), pause entre chaque page et
  `User-Agent` identifiant le projet. Le site ne requête jamais Riftcodex en direct :
  tout passe par la base locale.
- **Images** : servies par le CDN officiel de Riot (déjà mondialement distribué),
  `preconnect` au chargement, miniatures redimensionnées côté CDN (`w=180/260`),
  chargement paresseux. Elles ne sont volontairement pas rehébergées : la politique
  « Jargon juridique » interdit de redistribuer les visuels.

## Sources de données

- Cartes : [API Riftcodex](https://api.riftcodex.com/docs) (communautaire, gratuite) —
  synchronisées en base locale pour ne pas la solliciter à chaque requête.
- Visuels : CDN officiel Riot (`cmsassets.rgpub.io`) — jamais copiés ni rehébergés.
- Règles officielles : texte français intégral embarqué dans le dépôt (`data/rules-fr.json`).

## Mentions légales

Riftarium was created under Riot Games' "Legal Jibber Jabber" policy using assets
owned by Riot Games. Riot Games does not endorse or sponsor this project.

Riftarium a été créé en vertu de la politique « Legal Jibber Jabber » (Jargon juridique)
de Riot Games, à partir d'actifs appartenant à Riot Games. Riot Games ne soutient ni
ne sponsorise ce projet. Riftbound, League of Legends et tous les visuels et textes de
cartes sont © Riot Games, Inc. En bêta, les textes de cartes viennent de Riftcodex en
attendant l'API officielle Riot. Le code de Riftarium est propriétaire, publié en source
accessible (voir [LICENSE](../LICENSE)) ; la licence ne couvre aucun actif Riot.
