# WORKFLOW.md — Riftarium : web, API et application mobile

Mode d'emploi du dépôt pour les personnes et les agents (Claude Code, Cursor).
À lire avant toute tâche. Ce document fait autorité sur l'organisation du dépôt
et la feuille de route mobile ; le détail technique de chaque application reste
dans son propre `README.md`.

## 1. Décision (27 août 2026)

- **La PWA n'est plus la cible mobile.** Elle reste servie par le site tant que
  l'application n'est pas publiée (icône iOS capricieuse, premier chargement
  lent à cause du moteur OCR tesseract.js de 15 Mo, service worker complexe pour
  peu de gain).
- **Cible mobile : une application native iOS + Android en Flutter**, dans
  `riftarium/apps/mobile`. Une seule base de code Dart, rendu natif, caméra et
  reconnaissance de texte via plugins natifs (ML Kit).
- **Le site Vue reste la version web** (desktop et mobile web). Web et mobile
  consomment la même API FastAPI.
- **Pas de fork, pas de second dépôt** : monorepo. L'API évolue avec le mobile,
  une fonctionnalité = une branche qui peut toucher `api` et `mobile` ensemble.
- Écartés : Swift seul (pas d'Android), Kotlin Multiplatform (langage inconnu du
  mainteneur), Capacitor (webview, pas de rendu natif), React Native.

## 2. Carte du dépôt

```
riftarium/
  apps/api/      FastAPI + SQLAlchemy + Alembic, PostgreSQL, Redis   -> image Docker `api`
  apps/web/      Vue 3 + Vite, servi par nginx (proxy /api)          -> image Docker `web`
  apps/mobile/   Flutter (iOS + Android)                             -> jamais dans Docker
  compose.yaml   production (VPS OVH, derrière BunkerWeb)
  compose.dev.yaml  surcouche dev : HMR Vite sur :8888, API sur :8889
  data/          rules-fr.json (règles officielles, embarquées dans l'image web)
  scripts/       deploy.sh, backup_db.sh, check_compose_security.py, migrate_pg18.sh
.github/workflows/
  ci.yml         api-test, web-check, compose-security : checks REQUIS de main,
                 réutilisé par deploy.yml (workflow_call). Ne pas y ajouter Flutter.
  deploy.yml     push sur main -> CI -> SSH VPS -> deploy.sh. Ignore apps/mobile et la doc agents.
  mobile.yml     Flutter : format, analyze, test (pas de build APK : quota Actions).
                 Déclenché seulement si apps/mobile change.
  dependabot-automerge.yml  auto-merge patch/minor pip et npm uniquement (pas pub).
WORKFLOW.md      ce fichier
CLAUDE.md        pointeur vers ce fichier pour Claude Code
.cursor/rules/riftarium.mdc  pointeur vers ce fichier pour Cursor
```

## 3. Règles d'isolation (ce qui garantit que le mobile ne casse rien)

1. `apps/mobile` n'entre jamais dans une image Docker : `riftarium/.dockerignore`
   l'exclut et les Dockerfiles ne copient que des chemins explicites
   (`apps/web/**`, `data/rules-fr.json`, `apps/api/**`). Ne pas élargir ces `COPY`.
2. Un commit qui ne touche que `apps/mobile`, `mobile.yml`, `WORKFLOW.md`,
   `CLAUDE.md` ou `.cursor/` **ne redéploie pas le VPS** (`paths-ignore` dans
   `deploy.yml`). Le cron hebdomadaire et le déclenchement manuel ne sont pas filtrés.
3. `ci.yml` reste tel quel : ses trois jobs sont les checks requis de `main` et
   doivent tourner sur toute PR (un filtre `paths` les ferait sauter et bloquerait
   le merge). Flutter vit dans `mobile.yml`.
4. **Ne pas modifier `apps/web` ou `apps/api` pour un besoin mobile**, sauf
   changement de contrat d'API décrit en §6 : dans ce cas l'API bouge d'abord,
   avec tests pytest, en restant compatible avec le web existant.
5. **Ne pas retirer** le scanner web (`scanOcr.js`, `useCardScanner.js`,
   `ScanView.vue`, `/ocr/*`), le service worker (`public/sw.js`) ni le manifest
   (`site.webmanifest`) tant que l'application n'est pas en store (§8, phase 9).
