# Riftarium

Compagnon communautaire tout-en-un pour **Riftbound**, le TCG de Riot Games :
cartothèque, collection personnelle, deck builder avec validation des règles officielles,
et partage de decks avec likes et modération automatique.

**Projet fan-made à but non lucratif, non affilié à Riot Games.**

## Lancer

```bash
docker compose up --build -d
```

- Site : <http://localhost:8888> (changer avec `PORT=3000 docker compose up`)
- API : <http://localhost:8889/docs> (OpenAPI)

> Ports par défaut 8888/8889 : sur Windows, les plages 7236-8035 et 8054-8553 sont
> souvent réservées par Hyper-V (`netsh interface ipv4 show excludedportrange protocol=tcp`).

Au premier démarrage, l'API synchronise automatiquement les ~1 300 cartes des 6 sets
depuis l'API communautaire [Riftcodex](https://api.riftcodex.com/docs) vers PostgreSQL
(~30 s). Resynchroniser : `curl -X POST http://localhost:8888/api/admin/sync`.

## Développer (rechargement à chaud, sans rebuild)

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d
```

- Front : Vite avec HMR sur <http://localhost:8888> — toute modification dans
  `apps/web/src` s'affiche immédiatement.
- API : `uvicorn --reload` — toute modification dans `apps/api/app` redémarre le serveur.
- Le code est monté en volume ; on ne rebuild une image que si `package.json`,
  `requirements.txt` ou un Dockerfile change (`docker compose -f compose.yaml -f compose.dev.yaml up -d --build`).

## Architecture

```
apps/web   Vue 3 + Vite, servi par nginx (proxy /api vers l'API)
apps/api   FastAPI (Python 3.12) : cartes, auth JWT, collection, decks, communauté
db         PostgreSQL 16
redis      Cache des lectures publiques (cartes, sets) + garde-fous
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

| Fonction | État |
| --- | --- |
| Cartothèque (recherche, filtres set/domaine/type, fiche carte) | ✅ |
| Comptes (inscription, connexion, JWT) | ✅ |
| Collection (quantités, état, langue) | ✅ |
| Deck builder + validation règles tournoi / mode libre | ✅ |
| Decks publics, likes | ✅ |
| Modération automatique (filtre lexical V1, statut `pending`) | ✅ |
| Scan mobile, estimation Cardmarket, textes FR, fil social complet | 🔜 voir [REFONTE.md](../REFONTE.md) |

## Tests

Chaque PR doit passer la CI (API, front, `docker compose config`). En local :

```bash
docker compose run --rm api pytest -q       # tests API (SQLite en mémoire)

# depuis apps/web, après npm ci
npm run check                               # lint, formatage, Vitest, build
```

## Sources de données

- Cartes : [API Riftcodex](https://api.riftcodex.com/docs) (communautaire, gratuite) —
  synchronisées en base locale pour ne pas la solliciter à chaque requête.
- Visuels : CDN officiel Riot (`cmsassets.rgpub.io`) — jamais copiés ni rehébergés.
- Règles officielles : texte français intégral embarqué dans le dépôt (`data/rules-fr.json`).

## Mentions légales

Riftarium a été créé en vertu de la politique juridique de Riot Games intitulée
« Jargon juridique » relative à l'utilisation d'actifs de Riot Games. Riot Games ne
soutient ni ne sponsorise ce projet. Riftbound, League of Legends et tous les visuels
et textes de cartes sont © Riot Games, Inc. Le code de Riftarium est sous licence MIT ;
la licence ne couvre aucun actif Riot.
