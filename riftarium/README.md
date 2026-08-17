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
(~30 s). Resynchroniser : `curl -X POST http://localhost:8080/api/admin/sync`.

## Architecture

```
apps/web   Vue 3 + Vite, servi par nginx (proxy /api vers l'API)
apps/api   FastAPI (Python 3.12) : cartes, auth JWT, collection, decks, communauté
db         PostgreSQL 16
```

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

```bash
docker compose run --rm api pytest -q       # 14 tests API (SQLite en mémoire)
```

## Sources de données

- Cartes : [API Riftcodex](https://api.riftcodex.com/docs) (communautaire, gratuite) —
  synchronisées en base locale pour ne pas la solliciter à chaque requête.
- Visuels : CDN officiel Riot (`cmsassets.rgpub.io`) — jamais copiés ni rehébergés.
- Règles officielles : module hérité du projet Le Codex (`../le-codex/`).

## Mentions légales

Riftarium a été créé en vertu de la politique juridique de Riot Games intitulée
« Jargon juridique » relative à l'utilisation d'actifs de Riot Games. Riot Games ne
soutient ni ne sponsorise ce projet. Riftbound, League of Legends et tous les visuels
et textes de cartes sont © Riot Games, Inc. Le code de Riftarium est sous licence MIT ;
la licence ne couvre aucun actif Riot.
