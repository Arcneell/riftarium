# Refonte du site web : « Forge noxienne »

Date : 6 octobre 2026. Périmètre : `riftarium/apps/web` (et l'API si une page
refaite en a besoin). L'application Flutter suivra la nouvelle charte dans un
chantier séparé, plus tard.

## 1. Pourquoi

Le mainteneur ne se reconnaît plus dans le site. Problèmes relevés :

- **Ambiance** : le bleu nuit « hextech » fait générique, pas assez Runeterra.
- **Caractère** : le rendu ressemble à un gabarit, rien ne le distingue.
- **Ergonomie** : on ne trouve pas les choses, navigation confuse, entrées de
  compte cachées derrière un menu, tiroir mobile.
- **Cohérence** : les pages ne se ressemblent pas. Cause technique : aucun
  composant n'a de style propre, tout vit dans `src/assets/main.css`
  (9 243 lignes, ~1 200 sélecteurs globaux), chaque page réinvente ses blocs.

Objectif : un site propre, marqué, stylisé, ancré dans Runeterra / Riftbound,
plaisant et intuitif, bâti sur un design system unique.

## 2. Décisions

| Sujet | Décision |
| --- | --- |
| Univers | Forge noxienne : noir, rouge sang, bronze ; martial et affirmé |
| Palette | Sang & bronze (§3.2) + couleurs officielles des six domaines |
| Typographie | Cinzel (titres, chiffres-clés) ; Barlow Condensed (étiquettes, navigation, boutons) ; Barlow (texte) |
| Habillage | « Forgé » : angles coupés, boutons biseautés, filets de bronze dégradés, liseré rouge sous les titres |
| Navigation | Rail latéral fixe (bureau), barre d'onglets en bas (téléphone), recherche universelle Ctrl K |
| Accueil | Splash cinématique, puis mur de cartes. L'éventail de trois cartes disparaît |
| Effets | Ciblés : seulement aux moments forts |
| Thème | Sombre uniquement |
| Visuels de jeu | Glyphes Riot officiels (énergie, puissance, runes, épuisement) et pastilles officielles de mots-clés, partout, jamais remplacés par du texte |
| Scanner web | Retiré (avance la phase 9 de WORKFLOW.md pour le seul scanner) |
| PWA | Service worker et manifest conservés, rhabillés ; retrait à la publication de l'app |
| Mobile Flutter | Inchangé ; s'alignera plus tard sur cette charte, chantier séparé |
| Méthode | Refonte progressive sur `main`, une PR par bloc de pages |

Directions écartées (pour mémoire) : Parchemin d'Ionia (clair, éditorial),
Faille arcanique (indigo / cyan), Givre du Freljord (clair, outil) ; accueils
« recherche d'abord » et « tableau de bord » ; navigation en barre haute ;
palettes or, acier, braise ; habillages sobre et orné ; big bang et front `/v2`.

## 3. Design system

### 3.1 Organisation du code

```
src/styles/
  tokens.css   couleurs, espacements, rayons, ombres, durées, z-index
  fonts.css    @font-face Cinzel, Barlow, Barlow Condensed (woff2 latin + latin-ext)
  base.css     reset, typographie de base, liens, focus, sélection, scrollbar,
               prefers-reduced-motion
src/ui/        composants de base, chacun avec <style scoped> et son .spec.js
```

- Seuls ces trois fichiers sont globaux. Une vue ne contient que de la mise en
  page (grilles, espacements) dans son propre `<style scoped>`, jamais le style
  d'un bouton, d'un panneau ou d'une puce.
- `main.css` est conservé pendant la transition. En PR 1, ses anciennes
  variables (`--paper`, `--ink`, `--gold`…) sont **redirigées vers les nouveaux
  tokens**, pour que les pages pas encore refaites prennent la palette Forge.
  Chaque PR de page supprime la tranche de `main.css` qu'elle remplace. Après
  la PR 8, `main.css` n'existe plus.
- Polices auto-hébergées comme aujourd'hui (aucune requête vers Google).
  IBM Plex Mono et Marcellus sont retirées ; Cinzel est conservée.

### 3.2 Tokens

Les noms sont neufs et décrivent leur rôle.

| Token | Valeur | Usage |
| --- | --- | --- |
| `--bg` | `#0d0d0f` | fond de page |
| `--bg-raised` | `#17120f` | panneaux, tuiles, modales |
| `--bg-sunken` | `#110e0c` | rail, champs de saisie |
| `--line` | `#2f2721` | séparateurs discrets |
| `--blood` | `#b3262b` | action principale, liseré du rail, onglet actif |
| `--blood-bright` | `#d23a33` | accent textuel sur fond noir |
| `--bronze` | `#8a6e4b` | filets, bordures, boutons secondaires |
| `--bronze-light` | `#d6b98c` | intertitres, prix, focus |
| `--ink` | `#e9e2d8` | texte |
| `--ink-muted` | `#9a8f80` | texte secondaire (contraste ≥ 4,5:1 sur `--bg` et `--bg-raised`, vérifié par test) |

