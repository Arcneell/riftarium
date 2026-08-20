<p align="center">
  <img src="assets/logo.svg" width="170" alt="Logo Riftarium" />
</p>

<h1 align="center">Riftarium</h1>

<p align="center">
  <strong>Le compagnon tout-en-un pour Riftbound, le TCG de Riot Games.</strong><br />
  Cartothèque · Collection · Deck builder · Règles officielles · Communauté
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-source%20accessible-e5b455?style=flat-square" alt="Licence source accessible" /></a>
  <img src="https://img.shields.io/badge/python-3.12-3776ab?style=flat-square&logo=python&logoColor=white" alt="Python 3.12" />
  <img src="https://img.shields.io/badge/vue-3-42b883?style=flat-square&logo=vuedotjs&logoColor=white" alt="Vue 3" />
  <img src="https://img.shields.io/badge/postgresql-16-4169e1?style=flat-square&logo=postgresql&logoColor=white" alt="PostgreSQL 16" />
  <img src="https://img.shields.io/badge/tests-CI-55b368?style=flat-square" alt="Tests CI" />
</p>

<p align="center"><em>Projet fan-made à but non lucratif — non affilié à Riot Games. Bêta fermée, non indexée.</em></p>

---

## Licence

Le code source de Riftarium est **accessible publiquement**, mais le projet **n'est pas
open source** : il est publié à des fins de transparence et de consultation uniquement.
Toute copie, reproduction, modification, redistribution, déploiement ou réutilisation du
code, en tout ou partie, est interdite sans autorisation écrite préalable de l'auteur.
Voir [LICENSE](LICENSE).

## Fonctionnalités

| Fonction | Description |
| --- | --- |
| **Cartothèque** | Les 1 315 cartes des 6 sets (Origins → Vendetta), variantes alt-art incluses. Recherche plein texte, filtres par domaine, type, rareté et set |
| **Règles** | Texte officiel intégral en français : 2 137 règles du jeu + 812 règles de tournoi, avec recherche |
| **Deck builder** | Validation des règles de tournoi (légende unique, 3 champs de bataille, 12 runes, 40 cartes minimum, 3 exemplaires max, conformité des domaines) ou mode libre |
| **Collection** | Inventaire personnel : quantités, état, langue — compte requis |
| **Communauté** | Decks publics en boîtes, likes, vues uniques, filtres (légende, domaine, format, popularité) |
| **Comptes** | Sessions par cookie HttpOnly, vérification d'adresse e-mail, réinitialisation de mot de passe, export RGPD |
| **Modération** | Chaque contenu publié passe par un filtre automatique avant mise en ligne ; le reste part en file de revue |
| **Mobile** | Interface entièrement utilisable sur téléphone (règles lisibles, deck builder tactile) |

## Architecture

```
          ┌─────────────────────┐
Internet ─│  BunkerWeb (WAF/TLS) │  réseau Docker `bunkerweb`
 HTTPS    └──────────┬──────────┘
                     ▼
┌────────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  web  (Vue 3/Vite) │────▶│  api  (FastAPI)      │────▶│  db (PostgreSQL) │
│  nginx + SPA        │ /api│  auth JWT · decks    │     │  cartes · users  │
│  proxy /api         │     │  validation · modo   │     │  decks · likes   │
└────────────────────┘     └────┬─────┬──────────┘     └──────────────────┘
                                │     │                ┌──────────────────┐
                                │     └───────────────▶│  redis           │
                                │ resync manuelle      │  cache + limites │
                                ▼                      └──────────────────┘
                           ┌─────────────────────┐
                           │ api.riftcodex.com    │  (données de cartes)
                           │ cmsassets.rgpub.io   │  (visuels — CDN Riot)
                           └─────────────────────┘
```

## Structure du dépôt

```
riftarium/          Application (produit)
├── apps/web/       Front Vue 3 + Vite, servi par nginx
├── apps/api/       API FastAPI (Python 3.12) + tests pytest
├── data/           Règles officielles en français (JSON)
└── compose.yaml    Orchestration Docker (web + api + db + redis)
assets/             Identité visuelle (logo SVG)
```

## Qualité

Chaque pull request est bloquée tant que la CI GitHub n'est pas verte :
lint et formatage (ruff, ESLint, Prettier), tests API (pytest, couverture > 95 %),
tests front (Vitest), audit des dépendances (pip-audit, npm audit), build des
images Docker et validation de la configuration Compose.

- **Déploiement** : un merge dans `main` relance la CI puis déploie sur le VPS,
  avec sauvegarde de la base avant chaque mise en production et retour automatique
  à la version précédente si le contrôle de santé échoue.
  Détail : [riftarium/README.md](riftarium/README.md#cd-depuis-main).
- **Schéma de base** : versionné par migrations Alembic, appliquées au démarrage.
- **Dépendances** : Dependabot hebdomadaire ; les mises à jour mineures sont
  fusionnées automatiquement quand la CI passe, les majeures restent revues à la main.
- **Accessibilité & SEO** : Lighthouse 100/100 sur les pages types (contrastes,
  hiérarchie de titres, liens crawlables, sitemap).

## Feuille de route

- [x] Cartothèque, comptes, collection, deck builder, decks publics, modération V1
- [ ] Scan mobile (PWA + caméra, reconnaissance par empreinte visuelle)
- [ ] Textes officiels FR/EN via l'API Riot (demande d'accès en cours)
- [ ] Fil communautaire (partage de decks, profils) — sans résultats de tournoi ni statistiques de méta

## Contribuer

Les issues et pull requests sont bienvenues. Avant de proposer une fonctionnalité qui
touche aux données Riot (visuels, textes de cartes), vérifiez qu'elle respecte la
[politique développeur Riftbound](https://developer.riotgames.com/policies/riftbound)
et la politique « Jargon juridique » de Riot Games. En soumettant une contribution,
vous acceptez qu'elle soit intégrée au projet sous les termes de la [licence](LICENSE).

## Mentions légales

Riftarium isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.

Riftarium n'est pas approuvé par Riot Games et ne reflète pas les opinions de Riot Games ni de quiconque officiellement impliqué dans la production ou la gestion des propriétés de Riot Games. Riot Games et toutes les propriétés associées sont des marques ou des marques déposées de Riot Games, Inc.

Riftarium was created under Riot Games' "Legal Jibber Jabber" policy using assets
owned by Riot Games. Riot Games does not endorse or sponsor this project.

Riftarium a été créé en vertu de la politique « Legal Jibber Jabber » (Jargon juridique)
de Riot Games, à partir d'actifs appartenant à Riot Games. Riot Games ne soutient ni
ne sponsorise ce projet.

Riftbound, League of Legends et l'ensemble des visuels de cartes, illustrations, symboles
de domaine et textes officiels sont la propriété de © Riot Games, Inc. Les visuels sont
servis directement depuis le CDN officiel de Riot et ne sont ni copiés ni redistribués.
En bêta, les textes de cartes sont synchronisés depuis l'API communautaire Riftcodex
en attendant l'API officielle Riot. Le projet est et restera non commercial. La [licence](LICENSE) du code ne couvre ni le
texte des règles officielles, ni les illustrations, ni aucun actif appartenant à
Riot Games, Inc.