6. Secrets et signatures hors git : `android/key.properties`, `*.jks`,
   `*.keystore`, profils et certificats iOS. Les `.gitignore` de `apps/mobile`,
   `android/` et `ios/` générés par Flutter les couvrent ; vérifier avant d'ajouter
   un fichier de signature.

## 4. Toolchain

| Outil | Version | Où |
| --- | --- | --- |
| Flutter | **3.41.2** stable (Dart 3.11.0) | épinglée dans `mobile.yml` : monter local et CI ensemble |
| Android SDK | 36 (`flutter doctor` vert) | Windows du mainteneur + Mac |
| Xcode + CocoaPods | version courante | Mac uniquement (build, signature, App Store) |
| Node | 24+ (CI : 26) | `apps/web` |
| Python | 3.12+ (CI : 3.14), **venv obligatoire** | `apps/api` |

Identifiants de l'application : bundle/applicationId **`re.riftarium.app`**
(Android `namespace` + `applicationId` dans `android/app/build.gradle.kts`,
iOS `PRODUCT_BUNDLE_IDENTIFIER` dans `Runner.xcodeproj`). Paquet Dart :
`riftarium_mobile`. Nom affiché : `Riftarium`.

Commandes mobile (depuis `riftarium/apps/mobile`) :

```bash
flutter pub get
flutter run                     # appareil ou émulateur branché ; -d <id> pour choisir
flutter build apk --debug       # valide la config Gradle (Windows ou Mac)
scripts/apk.sh [--install]     # APK de test dans dist/ (release signé debug, toutes ABI),
                                # installation adb en option ; jamais en CI (quota Actions)
flutter build ipa               # Mac seulement, compte développeur Apple requis
```

Mise à jour de Flutter : `flutter upgrade`, puis reporter la version dans
`mobile.yml` et ce tableau, puis `flutter analyze` + `flutter test`.

## 5. Vérifier avant de pousser

Lancer les vérifications de **chaque application touchée**. Ce sont exactement
celles de la CI.

```bash
# web  (riftarium/apps/web)
npm run check                                   # lint + format:check + test + build
# stack dev Docker : après tout `npm install`, `docker restart riftarium-web`

# api  (riftarium/apps/api, dans le venv)
ruff check app tests && ruff format --check app tests && pytest -q

# mobile  (riftarium/apps/mobile)
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter build apk --debug       # si un plugin natif, android/ ou ios/ a changé

# compose  (riftarium/)
docker compose -f compose.yaml config --quiet && python scripts/check_compose_security.py
```

## 6. Contrat API pour le mobile

- **Base URL** : prod `https://riftarium.re/api`. Dev (compose.dev) :
  `http://<IP LAN du PC>:8889/api` depuis un téléphone, `http://10.0.2.2:8889/api`
  depuis l'émulateur Android, `http://localhost:8889/api` depuis le simulateur iOS.
  L'URL est une constante de build (`--dart-define=API_BASE_URL=...`), jamais
  codée en dur dans un écran.
- **Authentification web** : cookie HttpOnly `riftarium_session` (JWT HS256,
  TTL `jwt_ttl_hours` = 24 h). `current_user` (`app/auth.py`) accepte aussi
  `Authorization: Bearer <jwt>` (le Bearer prime sur le cookie) ; sans en-tête
  mobile, `POST /api/auth/login` et `/register` renvoient
  `SessionOut {handle, avatar_url, is_admin}` **sans le jeton**.
  `enforce_same_origin` laisse passer les requêtes sans en-tête `Origin`
  (client natif) : rien à changer côté anti-CSRF.
- **Choix pour le mobile : Bearer**, jeton en stockage sécurisé
  (Keychain / Keystore). Contrat livré en phase 1, rétrocompatible avec le web :
  1. si l'en-tête `X-Riftarium-Client: mobile` est présent (casse ignorée),
     `POST /api/auth/login` et `/register` renvoient `SessionOut` avec `token` ;
     sans l'en-tête, la clé `token` est absente (sérialiseur du modèle, pas de
     `null`) et le cookie reste posé dans les deux cas ;
  2. TTL du jeton mobile : `jwt_ttl_hours_mobile` = 720 h (30 jours). La révocation
     globale (`token_version`, changement de mot de passe) s'applique telle quelle :
     après `POST /api/auth/password`, l'app doit se reconnecter (cette route ne
     renvoie pas de jeton mobile) ;
  3. `POST /api/auth/logout` : côté mobile, l'oubli du jeton suffit ; l'appel est
     fait quand même, sans bloquer la déconnexion locale s'il échoue ;
  4. côté Flutter : `core/api_client.dart` (en-tête + Bearer), `core/token_store.dart`
     (flutter_secure_storage), `features/auth/application/auth_controller.dart`
     (restauration au démarrage, connexion, inscription, déconnexion).
  Les limites `limit_auth` / `limit_auth_account` s'appliquent : pas de retry
  automatique sur les endpoints d'authentification. Tests : `tests/test_mobile_auth.py`.
