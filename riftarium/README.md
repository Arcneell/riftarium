# Riftarium

Compagnon communautaire tout-en-un pour **Riftbound**, le TCG de Riot Games :
cartothèque, collection personnelle, deck builder avec validation des règles officielles,
et partage de decks avec likes et modération automatique.

**Projet fan-made à but non lucratif, non affilié à Riot Games. Bêta fermée, non indexée.**

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
| Scan mobile, estimation Cardmarket, textes FR (sans stats de méta) | 🔜 |

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

Le service `web` est le seul rattaché au réseau externe `bunkerweb` ;
`api`, `db` et `redis` restent sur le réseau interne du projet. Créer ce
réseau une fois sur le VPS, puis y rattacher le conteneur BunkerWeb.
BunkerWeb n'autorise par défaut que GET/POST/HEAD : sans
`ALLOWED_METHODS=GET|POST|HEAD|OPTIONS|PUT|PATCH|DELETE` (voir
`bunkerweb.env.example`), les changements d'avatar, de collection et de
decks répondent 405.

```bash
docker network create bunkerweb
docker network connect bunkerweb <conteneur-bunkerweb>
```

```bash
cp .env.example .env
docker compose up -d --build
```

### E-mails (SMTP OVH)

Les e-mails transactionnels (vérification d'adresse, réinitialisation de mot de
passe) partent de la boîte OVH `contact@riftarium.re`. Variables dans `.env` :

| Variable | Valeur OVH |
| --- | --- |
| `SMTP_HOST` | `ssl0.ovh.net` (vide = mode console : e-mails loggés, pas envoyés) |
| `SMTP_PORT` | `465` (SSL implicite) ou `587` (STARTTLS) |
| `SMTP_USER` | l'adresse complète : `contact@riftarium.re` |
| `SMTP_PASSWORD` | mot de passe de la boîte |
| `MAIL_FROM` | `Riftarium <no-reply@riftarium.re>` (défaut ; SMTP_USER reste `contact@`) |
| `PUBLIC_BASE_URL` | base des liens ; vide = `https://riftarium.re` en prod, `http://localhost:8888` sinon |

En développement, ne rien configurer : `SMTP_HOST` vide active le **mode
console** — le destinataire et le lien complet sont loggés par l'API
(logger `riftarium.mailer`), pratique pour tester les flux sans boîte mail.
Un échec SMTP est loggé mais ne fait jamais échouer la requête.

### Développement local

Surcouche `compose.dev.yaml` : code monté en volume, HMR Vite, uvicorn
`--reload`, pas de réseau `bunkerweb` à créer.

```bash
docker compose -f compose.yaml -f compose.dev.yaml up -d
```

- Front : http://localhost:8888 (Vite) — API : http://localhost:8889
  (`API_PORT` dans `.env` pour changer).
- Tests : ils tournent hors Docker (l'image de prod n'embarque ni `tests/`
  ni pytest) :

```bash
cd apps/api && pip install -r requirements.txt -r requirements-dev.txt && pytest -q
cd apps/web && npm ci && npm test
```

### Migrations de schéma

