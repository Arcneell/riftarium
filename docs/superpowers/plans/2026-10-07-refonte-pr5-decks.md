# Refonte Forge noxienne — PR 5 : decks et communauté — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** refaire `/decks` (Mes decks), `/communaute`, `/decks/:id` (lecture d'un deck et éditeur) dans le style Forgé, sans perdre aucune fonction.

**Architecture :** un nouveau dossier `src/decks/` reçoit les pièces des decks, à partir de l'existant.
- `DeckCard` remplace `DeckBox` : une fiche posée sur l'illustration de la légende.
- `DeckLegalBadge` porte la pastille Légal / Illégal.
- `DeckStatsPanel` donne l'analyse du deck (énergie, valeur, courbe, domaines, règles). Il sert à la lecture et à l'éditeur.
- La lecture réutilise `DeckView`, `DeckVisual` et `DeckExportBar`.
- L'éditeur (`DeckEditView.vue`, 865 lignes) est découpé :
  - `DeckGallery` : recherche et galerie de cartes ;
  - `DeckList` : légende, compteurs et liste par zone ;
  - `useDeckDrag` : glisser-déposer ;
  - `DeckEditorBar` : barre d'édition.

  La page compose ces pièces : trois zones sur bureau, et sur téléphone un nouvel onglet en page (`RiftSegments`).
- La logique métier est conservée telle quelle : `useDeckRules`, `useDeckStats`, `useDeckAutosave`, `deckExport`, `deckDisplay`, `useQuerySyncedFilters`, `useGridMeasure`.

**Tech Stack :** Vue 3.5, vue-router 5, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§3.3, §3.4, §4.1, §5 PR 5, §8)

## Global Constraints