- **Endpoints réutilisés tels quels** : `GET /api/cards` (recherche, filtres,
  pagination), `GET /api/cards/{id}`, `GET /api/cards/{id}/variants`,
  `GET /api/sets`, `GET /api/prices/meta`, `GET /api/cards/hashes` (index du
  scan), `/api/collection/*`, `/api/wishlist/*`, `/api/decks*` et communauté,
  `/api/auth/*` (mot de passe oublié, vérification e-mail, export RGPD),
  `/api/metrics` (pages : ajouter une valeur `mobile` si l'on trace l'app).
  Référence : `apps/api/app/routers/*.py` et `apps/api/app/schemas.py`.
- **Raretés** : quatre raretés fonctionnelles (Common, Uncommon, Rare, Epic).
  « Showcase » = famille des impressions spéciales : alt-arts (gemme
  hexagonale), overnumbered (n° ≥ taille du set), signatures (overnumber signé,
  `*` dans l'identifiant). Les données source ne la codent pas de façon
  homogène (rareté « Showcase » sur les alt-arts d'OGN et SFD seulement) :
  `rarity=Showcase` côté API inclut `alternate_art | overnumbered | signature`
  (`apply_filters`, tests `test_showcase_filter.py`).
- **Images de cartes** : hôtes autorisés par `allowed_image_hosts()`
  (`app/security.py`) ; mise en cache côté app (`cached_network_image`).
- **Codes de deck** : le web utilise la bibliothèque JS
  `@piltoverarchive/riftbound-deck-codes` (`apps/web/src/deckExport.js`). Le
  mobile doit **porter le format en Dart** (format documenté dans la bibliothèque
  JS, tests croisés avec les codes produits par le web). Un endpoint API n'est
  envisageable que si une implémentation Python fiable existe. À trancher en phase 4.
- **Règles officielles** : `data/rules-fr.json` embarqué dans l'app comme asset
  (consultation hors ligne, comme le service worker le permettait) ; rafraîchi
  depuis `https://riftarium.re/data/rules-fr.json` quand le réseau est là.
- **Scan** : le web identifie par empreinte dHash côté client + lecture OCR du
  code collector, contre l'index `GET /api/cards/hashes`. Le mobile lit le code
  collector avec ML Kit (natif, instantané) ; la dHash n'est réimplémentée en
  Dart (paquet `image`) que si la lecture du code ne suffit pas.

## 7. Architecture Flutter cible

```
lib/
  main.dart               bootstrap (ProviderScope, router, thème)
  app/                    router (go_router), thème, widgets adaptatifs communs
  core/                   client HTTP (dio + intercepteur Bearer), stockage sécurisé,
                          erreurs API typées, configuration (--dart-define)
  features/<domaine>/     auth, cards, collection, wishlist, decks, rules, scan, profile
    data/                 DTO + appels API
    domain/               modèles, logique métier pure (testable sans Flutter)
    ui/                   écrans et widgets du domaine
test/                     miroir de lib/ ; tests de widgets par écran, tests unitaires
                          du client API avec mock ; pas de goldens au départ
```

- **Paquets** : `go_router`, `dio`, `flutter_riverpod` 2.x, `flutter_secure_storage`,
  `cached_network_image` + `flutter_cache_manager`, `flutter_svg` (glyphes
  officiels), `google_mlkit_text_recognition` + `camera`, `share_plus`,
  `url_launcher`, `path_provider`. Chaque ajout de plugin natif = `flutter build
  apk --debug` avant push.
- **Rendu** : la charte du site (`apps/web/src/assets/main.css`) transposée dans
  `lib/app/design/` (tokens, typographie Marcellus / Outfit / IBM Plex Mono
  embarquées, thème clair et sombre, bannières d'illustration, reflet foil,
  révélations en cascade, squelettes, boutons or, puces de domaine). **Lire
  `lib/app/design/README.md` avant tout écran.** iOS garde ses gestes et
  transitions ; l'habillage est celui de la marque sur les deux plateformes.
- **Images** : jamais d'URL de carte brute. `CardImage` redimensionne via le CDN
  (`w=`), met en cache 30 jours (`riftImageCache`) et `precacheCardThumbs`
  précharge la page suivante d'une grille.
- **Navigation** : onglets Accueil, Cartes, Collection, Decks (segment Mes decks |
  Communauté), Règles (hub : guide du débutant, aide avancée, texte officiel) ;
  profil derrière l'avatar en haut à droite ; scanner en plein écran.
- **Guides de règles** : `assets/rules/guides-fr.json` est exporté depuis
  `apps/web/src/rules/{topics,guide}.js` (depuis `apps/web`) :
  `node --input-type=module -e "import {TOPICS,CATEGORIES} from './src/rules/topics.js'; import {STEPS,CARDS,SPOTS} from './src/rules/guide.js'; import {writeFileSync} from 'node:fs'; writeFileSync('../mobile/assets/rules/guides-fr.json', JSON.stringify({categories:CATEGORIES,topics:TOPICS,guide:{steps:STEPS,cards:CARDS,spots:SPOTS}}))"`.
  À relancer quand les guides du site changent.
- **Suivi des matchs** (`/api/play`, salons, matchs confirmés, historique,
  statistiques) : contrat dans `riftarium/docs/suivi-des-matchs.md`, source de
  vérité pour l'API, le mobile et le site. Toute évolution passe d'abord par ce
  fichier.
- **Profils publics, hauts faits, amis** : contrat dans
  `riftarium/docs/profils-et-hauts-faits.md` (réglages de confidentialité,
  catalogue des hauts faits, suivis). Les hauts faits de duel ne comptent que les
  matchs suivis confirmés, jamais la partie libre.
- **Dette connue** : le rendu du texte enrichi existe deux fois
  (`features/cards/domain/card_text.dart` + `ui/widgets/card_glyph.dart`, et
  `features/rules/ui/rule_rich_text.dart`). À fusionner dans `lib/app/design/`
  (garder le gras et les abréviations `[R] [1] [E]` de la version règles, le
  cache mémoire des SVG de la version cartes).
- **Conventions** : identifiants en anglais (convention Dart), textes d'interface,
  commentaires, commits et documentation en français ; `flutter_lints` +
  `dart format` par défaut (80 colonnes) ; pas de code Kotlin/Swift maison au-delà
  de la colle exigée par un plugin.
- **Hors ligne** : règles disponibles sans réseau ; le reste affiche un état
  « hors ligne » explicite (pas de cache silencieux des données de compte).

## 8. Feuille de route

Cocher au fil de l'eau ; une phase = une ou plusieurs branches `feat/mobile-*`.

- [x] **Phase 0 : squelette.** `apps/mobile` créé, identifiants `re.riftarium.app`,
      `mobile.yml`, `paths-ignore` dans `deploy.yml`, Dependabot `pub`,
      `.dockerignore`, ce document.
- [x] **Phase 1 : authentification.** API (`token` dans `SessionOut` pour le client
      mobile, TTL 30 jours), écrans connexion / inscription (widgets adaptatifs
      Cupertino / Material), session persistée en stockage sécurisé, profil
      minimal (e-mail, statistiques), déconnexion. Reste pour plus tard : lien
      « mot de passe oublié » vers le site (url_launcher, phase 7).
- [x] **Phase 2 : cartothèque.** Grille paginée, recherche, filtres (set, type,
      domaine, rareté, énergie, tri, possédées/manquantes), fiche carte (zoom,
      prix + métadonnées, variantes, lien site). Un seul choix par facette pour
      l'instant (l'API accepte le CSV : évolution possible dans `CardFilters`).
- [x] **Phase 3 : collection et wishlist.** Résumé, complétion par set, recherche
      API, lots (qty / état / langue), feuille d'édition, wishlist ;
      `CardCollectionActions` dans la fiche carte (stepper + wishlist).
- [x] **Phase 4 : decks.** Mes decks, détail (checks API, cartes par zone,
      manquantes, like, partage), éditeur avec règles en direct
      (`deck_rules.dart`, portage de `validation.py`), communauté (légendes,
      filtres, pagination), codes de deck portés en Dart (`deck_code.dart`,
      formats 1.1 → 1.5, 13 codes croisés avec la bibliothèque JS), import par code.
- [x] **Phase 5 : règles.** Asset embarqué + rafraîchissement en ligne mis en cache
      (dossier documents), recherche accent-insensible, chapitres / sections /
      règles, exemples, renvois. Recopier l'asset quand `data/rules-fr.json` change.
- [x] **Phase 6 : scan.** Caméra + ML Kit (latin), lecture du code collector ligne
      par ligne, stabilisation, résolution via `GET /api/cards/hashes` (index
      `rid` → id, chargé une fois), fiche + prix, « +1 » par
      `POST /collection/{id}/entries`, historique de session. Pas de dHash.
      Android : `proguard-rules.pro` (`-dontwarn` sur les scripts ML Kit non
      embarqués, sinon R8 échoue en release), caméra déclarée optionnelle.
      À valider sur appareil réel (cadrage, luminosité, vitesse).
- [x] **Phase 7 : finitions.** Icônes (Android adaptatif + iOS, générées depuis
      `apps/web/public/icon-512.png`, 1024 px suréchantillonné : à régénérer depuis
      un visuel plus grand avant publication), écrans de lancement parchemin,
      liens `riftarium.re/cartes/*` et `/decks/*` ouverts dans l'app (Android,
      sans autoVerify), profil : renvoi de vérification, changement de mot de
      passe, export RGPD (partage), suppression de compte, liens légaux. APK de
      test construit en local (`scripts/apk.sh`), jamais en CI (quota Actions).