- Domaines : `--fury`, `--calm`, `--mind`, `--body`, `--chaos`, `--order` et
  leurs variantes `*-text`, reprises de l'actuel `main.css`.
- Mots-clés : familles timing `#24705f`, combat `#cc356e`, état `#94b42a`,
  utilitaire `#6c6d6c`, reprises telles quelles.
- Rayons : petits (2 à 4 px). La forme vient des angles coupés, pas de
  l'arrondi. Les illustrations de cartes gardent leur arrondi naturel.
- Durées : `--t-fast 150ms`, `--t-base 200ms`.

### 3.3 Composants `src/ui/`

| Composant | Rôle |
| --- | --- |
| `RiftButton` | variantes `primary` (rouge biseauté), `secondary` (filet bronze), `ghost` ; tailles `sm` / `md` ; rendu `<button>` ou `RouterLink` |
| `RiftPanel` | bloc à angles coupés, filet bronze, intertitre Cinzel suivi d'un filet dégradé (slot `title`) |
| `RiftChip` | puce de domaine, de rareté ou de filtre (supprimable) |
| `RiftField` | champ texte, champ de recherche, sélecteur ; label et erreur intégrés |
| `RiftTabs` | onglets (sous-pages, segments) ; défilants sur téléphone |
| `RiftModal` | modale accessible (focus piégé, Échap, défilement bloqué) ; remplace `ModalDialog` |
| `RiftSheet` | feuille du bas sur téléphone (filtres, menu du compte) |
| `RiftSkeleton` | squelettes de chargement |
| `RiftEmpty` | état vide (titre, phrase, action) |
| `RiftStat` | glyphe officiel + valeur Cinzel + étiquette |
| `CardTile` | vignette de carte : illustration, nom, prix, quantité possédée, reflet foil si rare / showcase |
| `RiftGlyph`, `RiftText` | rendu du texte de jeu à partir de `cardText.js` (glyphes Riot, pastilles de mots-clés, `**gras**`) ; seul rendu de texte de jeu du site, remplace `CardText` et `RuleText`. Une prop `rules` active la conversion des symboles abrégés des règles officielles (`[R]`, `[E]`, `[M]`…, table actuelle de `RuleText.vue`) |

`cardText.js` (parseur, URL des glyphes, familles de mots-clés) est conservé
tel quel : seule sa présentation change.

### 3.4 Effets

Autorisés :

- reflet foil au survol des cartes rares et showcase ;
- entrée du splash d'accueil ;
- défilement lent du mur de cartes ;
- éclat rouge bref à l'ajout d'une carte (collection, deck) ;
- transitions de 150 à 200 ms.

Supprimés : révélations en cascade au défilement, inclinaison 3D (`v-tilt`),
halos et transitions de page.

`prefers-reduced-motion` coupe tous les effets, et le mur de cartes devient
statique.

## 4. Coquille et navigation

### 4.1 Rail latéral (≥ 1 024 px)

Rail fixe d'environ 220 px, bordé à droite d'un liseré `--blood`.

```
RIFTARIUM            (logo → accueil ; badge bêta dessous)
◆ Accueil
◆ Cartes
◆ Decks          › Mes decks · Communauté
◆ Collection     › Collection · Wishlist
◆ Règles         › Apprendre · Plateau animé · Aide avancée · Texte officiel
◆ Jouer          › Salon · Historique · Statistiques
──────────
[avatar] Pseudo  → Profil · Amis · Administration (admin) · Déconnexion
(visiteur : RiftButton « Connexion »)
```

- Seules les sous-pages de la rubrique active sont dépliées.
- Rubrique active : fond dégradé rouge, trait `--blood-bright` à gauche,
  losange plein, `aria-current="page"`.
- Repliable en icônes seules (~64 px). Le choix est mémorisé dans
  `localStorage` (try/catch).
- De 768 à 1 023 px, le rail est replié par défaut.

### 4.2 Barre haute du contenu

Elle contient le fil d'Ariane (par exemple « Cartes › Origins › Ahri ») et le
déclencheur de la recherche universelle, avec son raccourci affiché.

### 4.3 Téléphone (< 768 px)

- **Barre d'onglets en bas**, fixe : Accueil · Cartes · Decks · Collection ·
  Règles. Ce sont les mêmes onglets que l'app Flutter, et Accueil reste dans
  la barre.
- **En haut** : logo, loupe (recherche) et avatar. L'avatar ouvre une
  `RiftSheet` avec Jouer (Salon, Historique, Statistiques), Profil, Amis,
  Wishlist, Administration et Déconnexion.
