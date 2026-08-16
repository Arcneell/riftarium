# Le Codex — Guide communautaire Riftbound

Portail francophone qui héberge **le texte intégral des règles officielles de Riftbound** : 2 137 règles du jeu et 812 règles de tournoi, consultables directement sur le site avec sommaire, recherche instantanée et renvois cliquables.

## Lancer avec Docker

```bash
docker compose up --build
```

Le site est disponible sur <http://localhost:8080>. Pour changer de port :

```bash
PORT=3000 docker compose up --build
```

## Structure

Le site propose deux niveaux de lecture : un guide simplifié pour apprendre, et le texte officiel intégral pour vérifier.

| Fichier | Rôle |
| --- | --- |
| `index.html` | Accueil : présentation, domaines, accès rapides |
| `debuter.html` | Règles simplifiées (reformulation pédagogique) |
| `regles.html` | Règles avancées (texte officiel intégral) |
| `style.css` | Système de design commun aux trois pages |
| `learn.css` / `learn.js` | Mise en page et sommaire actif de la page débutant |
| `reader.css` / `reader.js` | Navigation, recherche et rendu du texte officiel |
| `data/rules-fr.json` | Règles structurées générées depuis les PDF officiels |
| `data/assets-fr.json` | Illustrations et symboles officiels retenus, avec crédits |
| `tools/parse_rules.py` | Conversion des PDF en JSON |
| `tools/build_assets.py` | Sélection des illustrations depuis la galerie officielle |
| `tools/shot.js` | Captures de contrôle du rendu (Puppeteer) |

Les deux niveaux sont clairement distingués : `debuter.html` est signalé comme une reformulation du Codex, `regles.html` reproduit le texte officiel sans modification.

## Régénérer les règles

Les données ne sont pas saisies à la main : elles sont extraites des PDF officiels français.

```bash
# 1. Récupérer les PDF depuis le hub des règles officiel
#    https://playriftbound.com/fr-fr/rules-hub/
#    -> sources/core-fr.pdf et sources/tournament-fr.pdf

# 2. Extraire le texte en conservant la mise en page
docker run --rm -v "${PWD}/sources:/data" alpine:3.20 sh -c \
  "apk add --no-cache poppler-utils && \
   pdftotext -layout -enc UTF-8 /data/core-fr.pdf /data/core-fr.txt && \
   pdftotext -layout -enc UTF-8 /data/tournament-fr.pdf /data/tournament-fr.txt"

# 3. Construire le JSON
python tools/parse_rules.py
```

À chaque mise à jour publiée par Riot Games, relancez ces trois étapes puis reconstruisez l'image.

## Régénérer les illustrations

Les visuels proviennent de la galerie de cartes officielle, qui expose ses données en JSON.

```bash
# 1. Relever l'identifiant de build courant de playriftbound.com
curl -s https://riftbound.leagueoflegends.com/fr-fr/card-gallery/ | grep -o '"buildId":"[^"]*"'

# 2. Télécharger la galerie (1 190 cartes)
curl -s "https://riftbound.leagueoflegends.com/_next/data/<BUILD_ID>/fr-fr/card-gallery.json" \
  -o sources/cards-fr.json

# 3. Sélectionner les visuels et leurs crédits
python tools/build_assets.py
```

`build_assets.py` produit `data/assets-fr.json` : symboles des six domaines, icônes de type, une carte emblématique par domaine, les champs de bataille et un exemplaire de chaque type de carte. Les URL retenues sont recopiées dans le HTML, ce qui évite un aller-retour réseau au chargement.

**Les images ne sont pas hébergées par ce projet** : elles sont chargées depuis `cmsassets.rgpub.io`, le CDN dont Riot se sert pour son propre site. Rien n'est redistribué dans l'image Docker.

### Vérifier le rendu

```bash
docker run --rm -v "${PWD}/shots:/shots" -v "${PWD}/tools:/usr/src/app/tools" \
  -w /usr/src/app --entrypoint node zenika/alpine-chrome:with-puppeteer \
  tools/shot.js http://host.docker.internal:8080/ /shots/accueil.png 1440
```

Le quatrième argument accepte un décalage en pixels ou un sélecteur CSS (`.anatomy`, `#champs`…) ; sans lui, la capture couvre la page entière.

## Propriété intellectuelle

Le texte des règles est reproduit **verbatim** depuis les documents officiels publiés par Riot Games ; il reste sa propriété. Le Codex n'apporte que la navigation, la recherche et la mise en forme. En cas de divergence, les PDF officiels du [hub des règles](https://playriftbound.com/fr-fr/rules-hub/) font foi.

Les illustrations, symboles de domaine et visuels de cartes appartiennent également à Riot Games, Inc. Chaque carte affichée mentionne son nom, son code collector et son studio d'illustration. Les visuels sont ceux de l'édition anglaise : c'est la seule version publiée dans la galerie officielle à ce jour.

À noter : la [politique développeur Riftbound](https://developer.riotgames.com/policies/riftbound) impose de passer par l'API Riot avec une clé applicative dès qu'un projet dépasse le cadre d'un usage personnel. Une mise en ligne publique demanderait donc d'enregistrer le projet et de basculer sur l'API officielle.

Ce projet doit rester non commercial et respecter la politique [« Jargon juridique » de Riot Games](https://www.riotgames.com/fr/mentions-legales). La mention exigée figure dans le pied de page :

> Le Codex a été créé en vertu de la politique juridique Riot Games intitulée « Jargon juridique » relative à l'utilisation d'actifs de Riot Games. Riot Games ne soutient ni ne sponsorise ce projet.

Avant toute mise en ligne publique, vérifiez que la version des règles affichée est bien la plus récente et que les conditions d'utilisation n'ont pas changé.

## Licence

Le code source de **Le Codex** (HTML, CSS, JavaScript, scripts et configuration Docker) est publié sous licence [MIT](LICENSE).

Cette licence **ne couvre pas** le texte des règles officielles, les illustrations, les symboles de domaine ni aucune autre marque ou actif appartenant à Riot Games, Inc. Ces éléments restent la propriété exclusive de leurs détenteurs et sont uniquement référencés ou affichés conformément à la politique « Jargon juridique » de Riot Games.