- [ ] **Phase 8 : publication.** Comptes développeur (Apple 99 $/an, Google 25 $),
      signature (keystore Android + `key.properties` hors git, certificats iOS),
      `ios/Podfile` : `platform :ios, '15.5'` (ML Kit), TestFlight et test interne
      Play, build IPA sur runner macOS, fiches store. Liens profonds vérifiés :
      publier `/.well-known/assetlinks.json` (empreinte SHA-256 de la clé de
      signature) côté site et passer l'intent-filter en `autoVerify` ; iOS :
      entitlement Associated Domains + `apple-app-site-association` (Team ID).
      Régénérer les icônes depuis un visuel ≥ 1024 px.
- [ ] **Phase 9 : après publication.** Décider du retrait du service worker, du
      manifest PWA et du scanner web (15 Mo d'OCR). Décision à reprendre, pas acquise.

## 9. Workflow git

- Branche depuis `origin/main` : `feat/mobile-<sujet>` (mobile), `feat/<sujet>`
  ou `fix/<sujet>` (web, API). Ne pas empiler une branche sur une autre non mergée.
- Messages de commit en français, préfixe par domaine, comme l'historique :
  `Mobile : …`, `API : …`, `Web : …`, `Scanner : …`, `Sécurité : …`.
- Un commit = un sujet. Mélanger API et mobile est acceptable **uniquement** pour
  un changement de contrat d'API (§6) livré avec son premier usage.
- Pousser la branche ; le mainteneur merge et déploie (généralement le soir).
  Conditions : CI verte (`mobile-check` pour le mobile ; `api-test`, `web-check`,
  `compose-security` pour le reste) et vérifications locales de §5 passées.
- Les bumps Dependabot `pub` ne sont pas auto-mergés : valider avec un build sur appareil.

## 10. Quelle tâche, quelles étapes (pour les agents)

| Tâche | Où | Avant de pousser |
| --- | --- | --- |
| Interface ou logique web | `apps/web` uniquement | `npm run check` ; `docker restart riftarium-web` après ajout npm |
| Endpoint, schéma, migration | `apps/api` ; migration Alembic si le schéma change | ruff + pytest dans le venv ; rétrocompatibilité web |
| Écran ou logique mobile | `apps/mobile` uniquement | format + analyze + test ; `build apk --debug` si natif touché |
| Besoin mobile qui manque à l'API | API d'abord (tests, compat web), puis mobile, même branche | les deux jeux de vérifications |
| Compose, Dockerfile, nginx, BunkerWeb | `riftarium/` racine, `apps/*/Dockerfile` | `compose config` + `check_compose_security.py` |
| CI / déploiement | `.github/workflows` | garder `ci.yml` intact ; pas de `paths` sur les checks requis |
| Documentation d'organisation | ce fichier | mettre à jour §8 (phases) et §4 (versions) |

En cas de doute entre deux lectures d'une demande qui mèneraient à un travail
différent (retirer ou non du code web, changer ou non l'API), poser la question
avant de coder ; sinon, trancher selon ce document et le dire dans le compte rendu.