- Les sous-pages d'une rubrique deviennent des `RiftTabs` défilants en haut de
  la page.
- Le tiroir latéral actuel est supprimé.
- Zone de sécurité iOS respectée (`env(safe-area-inset-bottom)`).

### 4.4 Recherche universelle

- Ouverture : Ctrl K / ⌘ K, `/` hors d'un champ, ou clic sur le déclencheur.
- Une fenêtre centrée (plein écran sur téléphone), avec des résultats groupés :
  - **Cartes** : `GET /api/cards?q=…&size=5` ;
  - **Decks de la communauté** : `GET /api/community/decks?q=…` (5 premiers) ;
  - **Règles et aide** : index local (règles officielles via `rulesStore`,
    sujets de `rules/topics.js`) ;
  - **Pages** : liste statique de destinations (« Ma collection », « Nouveau
    deck », « Wishlist »…).
- Requêtes parallèles, anti-rebond de 200 ms, annulation des requêtes
  périmées (`AbortController`). L'échec d'un groupe n'empêche pas les autres de
  s'afficher.
- Clavier : ↑ ↓ pour naviguer, Entrée pour ouvrir, Échap pour fermer. Le focus
  revient au déclencheur à la fermeture.
- Pas de nouvel endpoint au départ. Un `/api/search` agrégé ne viendra que si
  la latence mesurée le justifie.

### 4.5 Pied de page

Une bande sobre en bas du contenu : mentions Riot obligatoires (`legal.js`),
liens légaux, contact, version. La navigation n'y est plus dupliquée. Le
bandeau prisme est supprimé.

### 4.6 Bandeaux globaux

`EmailVerifyNotice`, l'avis hors ligne et `TraceursNotice` sont conservés,
rhabillés en bandeaux Forgés en haut du contenu.

## 5. Pages : découpage en PR

Chaque PR :

- réécrit ses vues avec `src/ui/` ;
- supprime sa tranche de `main.css` ;
- adapte ses `.spec.js` sans perdre les cas métier couverts.

### PR 1 : socle et coquille (`feat/refonte-socle`)

- `src/styles/`, `src/ui/` (tous les composants du §3.3), redirection des
  anciennes variables de `main.css`.
- `App.vue` réécrit : rail, barre haute, onglets mobiles, `RiftSheet` du
  compte, recherche universelle, pied de page.
- **Retrait du scanner web** : `ScanView.vue`, `useCardScanner.js`,
  `scanOcr.js`, `scanHash.js`, `scanCapture.js` et leurs specs, la route
  `/scan`, les dépendances `tesseract.js`, `tesseract.js-core` et
  `@tesseract.js-data/eng`, le plugin Vite de copie et de service des assets
  `/ocr`, les règles nginx et CSP propres à `/ocr` si elles existent, les liens
  vers `/scan` (accueil, pied de page, sitemap).
  `GET /api/cards/hashes` **reste en place** : l'app mobile l'utilise.
- PWA : `site.webmanifest` (`theme_color` / `background_color` `#0d0d0f`),
  `sw.js` sans les entrées `/ocr`, `sw.spec.js` mis à jour.
- Documentation (§7).

### PR 2 : accueil

- **Splash cinématique** : illustration officielle plein cadre (rotation parmi
  `BANNERS`), fondue dans le noir. Titre Cinzel, deux `RiftButton`, crédit
  Riot. Préchargé pour le LCP.
- **Mur de cartes** : mosaïque inclinée de cartes du dernier set
  (`GET /api/cards`), qui défile lentement dans la pénombre et mène à la
  cartothèque. Images réduites via le CDN (`w=`), chargement différé.
- **Visiteur** : trois blocs Forgés (Decks, Collection, Règles).
- **Connecté** : les mêmes blocs avec ses données (complétion de collection,
  dernier deck modifié, dernier match). Si une donnée manque à l'API, l'endpoint
  est ajouté dans cette PR (§6).

### PR 3 : cartothèque et fiche carte

- **Liste** :
  - filtres dans un panneau latéral repliable (une `RiftSheet` sur
    téléphone) ;
  - puces des filtres actifs au-dessus de la grille ;
  - grille de `CardTile` avec la quantité possédée.

  Synchronisation avec l'URL conservée (`useQuerySyncedFilters`).
- **Fiche** :
  - à gauche, l'illustration, avec **directement dessous, sans vide** : les
    variantes, le prix et les actions collection et wishlist ;
  - à droite, le type et le domaine (glyphe de rune), le nom en Cinzel, les
    `RiftStat` (énergie, puissance, rune), le texte via `RiftText` dans un
    `RiftPanel`, puis les métadonnées (set, numéro, artiste, rareté).

### PR 4 : collection et wishlist