- **Branche** : `feat/refonte-decks`, créée depuis `refonte/forge` (cac3d2e). La PR vise `refonte/forge`. Aucun push sans validation du mainteneur en local.
- **Langue** : français pour les commentaires, l'interface et les commits. Identifiants en anglais.
- **Commits** : `Web : …` ou `Docs : …`, terminés par une ligne vide puis `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Vérification** : `npm run check` vert (lint, format:check, test, build) avant chaque commit, depuis `riftarium/apps/web`.
- **Composants disponibles** :
  - `src/ui/` :
    - `RiftButton` (`variant` primary / secondary / ghost, `size` sm / md, `to`, `disabled`, `block`) ;
    - `RiftField` (`label`, `hide-label`, `search`, `type`, `placeholder`, `error`, `v-model`) ;
    - `RiftChip` (`label`, `selected` + `@toggle`, `removable` + `@remove`, `glyph`, `glyph-kind`, `color`) ;
    - `RiftChoice` (radiogroup en puces, `options [{value,label,title?}]`, `v-model`, `label`) ;
    - `RiftStepper` (`value`, `min`, `max`, `busy`, `label`, `size` md / sm, `@increment` / `@decrement`) ;
    - `RiftEmpty` (`title`, `text`, slot d'actions) ;
    - `RiftStat`, `RiftPanel` (`title`, `tag`, `accent`), `RiftSkeleton`, `RiftModal` (`title`, `wide`, `@close`), `RiftSheet` (`title`, `@close`), `RiftText`, `RiftGlyph` ;
    - `CardTile` (racine `rift-tile`, props `card`, `preview`, `hideOwned`, slot `overlay`).
    - `RiftTabs` est lié aux routes : c'est la coquille qui l'utilise pour « Mes decks · Communauté ». Ne pas l'utiliser pour des onglets dans une page.
  - `src/cards/CardFilters.vue` : props `state`, `sets` ; événement `update(key, value)`. Facettes : q, domain, type, rarity, energy, set_id.
  - `src/composables/useBreakpoint.js` : renvoie la ref `"mobile" | "tablet" | "desktop"` (< 768 px, < 1 024 px, au-delà).
  - Tokens : `src/styles/tokens.css`. L'encre rouge des textes est `--blood-text` ; `--blood-bright` est réservé aux grands titres.
- **Leçon des PR précédentes (obligatoire)** : `src/assets/main.css`, hérité et chargé APRÈS `src/styles/*`, fuit sur tout nom de classe qu'il connaît, ainsi que sur `h1`, `h2`, `h3`, `section`, `input`, `select`, `textarea` et `button`.
  - Préfixes de classes réservés à cette PR, absents de `main.css` (vérifié) : `deck-card-`, `legalite-`, `analyse-`, `mesdecks-`, `communaute-`, `lecture-`, `atelier-`, `galerie-`, `decklist-`, `rift-segments`.
  - Interdits, car hérités : `deck-box*`, `deck-legal*`, `dvis*`, `dbuilder*`, `gcard*`, `deck-row*`, `deck-hero*`, `deck-meters`, `meter`, `curve`, `validator`, `zone-*`, `fsel*`, `owned-seg`, `filter-board`, `pager`, `switch`, `price-*`, `chip*`.
  - Vérifier toute nouvelle classe par `grep` dans `main.css`.
  - Neutraliser localement les balises héritées :
    - `h1` : `background: none; color: var(--ink); animation: none; font-weight: 700` ;
    - `h2` et `h3` : marges, taille et couleur explicites ;
    - `section` : `padding: 0` ;
    - `input`, `textarea` : `box-shadow: none` au focus.
  - Le test `src/assets/cssCoverage.spec.js` exige une règle pour toute classe statique d'un gabarit. Il doit rester vert.
- **Titre de page** : `h1` dans la page, comme `CollectionView` (`collection-page-title`). Pas de `PageBanner` sur les pages refaites.
- **Effets** (spec §3.4) :
  - éclat rouge bref (≤ 600 ms) sur la ligne d'une carte ajoutée au deck, à la place de l'éclat doré ;
  - transitions de 150 à 200 ms ;
  - la cascade `v-reveal` et `v-tilt` sont supprimés ;
  - tout est coupé sous `prefers-reduced-motion`.
- **Glyphes officiels** : runes de domaine par `glyphUrl("rune_…")` ou `RiftGlyph`, énergie par le glyphe Riot dans la courbe et les lignes. Pas d'emoji ni de pastille inventée.
- **Accessibilité** : cibles ≥ 44 px (32 px tolérés dans les lignes compactes de la liste du deck sur bureau, 44 px sous `(hover: none)`). `aria-pressed` sur les bascules, `role="status"` sur les messages éphémères, focus visible (contour `--bronze-light`).
- **Comportements conservés** : tous les cas des specs suivantes, migrés vers les nouveaux fichiers sans perte :
  - `DecksView.spec.js`, `DeckEditView.spec.js`, `CommunityView.spec.js` ;
  - `DeckBox.spec.js` (devient `DeckCard.spec.js`) ;
  - `DeckExportBar.spec.js`, `DeckMissingModal.spec.js`, `DeckView.copy.spec.js`, `DeckVisual.spec.js`.

  On adapte les sélecteurs, jamais l'intention d'un cas.
- **Aucun changement d'API.** Endpoints utilisés :
  - decks : `/api/decks/mine`, `/api/decks` (POST), `/api/decks/example`, `/api/decks/{id}` (GET, PUT, DELETE), `/api/decks/{id}/like`, `/view`, `/copy`, `/missing`, `/og.png` ;
  - communauté : `/api/community/decks`, `/api/community/legends` ;
  - autres : `/api/wishlist/from-deck/{id}`, `/api/cards`, `/api/sets`, `/api/play/stats`.

## Review Focus

- **Éditeur sur téléphone** : changer d'onglet (Cartes, Deck, Analyse) ne perd ni la recherche, ni la page de la galerie, ni le défilement de la liste, car les panneaux restent montés (`v-show`). Une carte ajoutée depuis l'onglet Cartes incrémente le badge de l'onglet Deck, et le message de plafond reste visible depuis l'onglet Cartes. Testé en tâche 8.
- **Deck sans légende ou vide** : la fiche, la lecture et l'éditeur ne cassent pas.
  - La fiche affiche un fond neutre « Sans légende ».
  - La lecture affiche « Aucune carte dans ce deck ».
  - Dans l'éditeur, la galerie s'ouvre sur les légendes.
  - Les statistiques à zéro n'affichent ni NaN ni barre de hauteur invalide.

  Testé en tâches 2, 5 et 8.
- **Double clic sur une action réseau** (créer, supprimer, aimer, copier dans mes decks) : une seule requête part, et le bouton est désactivé pendant l'attente. Testé en tâches 3, 4 et 5.
- **Session expirée pendant l'édition** : le brouillon reste affiché et modifiable, avec un message clair. Aucune perte au démontage, car le save de secours part. Testé en tâche 8 (cas existants).
- **Nom de deck long ou sans espace** (80 caractères) : il ne déborde pas de la fiche ni de la barre d'édition (ellipse, `min-width: 0`). Testé en tâches 2 et 7 (classe d'ellipse présente) et vérifié visuellement.

---

### Task 1 : `RiftSegments` (onglets dans une page)

**Files :** Create `src/ui/RiftSegments.vue`, `src/ui/RiftSegments.spec.js`.

**Interfaces :**
- `<RiftSegments v-model="pane" :items="[{ value, label, badge? }]" label="…" id-base="atelier" />`.
- Rendu : un `div role="tablist"` avec `aria-label`, contenant un bouton `role="tab"` par item.
  - `id` : `${idBase}-tab-${value}`.
  - `aria-controls` : `${idBase}-panel-${value}`.
  - `aria-selected`.
  - Tabindex itinérant : 0 sur l'actif, -1 sur les autres.
- Le `badge` (nombre ou texte court) est rendu dans un `span` après le libellé.
- Clavier : ← et → bouclent, Home et End vont aux extrémités. Chaque touche met à jour `v-model` et le focus. Les touches avec Alt, Ctrl ou Méta sont ignorées.
- Le composant ne rend pas les panneaux. La page pose elle-même `id="${idBase}-panel-${value}"`, `role="tabpanel"` et `aria-labelledby` sur ses panneaux.
- Style Forgé : barre pleine largeur, collée sous la barre haute (`position: sticky; top: 0`), fond `--bg-raised`, filet `--line`. L'onglet actif a un trait bas `--blood` de 2 px et l'encre `--ink`. Étiquettes `--font-label` en capitales. Hauteur ≥ 44 px.

- [ ] **Step 1 : tests.** Écrire dans `RiftSegments.spec.js` :
  - « rend un tablist avec aria-selected et aria-controls » ;
  - « clic : émet update:modelValue » ;
  - « flèches, Home et End : déplacent la sélection et le focus, en bouclant » ;
  - « ignore les flèches avec Ctrl » ;
  - « affiche le badge ».
- [ ] **Step 2** : vérifier l'échec (`npx vitest run src/ui/RiftSegments.spec.js`).
- [ ] **Step 3** : écrire le composant.
- [ ] **Step 4** : vérifier le succès et lancer `npm run check`.
- [ ] **Step 5** : commit `Web : composant RiftSegments (onglets dans une page)`.

---

### Task 2 : `DeckLegalBadge` et `DeckCard` (fiche de deck sur l'illustration de la légende)

**Files :**
- Create : `src/decks/DeckLegalBadge.vue`, `src/decks/DeckCard.vue`, `src/decks/DeckCard.spec.js` (migré depuis `src/components/DeckBox.spec.js`).
- Modify : `src/views/PublicProfileView.vue` : remplacer `DeckBox` par `DeckCard readonly`, et la grille `deck-boxes` par une grille `profil-decks-grid` en style scoped de la page (`repeat(auto-fill, minmax(200px, 1fr))`). Modify aussi `src/views/PublicProfileView.spec.js` (le cas qui lit `.deck-box-title` lit `.deck-card-title`).
- Ne pas encore supprimer `DeckBox.vue` : c'est la tâche 9.

**Interfaces :**
- `<DeckLegalBadge :deck />` :
  - utilise `legalState(deck)` de `deckDisplay.js` ;
  - rend un `span.legalite` avec `role="img"`, `aria-label` = `title` = la raison, un glyphe `✓` ou `✕` en `aria-hidden`, et le libellé « Légal » ou « Illégal » ;
  - prop `explain` (booléen) : rend en plus la raison en clair dans un `p.legalite-why` quand le deck est illégal.
  - Style : pastille Barlow Condensed en capitales. Légal : filet `--bronze-light`, encre `--bronze-light`. Illégal : filet `--blood`, encre `--blood-text`.
- `<DeckCard :deck :to :community :readonly :record :like-busy @like @remove />` : mêmes props et événements que `DeckBox`.
- **Gabarit** : un `article.deck-card` au format portrait (rapport 5:7), avec la variable `--cover` posée par `deckIdentity(deck)`. Dans l'ordre :
  1. **Fond** : l'illustration de la légende en `background-image: var(--cover)`, cadrée en haut (`background-position: center 18%`), sous un voile dégradé `--bg` (transparent en haut, opaque sur le dernier tiers). Sans légende, la classe `deck-card--blank` affiche un fond `--bg-sunken` avec un motif de filets bronze et le texte « Sans légende ».
  2. **Lien principal** : un `RouterLink.deck-card-link` couvre toute la fiche (pseudo-élément `::after` en `inset: 0`), avec `aria-label` « Ouvrir le deck {nom} ». Les autres contrôles (like, supprimer, lien de l'auteur) passent au-dessus (`position: relative; z-index: 1`).
  3. **En haut** : `DeckLegalBadge` à gauche, runes de la légende à droite (glyphes de 22 px, `alt` = libellé de la rune).
  4. **En bas, sur le voile** :
     - le nom en `h3.deck-card-title`, Cinzel 700, 18 px, encre `--ink`, ellipse sur une ligne (`min-width: 0`, `overflow: hidden`, `text-overflow: ellipsis`, `white-space: nowrap`), avec `title` = nom ;
     - le nom de la légende en `p.deck-card-legend` (Barlow Condensed, `--bronze-light`), ou « Légende à choisir » ;
     - la raison d'illégalité en clair (`DeckLegalBadge explain`, ou un `p` sous le titre) ;
     - la ligne méta, dans l'ordre : auteur (communauté : `UserAvatar` 18 px et lien vers `profilePath(owner)`), « N cartes », valeur `formatEur(prices.total_eur)` avec `title` = `PRICE_NOTE`, « public » ou « privé » et « en modération » (hors communauté et hors lecture seule), « Complet » ou « N manquante(s) (~coût) » (communauté, quand `missing_cards` est défini) ;
     - le pied :
       - le bilan « {won} V · {lost} D » si `record.played` et hors communauté ;
       - les j'aime : en communauté, un bouton avec `aria-pressed`, un libellé « Aimer ce deck » ou « Ne plus aimer », `disabled` quand `likeBusy`, et `@click.stop.prevent` ; ailleurs, un compteur ;
       - les vues (communauté) ;
       - « Supprimer » (`RiftButton ghost sm`, hors communauté et hors lecture seule), qui émet `remove` avec `@click.stop.prevent`.
- **Liseré** : un filet de 2 px en haut aux couleurs `linear-gradient(90deg, var(--d1), var(--d2))`, angles coupés (clip-path 10 px) et filet `--line`. Au survol ou au focus-within : filet `--bronze` et `translateY(-2px)` en 150 ms, coupé sous `prefers-reduced-motion`.
- `Icon` est global (`heart`, `eye`).

- [ ] **Step 1 : tests.** Migrer les 10 cas de `DeckBox.spec.js` vers `DeckCard.spec.js` en adaptant les sélecteurs. Ajouter :
  - « sans légende : classe deck-card--blank et texte Sans légende » ;
  - « le like ne déclenche pas la navigation (événement stoppé) et est désactivé quand likeBusy » ;
  - « titre long : classe d'ellipse et title complet » ;
  - « bilan V/D affiché seulement hors communauté avec record.played > 0 ».

  Mettre à jour le cas de `PublicProfileView.spec.js` qui lit `.deck-box-title`.
- [ ] **Step 2 à 4** : échec, composants, succès.
- [ ] **Step 5** : commit `Web : fiche de deck Forgée sur l'illustration de la légende`.

---

### Task 3 : page « Mes decks »

**Files :** Modify `src/views/DecksView.vue`, `src/views/DecksView.spec.js`.

**Interfaces :**
- Consomme `DeckCard` (tâche 2) et `usePlayStats()` (inchangé).
- Gabarit dans `div.wrap.cards-wrap.mesdecks` :
  1. En-tête `mesdecks-head` : `h1.mesdecks-title` « Mes decks » (balise neutralisée), compteur « N deck(s) », et `RiftButton primary` « Nouveau deck ».
  2. Pendant le premier chargement : 6 `RiftSkeleton` au format des fiches.
  3. En cas d'erreur : un `p.mesdecks-error` (`role="alert"`, encre `--blood-text`) et un bouton « Réessayer ».
  4. Grille `mesdecks-grid` : `repeat(auto-fill, minmax(220px, 1fr))`, gap `--space-4`. Sous 560 px, deux colonnes (`minmax(150px, 1fr)`).
  5. Aucun deck (sans erreur) : un `RiftEmpty`, titre « Forgez votre premier deck », texte « Partez de zéro ou d'un deck d'exemple, construit avec votre collection ou à compléter. », avec trois actions :
     - « Nouveau deck » (ouvre la modale) ;
     - « Exemple avec ma collection » (`createExample('owned')`) ;
     - « Exemple à compléter » (`createExample('discover')`).
- Modale de création (`RiftModal` « Nouveau deck ») :
  - `RiftField` « Nom du deck » (`maxlength` 80, focus à l'ouverture) ;
  - `RiftChoice` « Format » avec les options `[{value:"tournament", label:"Légal", title:"Règles officielles vérifiées"}, {value:"free", label:"Illégal", title:"Format libre, non officiel"}]` et la description du choix actif sous les puces ;
  - un `textarea.mesdecks-textarea` « Description (optionnel) », `maxlength` 2000, styles hérités neutralisés ;
  - « Rendre ce deck public » : un `RiftChip` à bascule avec `aria-pressed` (pas de checkbox stylée héritée) ;
  - l'erreur, puis les actions « Annuler » (ghost) et « Créer et ouvrir l'éditeur » (primary, désactivé si le nom est vide ou pendant la création) ;
  - un séparateur « ou partez d'un deck d'exemple » et les deux boutons d'exemple (secondary).
  - **Fermeture** : la modale ne se ferme pas pendant une création ou une génération (règle existante).
- Modale de suppression : texte inchangé ; « Supprimer » en `RiftButton primary` (le rouge), désactivé pendant la suppression ; la modale reste ouverte avec l'erreur en cas d'échec.
- Logique conservée telle quelle : `load`, `openCreate`, `createDeck`, `createExample`, `closeCreate`, `askRemove`, `cancelRemove`, `confirmRemove`, avec un état `loading` en plus pour le premier chargement.

- [ ] **Step 1 : tests.** Migrer les 7 cas existants en adaptant les sélecteurs. Ajouter :
  - « aucun deck : RiftEmpty avec Nouveau deck et les deux exemples » ;
  - « double clic sur Créer : un seul POST » ;
  - « échec de chargement : message et Réessayer relance le GET » ;
  - « le format se choisit au clavier dans le radiogroup ».
- [ ] **Step 2 à 4** : échec, page, succès.
- [ ] **Step 5** : commit `Web : page Mes decks Forgée`.

---

### Task 4 : page Communauté

**Files :** Create `src/decks/CommunityFilters.vue`, `src/decks/CommunityFilters.spec.js`. Modify `src/views/CommunityView.vue`, `src/views/CommunityView.spec.js`.

**Interfaces :**
- `<CommunityFilters :state :legends :signed-in @update="(key, value) => …" @liked="…" />`, où `legends = [{ id, name, deck_count }]`. Le composant affiche :
  - un `RiftField search` « Rechercher un deck » (placeholder « Nom, auteur, légende… ») ;
  - un `fieldset` « Trier » : `RiftChoice` sur `SORTS` (Tendance, Plus vus, Récents) ;
  - un `fieldset` « Légendes » : un `RiftField search` local « Filtrer les légendes », puis une puce `RiftChip` par légende (« Nom (N) »), à bascule. Le filtrage est local, insensible à la casse et aux accents (`normalize("NFD")`). Si aucune légende n'est chargée, le fieldset est masqué ;
  - un `fieldset` « Domaines » : `RiftChip` avec glyphe et couleur, comme dans `CardFilters` (`domainFilterOptions()`) ;
  - un `fieldset` « Format » : puces Légal et Illégal (`FORMAT_OPTIONS`) ;
  - un `fieldset` « Mes decks aimés » : une puce « Aimés ». Pour un visiteur, elle émet `liked`, et la page redirige vers la connexion ;
  - « Constructibles avec ma collection » : une puce affichée seulement si `signedIn`.
- **CommunityView** reprend le gabarit de `CardsView` (lire `src/views/CardsView.vue`) :
  - `h1.communaute-title` « Decks de la communauté » ;
  - une barre avec le compteur « N deck(s) » (`aria-live="polite"`), le bouton « Filtres (N) » et « Réinitialiser » quand `activeCount` est non nul ;
  - sur bureau, un panneau latéral `communaute-filters` de 280 px ; sur téléphone et tablette, une `RiftSheet` « Filtres ». Le choix se fait avec `useBreakpoint()`, desktop pour le panneau ;
  - une grille de `DeckCard community` ;
  - une pagination « ← Précédent · page X / Y · Suivant → » (`RiftButton ghost sm`), avec un retour en haut de la grille au changement de page ;
  - squelettes au premier chargement ; `RiftEmpty` « Aucun deck ne correspond » quand c'est vide, avec « Réinitialiser les filtres » si des filtres sont actifs et un lien « Créer un deck » vers `/decks`.
- La logique est conservée : `useQuerySyncedFilters` (mêmes clés et même `communityQuery`), `toggleLiked`, `toggleLike` avec son `Set` de garde, et le retrait de la carte quand on n'aime plus un deck sous le filtre « Aimés ». `FilterSelect` n'est plus utilisé ici.

- [ ] **Step 1 : tests.** Migrer les 8 cas de `CommunityView.spec.js`. Ajouter :
  - dans `CommunityFilters.spec.js` : « filtre local des légendes insensible aux accents », « puce Constructibles absente pour un visiteur », « tri au radiogroup émet update('sort', …) » ;
  - dans `CommunityView.spec.js` : « double clic sur j'aime : un seul POST », « sur téléphone, les filtres s'ouvrent dans une feuille ».

  Pour simuler le téléphone, mocker `matchMedia` comme le fait `CardsView.spec.js`.
- [ ] **Step 2 à 4** : échec, composants, succès.
- [ ] **Step 5** : commit `Web : page Communauté Forgée (filtres légende, domaine, format)`.

---

### Task 5 : lecture d'un deck (`DeckView`, `DeckVisual`, `DeckExportBar`, `DeckStatsPanel`)

**Files :**
- Create : `src/decks/DeckStatsPanel.vue`, `src/decks/DeckStatsPanel.spec.js`.
- Move et rewrite :
  - `src/components/DeckView.vue` vers `src/decks/DeckView.vue` ;
  - `src/components/DeckVisual.vue` vers `src/decks/DeckVisual.vue` ;
  - `src/components/DeckExportBar.vue` vers `src/decks/DeckExportBar.vue`.

  Utiliser `git mv` pour garder l'historique, avec leurs specs (`DeckView.copy.spec.js`, `DeckVisual.spec.js`, `DeckExportBar.spec.js`). Mettre à jour les imports dans `DeckEditView.vue`.

**Interfaces :**
- `<DeckStatsPanel :cards="deck.cards" :checks="deck.checks" :prices="deck.prices" />` :
  - Utilise `useDeckStats(() => cards)`, qui renvoie `curve`, `curveLabel`, `energyTotal` et `domainSpread`.
  - Rend un `RiftPanel` titré « Analyse ». Son contenu, dans l'ordre :
    1. `RiftStat` « Énergie » avec le glyphe d'énergie Riot `glyphUrl("energy_1")` (jetons `energy_0` à `energy_7` dans `cardText.js`) et la valeur `energyTotal`.
    2. `RiftStat` « Valeur », si `formatEur(prices?.total_eur)` est défini, avec `title` = `PRICE_NOTE`.
    3. La courbe `analyse-curve` (`role="group"`, `aria-label` inchangé) : 8 barres de coût 0 à 7+. Chaque barre a sa hauteur en %, remplie d'un dégradé `--blood` vers `--bronze`, un texte `sr-only` « N carte(s) à C d'énergie » et l'étiquette de coût. Si toutes les barres sont à 0, la hauteur vaut 0 % (jamais NaN).
    4. `curveLabel` en `aria-hidden`.
    5. La répartition par domaine : un `RiftChip` par domaine, avec glyphe de rune, couleur du domaine et libellé « Domaine · N ».
    6. Les règles : `ul.analyse-checks`, un `li` par check, avec `✓` (`--bronze-light`) ou `✕` (`--blood-text`) en `aria-hidden` et un texte visible. Classe `ok` ou `ko`.
  - Slot `actions` après les règles (l'éditeur y met « Trouver les cartes manquantes »).
- **`DeckView`** (lecture). Les props et l'événement `like`, ainsi que la logique de copie, sont conservés.
  1. **Bandeau de tête `lecture-hero`.** L'illustration de la légende est en fond (`deckIdentity`), sous un voile `--bg`. On y trouve :
     - le lien « ← Communauté » ;
     - le `h1.lecture-title` (nom, balise neutralisée, ellipse sur deux lignes) ;
     - `DeckLegalBadge explain` ;
     - l'auteur, avec avatar et lien vers son profil ;
     - les runes ;
     - j'aime (bouton si le deck est public et publié, désactivé pendant la requête si une prop `likeBusy` est passée ; ajouter `likeBusy` en prop) et les vues ;
     - « Copier dans mes decks » (`RiftButton secondary`, désactivé pendant la copie, avec le `title` existant) ;
     - l'erreur de copie.
  2. **Compteurs de zones `lecture-meters`.** Quatre `RiftStat` (Légende 1, Champs de bataille 3, Runes 12, Deck principal 40+), avec l'état « complet » quand la cible est atteinte (encre `--bronze-light`).
  3. **Mise en page `lecture-layout`.**
     - À gauche, `DeckVisual`.
     - À droite (320 px, sous la liste en dessous de 1 024 px) :
       - `DeckStatsPanel` ;
       - la description (`p.lecture-desc`, `white-space: pre-line`) ;
       - un `RiftPanel` « Exporter » contenant `DeckExportBar`.
- **`DeckVisual`.** Zones regroupées comme aujourd'hui : identité (légende, champs de bataille, runes), puis deck principal.
  - Titre de zone en `h2.decklist-zone-title`, Cinzel 15 px, avec le compteur en `--ink-muted`.
  - Grille de vignettes (`repeat(auto-fill, minmax(110px, 1fr))`, 150 px pour les champs de bataille en paysage).
  - Badge « ×N » en Cinzel sur fond `--bg` à 85 %.
  - Champion : filet `--blood` de 2 px avec l'étiquette « Champion ».
  - Le lien vers la fiche et `CardHoverPreview` sont conservés.
  - Classes `lecture-zone*` et `lecture-card*`.
- **`DeckExportBar`.**
  - Boutons `RiftButton` : « Liste Rift Atlas » (primary sm), « Code de deck », « Liste texte » et « Lien de partage » (secondary sm).
  - Note `role="status"`.
  - Logique inchangée.
  - Classes `lecture-export*`.

- [ ] **Step 1 : tests.**
  - Migrer les cas de `DeckView.copy.spec.js`, `DeckVisual.spec.js` et `DeckExportBar.spec.js`.
  - Ajouter dans `DeckStatsPanel.spec.js` :
    - « courbe : barres et sr-only, hauteur 0 % quand le deck est vide » ;
    - « règles ✓/✕ avec texte » ;
    - « valeur absente sans prix » ;
    - « slot actions rendu ».
  - Ajouter dans `DeckView.copy.spec.js` : « double clic sur Copier : un seul POST ».
- [ ] **Step 2 à 4** : échec, composants, succès.
- [ ] **Step 5** : commit `Web : lecture d'un deck Forgée (bandeau, analyse, export)`.

---

### Task 6 : éditeur — galerie de cartes (`DeckGallery`)

**Files :** Create `src/decks/DeckGallery.vue`, `src/decks/DeckGallery.spec.js`.

**Interfaces :**
- `<DeckGallery :gallery :result :loading :active-count :page-count :sets :in-deck-qty :off-domain :tournament :shakes @update="(key, value)" @reset @add="card" @tile-pointerdown="(card, event)" @preview="(card, event)" @hide-preview />`.
  - `gallery` est l'état réactif de `useQuerySyncedFilters`, qui reste dans la page (tâche 8).
  - `inDeckQty` et `offDomain` sont des fonctions venues de `useDeckRules`.
  - `shakes` est un `Set` réactif.
  - Le composant expose `grid` (ref de la grille) avec `defineExpose`, pour `useGridMeasure` dans la page.
- **Gabarit `galerie`** :
  1. **Barre de recherche** : `RiftField search` « Rechercher une carte » (placeholder « Jinx, ogn-202, reaction… »), avec à côté :
     - le bouton « Filtres (N) », qui ouvre les facettes ;
     - la possession, membres seulement : `RiftChoice` Toutes / Possédées / Manquantes (valeurs `""`, `"1"`, `"0"`) ;
     - « Réinitialiser ».
  2. **Facettes** : `CardFilters` réutilisé tel quel (`:state="gallery"` et `:sets`, en relayant `update`).
     - Bureau : dans un volet repliable `galerie-facets` sous la barre, fermé par défaut, avec un bouton `aria-expanded`.
     - Téléphone et tablette : dans une `RiftSheet` « Filtres ».
     - Le champ de recherche de `CardFilters` fait doublon avec la barre : passer une prop `hide-search` à `CardFilters`. Il faut donc modifier `src/cards/CardFilters.vue` (prop booléenne, `v-if` sur le `RiftField`) et ajouter un cas à `CardFilters.spec.js`.
  3. **Compteur** : « N carte(s) », suivi de « — chargement… » pendant le chargement (`aria-live="polite"`).
  4. **Grille `galerie-grid`** avec `--tile-min`. Chaque case `galerie-slot` contient :
     - un `button.galerie-card`, avec `aria-label` « Ajouter {nom} au deck », qui contient :
       - l'image `cardThumb(image_url, 320)` ;
       - la pastille « ×N possédée » (membres, si `owned_qty > 0`) ;
       - la pastille « N » dans le deck (Cinzel, fond `--blood`) ;
       - le prix ;
       - un « + » en survol.
     - États par classe :
       - `unowned` : grisée à 45 % (`filter: grayscale(.8)`) mais cliquable ;
       - `indeck` : filet `--bronze-light` ;
       - `offdomain` : en tournoi hors domaine, opacité 0,35 avec un motif hachuré ;
       - `landscape` ;
       - `shake` : secousse de 300 ms, coupée sous reduced-motion.
     - Un `RouterLink.galerie-info` « ℹ », `aria-label` « Voir la fiche de {nom} », visible seulement sous `(hover: none)`, avec `@pointerdown.stop`.
     - Événements :
       - `@click` émet `add` ;
       - `@pointerdown` émet `tile-pointerdown` ;
       - `mouseenter` et `focusin` émettent `preview` ;
       - `mouseleave` et `focusout` émettent `hide-preview`.
  5. **Vide** : `RiftEmpty` « Aucune carte ne correspond aux filtres », avec « Réinitialiser » si des filtres sont actifs.
  6. **Pagination** : `RiftButton ghost sm`.

- [ ] **Step 1 : tests.** Migrer depuis `DeckEditView.spec.js` vers `DeckGallery.spec.js` les cas « galerie : possédées en couleur, manquantes grisées mais ajoutables » et « tactile : le bouton ℹ ouvre la fiche sans ajouter ». Pour ce second cas, garder aussi une version d'intégration dans `DeckEditView.spec.js` à la tâche 8. Ajouter :
  - « clic : émet add avec la carte » ;
  - « hors domaine en tournoi : classe offdomain » ;
  - « facettes en feuille sur téléphone » ;
  - « possession : RiftChoice émet update('owned', '1') ».
- [ ] **Step 2 à 4** : échec, composant, succès.
- [ ] **Step 5** : commit `Web : galerie Forgée de l'éditeur de deck`.

---

### Task 7 : éditeur — liste du deck et glisser-déposer (`DeckList`, `useDeckDrag`, `DeckEditorBar`)

**Files :** Create :
- `src/decks/useDeckDrag.js` et `src/decks/useDeckDrag.spec.js` ;
- `src/decks/DeckList.vue` et `src/decks/DeckList.spec.js` ;
- `src/decks/DeckEditorBar.vue` et `src/decks/DeckEditorBar.spec.js`.

**Interfaces :**
- `useDeckDrag({ enabled: () => boolean, finePointer: boolean, reducedMotion: boolean, panel: Ref<HTMLElement>, onDropAdd: (card) => boolean, onDropRemove: (cardId) => void, onStart: () => void })` renvoie `{ drag, onTilePointerDown(card, from, event), suppressClick: () => boolean, dispose() }`.
  - `drag` est un objet `reactive`.
  - La logique est déplacée sans changement depuis `DeckEditView.vue` : `onTilePointerDown`, `onDragMove`, `onDragEnd`, `flyGhostToRow` (seuil de 8 px, souris seulement, `.row-actions` exclu). Ce sélecteur devient `.decklist-actions`.
  - `dispose()` retire les écouteurs `pointermove` et `pointerup` de `window`, ainsi que la classe `drag-active` du body. La page l'appelle dans `onBeforeUnmount`.
  - Le fantôme vise une ligne `[data-row="id"]` sous `panel`.
- `<DeckList :deck :can-edit :zones :list-zones :grouped :zone-counts :legend-entry :legend-runes :flashes :limit-message :missing-in-deck :drag :fine-pointer :signed-in @set-qty="(entry, delta)" @remove-one="cardId" @show-legends @row-pointerdown="(card, event)" @preview="(card, event)" @hide-preview />`. Le composant expose `panel` (sa racine), qui sert de zone de dépôt. Son gabarit, `decklist` :
  1. **Indication de dépôt pendant un glisser.** Quand on glisse depuis la galerie, un voile « Déposez ici » apparaît (`aria-hidden`), avec la classe `hot` au survol.
  2. **Vitrine de la légende `decklist-hero`.**
     - Avec légende : l'illustration en fond, l'étiquette « Légende », le nom en Cinzel, les runes, et un bouton ✕ « Retirer la légende du deck » si `canEdit`.
     - Sans légende : « 1. Choisissez votre légende : elle fixe les deux domaines du deck. » et le bouton « Voir les légendes », qui émet `show-legends`. En lecture seule : « Ce deck n'a pas encore de légende ».
  3. **Compteurs `decklist-meters`.** Quatre jauges compactes « n/cible » (avec « + » pour le deck principal), une barre de remplissage `--blood` et la classe `full` quand la cible est atteinte.
  4. **Message.** `limitMessage` en `role="status"` (encre `--blood-text`). Sinon, s'il manque des cartes au deck, « N carte(s) du deck manquent à votre collection. » (`--ink-muted`).
  5. **Zones.** Pour chaque zone de `listZones` :
     - un `h3.decklist-zone` avec le libellé et le compteur ;
     - un `TransitionGroup` (`name="decklist-row"`, 180 ms, coupé sous reduced-motion) de lignes `decklist-row`, chacune avec `data-row`, un fond d'illustration voilé, et les classes `flash` (éclat rouge 600 ms : `box-shadow` intérieur `--blood` qui s'éteint) et `lacking`.

     Contenu d'une ligne :
     - le coût en losange bronze ;
     - le nom, avec ellipse ;
     - « manque N » (`--blood-text`) ;
     - « ×N » ;
     - si `canEdit`, `span.decklist-actions` avec deux boutons « − » et « + », dont les `aria-label` sont inchangés. Ils font 32 px, et 44 px sous `(hover: none)`.

     Une zone vide affiche le texte existant, selon `canEdit` et `finePointer`.
- `<DeckEditorBar :deck :can-edit :save-state :error :like-busy @like @export @update:name @update:format @update:public />`. Le composant ne modifie pas `deck` lui-même : la page applique les changements. Son gabarit, `atelier-bar`, sur une ligne qui se replie :
  - « ← Mes decks » ;
  - le nom : un `input.atelier-name`, `aria-label` « Nom du deck », `maxlength` 80, Cinzel 20 px, sans bordure, avec un filet bas `--line` qui passe à `--bronze-light` au focus, et `min-width: 0` ;
  - le format : `RiftChoice` Légal / Illégal ;
  - « Public » : un `RiftChip` à bascule avec `aria-pressed` ;
  - les j'aime (bouton si le deck est public et publié) et les vues ;
  - « Exporter » (`RiftButton ghost sm`) ;
  - l'état de sauvegarde `atelier-save` (`saving` : « Enregistrement… » ; `saved` : « Enregistré » ; `error` : « Erreur de sauvegarde » en `--blood-text`), en `role="status"`. Sous 1 100 px, il devient un toast fixe au-dessus des onglets du bas, masqué quand il est vide (classe `idle`) ;
  - l'erreur.

  Il faut aussi la bannière de modération « En attente de modération : ce deck n'est pas visible publiquement. ». Elle est rendue par la page à la tâche 8, pas par la barre.

- [ ] **Step 1 : tests.**
  - `useDeckDrag.spec.js` :
    - « un déplacement de moins de 8 px n'active pas le glisser » ;
    - « déposer sur le panneau appelle onDropAdd » ;
    - « relâcher hors du panneau depuis le deck appelle onDropRemove » ;
    - « toucher (pointerType touch) n'active rien » ;
    - « dispose retire les écouteurs ».
  - `DeckList.spec.js` :
    - « vitrine de légende avec runes et bouton retirer » ;
    - « sans légende : bouton Voir les légendes émet show-legends » ;
    - « − et + émettent set-qty » ;
    - « ligne flash et lacking » ;
    - « zone vide : texte tactile ou souris ».
  - `DeckEditorBar.spec.js` :
    - « format : RiftChoice émet update:format » ;
    - « Public : aria-pressed et update:public » ;
    - « état de sauvegarde annoncé » ;
    - « nom long : input avec min-width 0 (classe) ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : liste du deck, glisser-déposer et barre d'édition Forgés`.

---

### Task 8 : éditeur — composition, onglets sur téléphone, cartes manquantes

**Files :**
- Modify : `src/views/DeckEditView.vue`, `src/views/DeckEditView.spec.js`.
- Move et rewrite : `src/components/DeckMissingModal.vue` devient `src/decks/DeckMissingModal.vue`, avec sa spec (`git mv`).

**Interfaces :**
- **La page garde** :
  - le chargement avec `loadSeq` ;
  - l'autosave (`useDeckAutosave`, monté en premier pour que le save de secours parte avant les autres démontages) ;
  - `useDeckRules` ;
  - `useQuerySyncedFilters` (galerie, `syncUrl: false`) et `useGridMeasure` ;
  - l'aperçu au survol (`preview` téléporté dans le body : classes `atelier-preview*`, contenu inchangé) ;
  - le fantôme de glisser (téléporté : classes `atelier-ghost*`) ;
  - like, vue comptée, SEO et cartes manquantes.
- **Elle compose** : `DeckView` (lecture, `v-if="deck && !canEdit"`), ou bien `DeckEditorBar`, la bannière de modération, puis trois panneaux :
  - `atelier-pane--cards` : `DeckGallery` ;
  - `atelier-pane--deck` : `DeckList` ;
  - `atelier-pane--stats` : `DeckStatsPanel`, avec dans le slot `actions` « Trouver les cartes manquantes » (`RiftButton primary sm`), suivi du `textarea.atelier-desc` « Description du deck », styles hérités neutralisés.
- **Mise en page** (classe `atelier`) :
  - **≥ 1 280 px** : trois colonnes `minmax(0, 1fr) 340px 300px`. La liste et l'analyse sont collantes (`position: sticky; top: var(--space-4)`), avec un défilement interne limité à la hauteur de la fenêtre.
  - **De 768 à 1 279 px** : deux colonnes `minmax(0, 1fr) 340px`. L'analyse passe sous la liste, dans la colonne de droite.
  - **< 768 px** (`useBreakpoint() === "mobile"`) : `RiftSegments`, avec `id-base="atelier"` et les items suivants :
    - `cards` « Cartes » ;
    - `deck` « Deck », avec en badge le nombre total de cartes (somme des quantités) ;
    - `stats` « Analyse », avec en badge « ✕ » si une règle échoue.

    Chaque panneau porte `role="tabpanel"`, `id="atelier-panel-…"` et `aria-labelledby="atelier-tab-…"`, et se masque avec `v-show` (les panneaux restent montés). L'onglet par défaut est `deck` si le deck a une légende, sinon `cards`. Le message de plafond (`limitMessage`) apparaît aussi, en toast fixe, au-dessus des onglets du bas quand l'onglet actif n'est pas `deck`.
  - Hors téléphone, les attributs `role` et `id` de panneau ne sont pas posés.
- **Les ajouts restent ceux de `useDeckRules`.** Le clic d'une tuile passe par `addCard`, sauf si `suppressClick()` est vrai. Le dépôt passe par `addCard` puis `flyGhostToRow`. « Voir les légendes » appelle `setFilter('type', ['Legend'])`, et passe à l'onglet `cards` sur téléphone.
- **`DeckMissingModal`.** Les props, les événements et la logique (copie, wishlist, minuteries) sont conservés.
  - Rendu dans une `RiftModal wide` « Cartes manquantes ».
  - Liste `atelier-missing-list` : vignette, nom, « ×N manquante(s) », prix unitaire ; le survol émet `preview`.
  - Ligne « Coût pour compléter : … » (`PRICE_NOTE`).
  - Actions : « Copier la liste » (secondary), puis « Ajouter les manquantes à ma wishlist » (primary, membres seulement, si `deckId`).
  - Chargement : `RiftSkeleton`. Erreur : `role="alert"`.
  - La classe héritée `wish-from-deck` n'est plus utilisée.
- **`FilterSelect`** n'est plus importé dans cette page.

- [ ] **Step 1 : tests.**
  - Migrer les 15 cas de `DeckEditView.spec.js`. Le cas « format : sélecteur au style des filtres » devient « format : RiftChoice bascule légal / illégal ».
  - Migrer les cas de `DeckMissingModal.spec.js`.
  - Ajouter :
    - « téléphone : trois onglets, panneaux montés, ajout depuis Cartes met à jour le badge Deck » ;
    - « téléphone : onglet par défaut Deck avec légende, Cartes sans légende » ;
    - « téléphone : Voir les légendes bascule sur Cartes et filtre les légendes » ;
    - « bureau : pas de tablist, trois panneaux visibles » ;
    - « démontage pendant un glisser : écouteurs retirés » (via `useDeckDrag.dispose`) ;
    - « deck vide : analyse sans NaN ».
- [ ] **Step 2 à 4** : échec, page, succès.
- [ ] **Step 5** : commit `Web : éditeur de deck Forgé (trois zones, onglets sur téléphone, cartes manquantes)`.

---

### Task 9 : nettoyage et documentation

**Files :**
- Delete : `src/components/DeckBox.vue` et sa spec, si plus rien ne les importe.
- Delete : `src/components/FilterSelect.vue` et sa spec, si plus rien ne l'importe (vérifier par `grep -rn FilterSelect src`). Sinon, le garder et le noter.
- Modify : `src/assets/main.css`, `src/assets/cssCoverage.spec.js` (liste d'exceptions, si besoin), `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md`, `riftarium/apps/web/README.md` (liste des dossiers, si `src/decks/` doit y figurer).

**Étapes :**
- [ ] **Step 1 : retirer de `main.css` les tranches des decks devenues inutiles.** Repères de section actuels :
  - « Deck builder visuel » et « Courbe d'énergie » (vers les lignes 824 à 907) ;
  - « Deck builder v2 : table de jeu » jusqu'à « Hors des domaines » (vers 3230 à 4013) ;
  - « Fiches de deck » et « Page dédiée : lecture d'un deck » (vers 4014 à 4512) ;
  - les blocs prix des decks (vers 5245, 5255 et 5272) ;
  - « Tri en mode choix unique » (`fsel-single`, vers 5287), seulement si `FilterSelect` est supprimé ;
  - « Decks communauté : constructible » (vers 5355) ;
  - « Éditeur de deck (≤1100) » et ses paliers responsive (vers 5430 à 5748) ;
  - les règles `fsel*`, `owned-seg` et `filter-board`, si plus aucun gabarit ne les utilise.

  **Règle de sûreté (leçon de la PR 4)** : avant de supprimer un sélecteur, chercher chacune de ses classes dans `src` hors `main.css` (`grep -rn "nom-de-classe" src --include=*.vue --include=*.js`). Une classe encore utilisée ailleurs (`curve`, `validator`, `chip-rune`, `price-tag`, `price-amount`, `deck-legal`, `mono`, `muted`, etc.) garde sa règle. Lister dans le rapport les sélecteurs gardés et la raison. Vérifier que `cssCoverage.spec.js` reste vert.
- [ ] **Step 2 : retirer `v-reveal`.** Supprimer les usages de `v-reveal` et `v-tilt` restants dans les fichiers des decks (normalement aucun après les tâches 2 à 8).
- [ ] **Step 3 : mettre à jour la spec.**
  - Au §3.3 : ajouter `RiftSegments` (« onglets dans une page, `role="tablist"`, panneaux posés par la page ; livré en PR 5 ») et préciser que `RiftTabs` est réservé aux sous-pages.
  - Au §5 PR 5 : ajouter une puce « **Livré** » qui décrit :
    - le dossier `src/decks/` et ses pièces ;
    - les préfixes de classes ;
    - les trois colonnes, puis deux, puis les onglets ;
    - l'éclat rouge ;
    - la suppression de `DeckBox` et `FilterSelect` (ou la raison de garder ce dernier) ;
    - `CardFilters` et sa prop `hide-search`.
- [ ] **Step 4 : vérifier.** Lancer `npm run check` (vert), puis vérifier par `grep` qu'aucun gabarit n'utilise une classe dont la règle a été supprimée.
- [ ] **Step 5 : commits.** `Web : nettoyage des styles hérités des decks`, puis `Docs : spec — PR 5 decks et communauté livrée`.

---

## Validation locale (après la revue finale, avant tout push)

À montrer au mainteneur sur `http://localhost:8888` :

1. **`/decks` connecté** :
   - avec decks : fiches sur l'illustration, pastilles Légal / Illégal, bilan V/D ;
   - sans deck : état vide et exemples ;
   - création : modale, format en puces, bascule Public ;
   - suppression confirmée.
2. **`/communaute`** :
   - visiteur : j'aime redirige vers la connexion, pas de puce Constructibles ;
   - connecté : Complet / manquantes, j'aime, filtres légende (recherche), domaine, format, Aimés, Constructibles, tri, pagination ;
   - téléphone : filtres en feuille.
3. **`/decks/:id` d'un autre joueur** : bandeau, analyse, export, copie dans mes decks.
4. **`/decks/:id` à soi** :
   - bureau : trois zones, glisser-déposer, éclat rouge, plafond, hors domaine, cartes manquantes, autosave ;
   - tablette (900 px) : deux colonnes ;
   - téléphone (390 px) : onglets Cartes, Deck et Analyse.
5. **Profil public** d'un joueur avec decks : fiches en lecture seule.
