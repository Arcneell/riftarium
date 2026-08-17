# Riftarium — Plan de refonte

> Reprise du projet **Le Codex** (guide de règles statique) vers **Riftarium** : compagnon
> communautaire tout-en-un pour Riftbound, le TCG de Riot Games.
> Projet fan-made, non commercial, non affilié à Riot Games.

## 1. Le nom

**Riftarium** — « Rift » (la Faille) + « -arium » (lieu qui abrite une collection, comme
aquarium ou herbarium). N'existe pas dans l'univers Riftbound ni dans le lore de Runeterra,
et vérifié libre sur internet (août 2026) : aucun site fan Riftbound ne l'utilise, contrairement
à Riftdex (riftdex.com, myriftdex.com), Riftbinder, Riftcodex, Rift Atlas ou RiftDecks.

⚠️ Caveat juridique : le préfixe « Rift » reste proche de la marque Riftbound. À valider avec
Riot lors de la demande d'accès API. Noms de repli prêts : **Faillecodex**, **Riftothèque**.

## 2. Périmètre fonctionnel

| Module | Description | Priorité |
| --- | --- | --- |
| **Cartothèque** | Toutes les cartes FR + EN, recherche plein texte, filtres (domaine, type, rareté, set, coût), fiche détaillée avec texte officiel dans les deux langues | P0 |
| **Collection** | Inventaire personnel : quantités, états (NM/EX/…), langues, éditions. Saisie manuelle + **scan mobile** (caméra → reconnaissance de carte) | P0 |
| **Estimation** | Valeur de la collection et de chaque carte via l'API Cardmarket (prix tendance, min, moyenne 30 j) | P1 |
| **Deck builder** | Construction avec validation des règles officielles (légende, 40 cartes, 12 runes, 3 champs de bataille, max 3 exemplaires) **ou mode libre** ; guide intégré pour débutants ; export/partage | P0 |
| **Communauté** | Publication de decks, likes, commentaires, publication de réussites (pulls, tournois), profils, abonnements | P1 |
| **Guides** | Reprise du contenu Le Codex : règles officielles intégrales + guide débutant (l'existant est conservé et migré) | P0 |
| **Modération automatique** | Filtrage des contenus publiés avant mise en ligne (texte + images) | P1 (obligatoire avant ouverture publique) |

## 3. Architecture technique

```
┌─────────────────────────────────────────────────────────┐
│  Front — Vue 3 + Vite (+ PWA)                            │
│  • SPA : Vue Router, Pinia                               │
│  • PWA installable mobile : accès caméra (scan),          │
│    cache hors-ligne de la cartothèque                     │
│  • i18n FR/EN (vue-i18n)                                  │
└──────────────────────┬──────────────────────────────────┘
                       │ REST + WebSocket (feed temps réel)
┌──────────────────────┴──────────────────────────────────┐
│  Back — Python 3.12 / FastAPI                            │
│  • Auth : OAuth2 + JWT (inscription email, RSO possible) │
│  • Services : cards, collection, pricing, decks,          │
│    social, moderation                                     │
│  • Tâches asynchrones : Celery + Redis                    │
│    (sync API Riot, sync prix Cardmarket, modération)      │
│  • Scan : pipeline de reconnaissance d'image              │
│    (perceptual hash + embeddings, index FAISS/pgvector)   │
└──────────────────────┬──────────────────────────────────┘
┌──────────────────────┴──────────────────────────────────┐
│  PostgreSQL 16                                           │
│  • + pgvector (reconnaissance scan, recherche sémantique)│
│  • + pg_trgm (recherche floue de noms de cartes)          │
│  Redis : cache, files Celery, rate limiting               │
│  Stockage objet (S3/minio) : avatars, photos de pulls     │
└─────────────────────────────────────────────────────────┘
```

### Choix front : Vue 3 plutôt qu'Astro

L'application est dominée par l'interactif (builder temps réel, scan caméra, feed social,
collection) : une SPA Vue avec PWA est le bon outil. Astro excelle sur du contenu statique ;
si besoin, la partie éditoriale (guides, règles) pourra être pré-rendue via SSG Nuxt plus tard.

### Sources de données

| Donnée | Source | Mode |
| --- | --- | --- |
| Cartes (texte, visuels FR/EN) | **API Riot / Riftbound** (clé applicative à demander) — en attendant : galerie officielle publique | Sync quotidienne (Celery) |
| Prix | **API Cardmarket** (compte pro requis, OAuth 1.0a) | Sync quotidienne, cache 24 h |
| Règles officielles | PDF officiels (pipeline `tools/parse_rules.py` conservé) | À chaque mise à jour Riot |

Les visuels ne sont **jamais rehébergés** : servis depuis le CDN Riot (`cmsassets.rgpub.io`),
conformément à la politique « Jargon juridique ».

### Scan mobile — principe

1. PWA ouvre la caméra (getUserMedia), l'utilisateur cadre la carte.
2. Capture → recadrage automatique (détection de contours côté client, OpenCV.js).
3. Envoi au back : hash perceptuel + embedding image comparés à l'index des ~1 200 cartes
   (pgvector). Retour < 1 s avec les 3 meilleures correspondances.
4. Confirmation utilisateur → ajout à la collection (quantité, état, langue).

### Modération automatique

- **Texte** (descriptions de decks, commentaires, posts) : filtre lexical multilingue +
  classification ML (API de modération ou modèle local), file de revue humaine pour les cas limites.
- **Images** (photos de pulls, avatars) : détection NSFW avant publication.
- Signalement communautaire + audit log ; rien n'est publié sans passage par le pipeline.

## 4. Modèle de données (PostgreSQL — simplifié)

```
users(id, handle, email, locale, created_at, …)
cards(id, code, set, type, rarity, orientation, image_url, …)
card_locales(card_id, lang, name, text)           -- FR + EN
card_prices(card_id, source, trend, avg30, low, fetched_at)
collections(user_id, card_id, qty, condition, lang, foil)
decks(id, user_id, name, legend_card_id, format, is_public, likes_count)
deck_cards(deck_id, card_id, zone, qty)           -- main / runes / battlefields / side
posts(id, user_id, kind, body, image_url, moderation_status)
likes(user_id, subject_type, subject_id)
comments(id, post_id|deck_id, user_id, body, moderation_status)
moderation_events(id, subject, verdict, model, reviewed_by)
card_embeddings(card_id, embedding vector)         -- scan
```

## 5. Phases

1. **Maquette** (`maquette/`) — démo visuelle à présenter à Riot pour la demande d'accès API. ✅ ce dépôt
2. **Socle** — monorepo (`apps/web` Vue, `apps/api` FastAPI, `infra/` compose), auth, cartothèque en lecture (données galerie publique), migration des guides Le Codex.
3. **Collection + prix** — inventaire, import CSV, intégration Cardmarket.
4. **Deck builder** — validation règles, mode libre, partage par lien.
5. **Communauté + modération** — feed, likes, profils ; pipeline de modération obligatoire avant ouverture.
6. **Scan mobile** — PWA caméra + reconnaissance.

## 6. Cadre légal (inchangé et renforcé)

- Riftarium est un projet **fan-made, non commercial**, créé en vertu de la politique
  « Jargon juridique » de Riot Games. Riot Games ne soutient ni ne sponsorise ce projet.
- Cartes, illustrations, symboles et textes officiels © Riot Games, Inc.
- La [politique développeur Riftbound](https://developer.riotgames.com/policies/riftbound)
  impose une clé API applicative au-delà de l'usage personnel → **la maquette sert justement
  de dossier de présentation pour cette demande**.
- Cardmarket est une marque de Cardmarket GmbH ; les prix affichés dans la maquette sont fictifs.
- Le code du projet reste sous licence MIT ; la licence ne couvre aucun actif Riot.