- Résumé chiffré et complétion par set (barres Forgées).
- Classeur actuel (pochettes, cartes manquantes en fantôme) rhabillé ;
  édition des lots dans une `RiftModal`.
- Wishlist avec les mêmes composants.

### PR 5 : decks et communauté

- **Mes decks** : fiches de deck sur l'illustration de la légende.
- **Éditeur** : trois zones (recherche de cartes, liste par zone, stats et
  règles en direct), qui passent en `RiftTabs` sur téléphone. La logique
  existante est conservée (`useDeckRules`, `useDeckStats`, `useDeckAutosave`,
  `deckExport`).
- **Communauté** : filtres par légende et par domaine, pagination.
- **Détail d'un deck** : `DeckView` et `DeckVisual` rhabillés.

### PR 6 : règles

- Hub à trois entrées.
- Guide en chapitres et plateau animé rhabillés.
- Aide avancée.
- Texte officiel : table des matières collante à gauche, recherche en haut.
- `RiftText` partout.

### PR 7 : jeu et social

Salon, historique et statistiques (graphiques `charts/` aux couleurs de la
Forge), profil, profil public (hauts faits), amis. Les contrats
`docs/suivi-des-matchs.md` et `docs/profils-et-hauts-faits.md` restent
inchangés.

### PR 8 : compte et pages annexes

- Connexion et inscription : `RiftPanel` sur le splash.
- Mot de passe oublié et réinitialisation, vérification d'e-mail.
- Pages légales, page 404.
- Administration : une version plus dense et utilitaire, avec les mêmes
  composants.
- **Suppression finale de `main.css`.**

## 6. API

- Aucun changement prévu à ce stade.
- Si une page refaite a besoin d'une donnée absente, l'API évolue **dans la
  même PR** :
  - tests pytest ;
  - `ruff check` / `ruff format --check` ;
  - rétrocompatibilité avec l'app mobile (aucun champ retiré ni renommé) ;
  - mise à jour de WORKFLOW.md §6 si le contrat change.

## 7. Documentation (livrée en PR 1, complétée au fil des PR)

- `apps/web/README.md` : section « Charte Forge noxienne » (tokens,
  composants, règles d'usage : pas de style de composant dans une vue,
  glyphes officiels obligatoires, effets autorisés). C'est la référence du
  futur chantier mobile.
- `WORKFLOW.md` :
  - §3.5 : le scanner web est retiré, le service worker et le manifest restent
    jusqu'à la publication de l'app ;
  - §8 : phase 9 amendée en conséquence ;
  - §7 : note indiquant que `lib/app/design/` devra suivre la charte Forge ;
  - carte du dépôt mise à jour.
- `CLAUDE.md` : le rappel « scanner web, service worker, manifest » devient
  « service worker et manifest ».

## 8. Vérification et validation

### Boucle de chaque PR

1. Une branche `feat/refonte-<bloc>` depuis `origin/main`, sans empilement.
2. Le développement sur la stack dev Docker (HMR sur `http://localhost:8888`).
3. `npm run check` vert (lint, format, vitest, build). Pour une PR qui touche
   l'API : ruff et pytest dans le venv.
4. Contrôle visuel par l'agent dans le navigateur, à 1 440 px, 768 px et
   390 px.
5. **Validation locale par le mainteneur** : l'agent fournit la liste des pages
   et des états à regarder sur `localhost:8888` (visiteur, connecté, vide,
   chargement, erreur). Rien n'est commité pour push ni poussé sans son accord
   explicite.
6. Commit en français (`Web : …`), push, merge par le mainteneur.

### Tests

- Chaque composant de `src/ui/` a son `.spec.js` : rendu des variantes, rôles
  ARIA, focus, Échap (modale, feuille, recherche).
- Recherche universelle : appels mockés ; anti-rebond, annulation,
  regroupement, navigation au clavier, état vide, échec partiel.
- Coquille : rubrique active et `aria-current`, rail replié mémorisé, onglets
  mobiles, menu du compte (visiteur, connecté, admin).
- Test de contraste des tokens de texte (≥ 4,5:1).
- Specs du scanner supprimées avec lui ; `sw.spec.js` et `router.spec.js`
  ajustés.

### Accessibilité et performance

- Focus visible (contour `--bronze-light`), navigation complète au clavier
  dans le rail et les onglets.
- Cibles tactiles d'au moins 44 px, `aria-current` sur la rubrique active.
- Polices woff2 avec `font-display: swap`. Préchargement du splash.
- Le bundle perd tesseract.js (~15 Mo d'assets).

## 9. Hors périmètre

- Application Flutter (chantier séparé, ultérieur).
- Retrait du service worker et du manifest (à la publication de l'app).
- Mode clair.
- Nouvelles fonctionnalités métier qui ne découlent pas de la refonte.