Le schéma est versionné avec [Alembic](https://alembic.sqlalchemy.org/)
(`apps/api/alembic/`). Les migrations s'appliquent **automatiquement au
démarrage de l'API** (`run_migrations()` dans `app/db.py`) : rien à lancer
en déploiement. Après un changement dans `app/models.py`, générer la
migration puis la relire avant de la committer :

```bash
cd apps/api && alembic revision --autogenerate -m "description du changement"
```

Reprise des instances existantes : une base créée avant Alembic (via
l'ancien `create_all` + `ensure_schema`) est détectée au démarrage (tables
présentes, pas de table `alembic_version`) et marquée (`stamp`) sur la
baseline 0001 sans la rejouer. 0001 décrit le schéma visé (e-mails inclus),
pas forcément celui réellement en place : la migration 0002 backfill alors
`users.email_verified_at` et `auth_tokens` si elles manquent.

### Sauvegardes PostgreSQL

`scripts/backup_db.sh` fait un `pg_dump` compressé dans `backups/`
(rétention : 14 fichiers, réglable via `BACKUP_RETENTION`). Il est appelé
automatiquement par `deploy.sh` avant chaque mise à jour. En complément,
programmer une sauvegarde quotidienne :

```cron
0 4 * * * cd /opt/riftarium/riftarium && bash scripts/backup_db.sh >> /var/log/riftarium-backup.log 2>&1
```

Le dossier `backups/` n'est ni versionné ni envoyé dans le contexte de build
Docker (`.gitignore` + `.dockerignore`). **Recommandé** : copier régulièrement
ces dumps hors du VPS (rsync/rclone vers un stockage distant) — une sauvegarde
sur la même machine ne protège ni d'une panne disque ni d'une compromission.

### CD depuis main

Après une CI verte, GitHub Actions se connecte en SSH, aligne le clone du VPS
sur `origin/main` (`git checkout -B main FETCH_HEAD`), reconstruit les images
et relance Compose. Si le healthcheck échoue, `deploy.sh` revient
automatiquement au commit précédent (re-checkout + rebuild). BunkerWeb n'est
pas touché. Le `.env` du VPS n'est pas dans git : l'alignement du clone ne
l'écrase pas.

**Une fois sur le VPS**

1. Clone HTTPS du dépôt **à la racine git** (fichier `.github/` + dossier
   `riftarium/`), par exemple `/opt/riftarium`. Le dépôt est public : pas
   besoin de clé GitHub sur le VPS. `DEPLOY_PATH` est ce chemin, pas le
   sous-dossier Compose.
2. Utilisateur SSH dédié, dans le groupe `docker`, sans mot de passe (clé
   uniquement).
3. `riftarium/.env` déjà rempli. `curl` et Docker Compose v2 installés.
4. Clé publique de GitHub Actions dans `~/.ssh/authorized_keys` de cet
   utilisateur. Clé privée **uniquement** dans les secrets GitHub, jamais
   dans le dépôt.

**Secrets GitHub** (Settings → Environments → `production`, ou secrets du
dépôt) :

| Secret | Exemple de contenu |
| --- | --- |
| `DEPLOY_HOST` | IP ou nom d'hôte SSH du VPS |
| `DEPLOY_USER` | utilisateur SSH |
| `DEPLOY_PATH` | racine du clone (`/opt/riftarium`, là où se trouve `.github/`) |
| `DEPLOY_SSH_KEY` | clé privée Ed25519 complète (Actions → VPS) |
| `DEPLOY_KNOWN_HOSTS` | sortie de `ssh-keyscan -t ed25519,rsa HOST` |
| `DEPLOY_PORT` | optionnel, `22` par défaut |

Empreinte du serveur, à coller dans `DEPLOY_KNOWN_HOSTS` :

```bash
ssh-keyscan -t ed25519,rsa HOST
```

Une fois les secrets renseignés, fusionner cette branche dans `main` déclenche
le premier déploiement automatique. On peut aussi lancer *Run workflow* sur
« Déploiement production », branche `main`.

Ne pas modifier le code sur le VPS : le prochain déploiement écrase les
fichiers suivis.

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

## Scan mobile

La reconnaissance de cartes repose sur des empreintes perceptuelles (dHash) calculées
côté serveur : après une sync, lancer `POST /api/admin/cards/hashes` (en-tête
`X-Admin-Token`) et répéter l'appel jusqu'à `remaining=0` pour peupler les empreintes.

## Sources de données

- Cartes : [API Riftcodex](https://api.riftcodex.com/docs) (communautaire, gratuite) —
  synchronisées en base locale pour ne pas la solliciter à chaque requête.
- Visuels : CDN officiel Riot (`cmsassets.rgpub.io`) — jamais copiés ni rehébergés.
- Règles officielles : texte français intégral embarqué dans le dépôt (`data/rules-fr.json`).

## Mentions légales

Riftarium isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing Riot Games properties. Riot Games, and all associated properties are trademarks or registered trademarks of Riot Games, Inc.

Riftarium n'est pas approuvé par Riot Games et ne reflète pas les opinions de Riot Games ni de quiconque officiellement impliqué dans la production ou la gestion des propriétés de Riot Games.

Riftarium was created under Riot Games' "Legal Jibber Jabber" policy using assets
owned by Riot Games. Riot Games does not endorse or sponsor this project.

Riftarium a été créé en vertu de la politique « Legal Jibber Jabber » (Jargon juridique)
de Riot Games, à partir d'actifs appartenant à Riot Games. Riot Games ne soutient ni
ne sponsorise ce projet. Riftbound, League of Legends et tous les visuels et textes de
cartes sont © Riot Games, Inc. En bêta, les textes de cartes viennent de Riftcodex en
attendant l'API officielle Riot. Le code de Riftarium est propriétaire, publié en source
accessible (voir [LICENSE](../LICENSE)) ; la licence ne couvre aucun actif Riot.
