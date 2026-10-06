# Refonte Forge noxienne — PR 4 : collection et wishlist — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** refaire `/collection` (classeur et inventaire) et `/wishlist` dans le style Forgé, sans perdre aucune fonction.
- **Classeur** : onglets de sets avec progression, pochettes 3 × 3 sur deux pages, cartes manquantes en fantôme, filtre Tout / Possédées / Manquantes, tournage de page à la souris et au clavier.
- **Inventaire** : filtres, tri par prix, sélection et opérations de masse, export CSV, retrait confirmé.
- **Wishlist** : stepper de quantité et retrait.

**Architecture :** `CollectionView.vue` (729 lignes) est découpé.
- `src/collection/useCollectionBinder.js` : toute la logique du classeur (état, chargement anti-course, navigation, clavier), testable sans gabarit.
- `src/collection/CollectionBinder.vue` : l'affichage du classeur.
- `src/collection/CollectionInventory.vue` : l'inventaire. Il reçoit l'instance `useQuerySyncedFilters` de la page, qui possède aussi le paramètre d'URL `vue`.
- `src/collection/CollectionStats.vue` : la rangée de statistiques. Elle sert aussi à la wishlist.
- `CollectionView.vue` compose ces pièces ; `WishlistView.vue` est réécrite.

**Tech Stack :** Vue 3.5, vue-router 5, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§3.3, §3.4, §5 PR 4)

## Global Constraints

- **Branche** : `feat/refonte-collection` depuis `origin/refonte/forge`. La PR vise `refonte/forge`. Aucun push sans validation du mainteneur.
- **Langue** : français pour les commentaires, l'interface et les commits. Identifiants en anglais.
- **Commits** : `Web : …`, terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Vérification** : `npm run check` vert avant tout push.
- **Tokens et composants disponibles** :
  - tokens : voir `src/styles/tokens.css` ;
  - `src/ui/` : `RiftButton`, `RiftField`, `RiftChip` (`selected` et `@toggle`, ou `removable` et `@remove`), `RiftEmpty`, `RiftStat` (`label`, `value`, `glyph`, `glyph-alt`), `RiftPanel`, `RiftSkeleton`, `RiftModal`, `RiftSheet`, `RiftTabs`, `CardTile` (racine `rift-tile`, props `card` et `preview`) ;
  - `src/cards/` : `CardFilters` et `ActiveFilters` (props `state` et `sets`, événements `update(key, value)` et `reset`).
- **Leçon des PR précédentes (obligatoire)** : les règles globales héritées de `src/assets/main.css` (chargé après `src/styles/*`) fuient sur tout nom de classe qu'elles connaissent, ainsi que sur `h1`, `h2`, `h3`, `section`, `input`, `select` et `button`.
  - Chaque nouveau composant utilise des classes absentes de `main.css` : préfixes `binder-`, `inv-`, `wish-` interdits. Prendre `classeur-…`, `inventaire-…`, `souhait-…`, et vérifier par grep avant de choisir.
  - Neutraliser localement les règles de balises héritées : sur un `h1`, `background: none`, `color: var(--ink)`, `animation: none`, `font-weight: 700` ; sur les `h2` / `h3`, poser explicitement marges, taille et couleur ; sur les `input` / `select`, poser `box-shadow: none` au focus.
- **Effets** (spec §3.4) : le tournage de page du classeur est conservé, raccourci à 200 ms au plus, en fondu-glissé. La cascade d'apparition des pochettes est supprimée. Tout est coupé sous `prefers-reduced-motion`.
- **Comportements conservés** : tous les cas de `CollectionView.spec.js` et `WishlistView.spec.js`, migrés vers les nouveaux fichiers sans perte. Seul le cas « cascade des pochettes : à l'ouverture d'un set, pas au tournage de page » est retiré, puisque la cascade disparaît.
- **Classe partagée** : `wish-from-deck` (DeckMissingModal) reste dans `main.css`.
- **Aucun changement d'API.**

## Review Focus

- **Collection vide** (membre sans carte) : le classeur n'affiche pas une double page de fantômes sans explication, mais un `RiftEmpty` qui invite à parcourir les cartes. L'inventaire montre son état vide. Testé en tâches 2 et 3.
- **Flèches du clavier dans un champ** (recherche de l'inventaire, select des opérations de masse) ou **modale ouverte** : la page du classeur ne tourne pas. Testé en tâche 1.
- **Mode sélection** : cocher une vignette ne navigue pas vers la fiche, que ce soit au clavier (Entrée, Espace) ou à la souris. L'état coché est annoncé (`aria-pressed` ou case à cocher). Testé en tâche 3.
- **Opération de masse en échec** : l'erreur s'affiche, la sélection est conservée, et le bouton se réactive. Testé en tâche 3.
- **Wishlist pendant une requête** : tous les steppers sont désactivés, et une saisie invalide revient à la valeur bornée (de 1 à 99). Testé en tâche 5.

---

### Task 1 : `useCollectionBinder` (logique du classeur)

**Files :** Create `src/collection/useCollectionBinder.js`, `src/collection/useCollectionBinder.spec.js`.

**Interfaces :**
- `useCollectionBinder({ active: () => boolean, isBlocked: () => boolean })` renvoie :
  - l'état : `{ binderSet, binderPage, binderOwned, binderLoading, binderError, spread, turnDir }` (refs) ;
  - les dérivés : `leftCards`, `rightCards` (9 cases chacune, complétées par `null`) ;
  - les actions : `selectSet(id)`, `setGhostFilter(value)`, `turnPage(delta)`, `loadBinder()`, `onKeydown(event)`.
- Le chargement passe par `GET /api/cards?set_id=…&page=…&size=18[&owned=0|1]` avec une garde de séquence. `spread` n'est remplacé qu'à l'arrivée de la réponse et vaut `{ key, items, page, pages, total }`.
- Un `watch` sur `[binderSet, binderPage, binderOwned]` déclenche le chargement si `active()`.
- `onKeydown` ignore l'événement dans les cas suivants : classeur inactif, aucune double page, `isBlocked()` (une modale est ouverte), `defaultPrevented`, Alt / Ctrl / Méta, ou cible éditable (`INPUT`, `TEXTAREA`, `SELECT`, contenteditable). Sinon, il traite ← et →.
- `GHOST_FILTERS` est exporté.
- **Le composable n'enregistre aucun écouteur global** : c'est le composant qui l'enregistre et le retire.
- **Reprise de l'existant** : la logique vient de `CollectionView.vue` (`loadBinder`, `selectSet`, `setGhostFilter`, `turnPage`, `onBinderKeydown`, `padPage`). La déplacer en adaptant les noms, sans changer le comportement. Le champ `deal` (cascade) disparaît.

- [ ] **Step 1 : écrire les tests** : migrer depuis `CollectionView.spec.js` les cas « chips du classeur : Manquantes filtre sur owned=0 », « tourner la page : demande la double page suivante », « flèches du clavier : feuillettent le classeur » et « clic sur un onglet de set : ouvre ce set à la première page ». Les écrire contre le composable, monté dans un petit composant hôte avec `vi.mock("../api.js")`.

  Ajouter :
  - « flèches ignorées dans un champ, avec un modificateur ou quand isBlocked() » ;
  - « une réponse tardive d'un set précédent est ignorée » ;
  - « tourner au-delà de la dernière page ne fait rien ».
- [ ] **Step 2** : vérifier l'échec. **Step 3** : écrire le composable. **Step 4** : vérifier le succès. **Step 5** : commit `Web : logique du classeur extraite (useCollectionBinder)`.

---

### Task 2 : `CollectionBinder` (classeur Forgé)

**Files :** Create `src/collection/CollectionBinder.vue`, `src/collection/CollectionBinder.spec.js`.

**Interfaces :**
- `<CollectionBinder :progress :active />`. `progress` vaut `{ sets: [{ set_id, name, owned, total, missing, missing_cost_eur }], overall }` ou `null` ; `active` est un booléen.
- Le composant utilise `useCollectionBinder`. Il enregistre `keydown` sur `window` au montage et le retire au démontage. Il ouvre par défaut le premier set incomplet (sinon le premier) quand `progress` arrive.
- **Gabarit** :
  1. Onglets de sets (`role="tablist"`), un bouton `role="tab"` par set avec :
     - le nom ;
     - « ✓ » si le set est complet, sinon le pourcentage ;
     - une barre de progression (largeur = pourcentage) ;
     - `aria-selected`.
  2. En-tête : nom du set en `h2` (Cinzel, styles hérités neutralisés), la ligne « possédées / total · % — il manque N carte(s) (~coût) », et les filtres Tout / Possédées / Manquantes en `RiftChip` (`aria-pressed`).
  3. La double page : deux grilles de 3 × 3 pochettes et une reliure centrale.
     - **Pochette pleine** : `RouterLink` vers la fiche, illustration, quantité « ×N ».
     - **Fantôme** (non possédée) : illustration désaturée à faible opacité, code et prix. L'`alt` et le `title` disent « Carte manquante : nom ».
     - **Case vide** : pochette décorative `aria-hidden`.
     - **Premier chargement** : 18 pochettes squelettes.
  4. La navigation « ← Tourner », « X / Y », « Tourner → » (`RiftButton ghost sm`, avec `aria-label`), désactivée aux bornes et pendant un chargement.
  5. Si `progress.overall.owned === 0` : un `RiftEmpty` titré « Votre classeur attend ses premières cartes », avec un bouton « Parcourir les cartes » vers `/cartes`, **à la place** de la double page.
  6. Double page vide pour un filtre : on garde les messages actuels (« Rien ne manque ici », « Aucune carte possédée dans ce set », « Classeur vide ») dans un `RiftEmpty`.
- **Style Forgé** :
  - pages en `--bg-sunken`, avec un filet de bronze et des angles coupés ;
  - pochettes avec un fin cadre `--line`, et un reflet foil au survol pour `isFoil` ;
  - reliure : trois anneaux bronze ;
  - transition de tournage de 200 ms au plus (fondu + glissement de 12 px dans le sens `turnDir`), coupée sous reduced-motion ;
  - classes préfixées `classeur-` (vérifier par grep qu'elles n'existent pas dans `main.css`).

- [ ] **Step 1 : tests** : migrer « classeur par défaut : ouvre le premier set incomplet, pochettes pleines et fantômes » et adapter les sélecteurs. Ajouter :
  - « collection vide : RiftEmpty avec lien vers /cartes, pas de double page » ;
  - « onglet d'un set complet : ✓ et aria-selected » ;
  - « navigation désactivée aux bornes ».
- [ ] **Step 2 à 5** : échec, composant, succès, commit `Web : classeur Forgé (onglets de sets, pochettes, fantômes)`.

---

### Task 3 : `CollectionInventory` (inventaire Forgé)

**Files :** Create `src/collection/CollectionInventory.vue`, `src/collection/CollectionInventory.spec.js`.

**Interfaces :**
- `<CollectionInventory :filters :sets />`. `filters` est l'objet renvoyé par `useQuerySyncedFilters` dans la page : `state`, `result`, `loading`, `error`, `activeCount`, `pageCount`, `setFilter`, `reset`, `load`. `sets` est au format `[{ value, label }]`.
- Le composant utilise `useGridMeasure` sur sa propre grille. Quand la taille change, il délègue : `watch(size)` appelle `filters.scheduleLoad`, ou remet `state.page` à 1, comme dans l'actuel `CollectionView`. Le nombre d'éléments par page envoyé au fetcher vient d'une prop `pageSize` que la page fournit : **décision** pour éviter une dépendance circulaire, la page possède `useGridMeasure` et passe à l'inventaire une ref de gabarit par `defineExpose`. Retenir la solution la plus simple qui garde « taille de page = grille mesurée » et l'expliquer dans le rapport.
- **Barre d'outils** :
  - « Filtres (N) » ouvre une `RiftSheet` avec `CardFilters` (même schéma que la cartothèque) et un pied « Voir les N cartes » ;
  - le tri « Prix décroissant / Prix croissant » se fait par deux `RiftChip` à choix unique (`state.sort`) ;
  - « Sélectionner » / « Terminer la sélection » ;
  - « Exporter (CSV) », un lien direct vers `/api/collection/export.csv` avec `download`.
- **`ActiveFilters`** au-dessus de la grille.
- **Barre de masse** (`role="toolbar"`, visible en mode sélection) : compteur, « Toute la page », « +1 par lot », « −1 par lot », état et langue (select + Appliquer), « Retirer de la collection » qui ouvre une `RiftModal` de confirmation (Annuler / Retirer). Les erreurs s'affichent dans la modale pour le retrait, et dans la page sinon.
- **Grille** de cellules, une par `item` :
  - `ui/CardTile` (`card = { ...item.card, owned_qty: item.total_qty }`, `preview: false`) ;
  - en dessous, la ligne méta : état et langue du lot unique, ou « N lots » (`title` = détail des lots), la valeur du lot et « ×qty ».
  - **En mode sélection**, la cellule devient un `<button type="button" aria-pressed>` qui enveloppe la vignette. Le lien de la vignette est neutralisé (`tabindex="-1"`, clic intercepté) : Entrée et Espace cochent, et rien ne navigue.
- **États vides** : `RiftEmpty` « Votre vitrine est encore vide » (avec un lien vers `/cartes`) si `unique_cards` vaut 0 ; « Aucune carte ne correspond aux filtres » (avec réinitialisation) sinon.
- **Pagination** comme dans la cartothèque.
- **Reprise de l'existant** : la logique de sélection et de masse vient de `CollectionView.vue` (`toggleSelectMode`, `onTileClick`, `selectPage`, `askRemove`, `cancelRemove`, `applyBulk`), à déplacer sans en changer le comportement. Ajouter une règle : en cas d'erreur, la sélection est conservée.

- [ ] **Step 1 : tests** : migrer « inventaire : reprend les filtres de la cartothèque », « quantité, lots et prix, sans aperçu au survol », « tri par prix : paramètre sort synchronisé à l'URL », « mode sélection : le clic coche au lieu de naviguer, puis applique une opération de masse », « Exporter (CSV) pointe directement sur l'export » et « retire de la collection après confirmation dans la modale ». Ajouter :
  - « en mode sélection, Entrée sur une cellule coche sans naviguer » ;
  - « opération de masse en échec : erreur affichée, sélection conservée, bouton réactivé » ;
  - « collection vide : RiftEmpty avec lien vers /cartes ».
- [ ] **Step 2 à 5** : échec, composant, succès, commit `Web : inventaire Forgé (filtres en feuille, sélection accessible, opérations de masse)`.

---

### Task 4 : `CollectionStats` et nouvelle page `CollectionView`

**Files :** Create `src/collection/CollectionStats.vue` (+ spec). Modify `src/views/CollectionView.vue` (réécrit) et `src/views/CollectionView.spec.js`.

**Interfaces :**
- `<CollectionStats :items="[{ label, value, title? }]" />` : une rangée de `RiftStat` sans glyphe. Une valeur `null` affiche « — ».
- **CollectionView** :
  - un `h1` « Ma collection » (sans `PageBanner`) ;
  - `CollectionStats` avec Cartes, Uniques, Valeur estimée (`title` = `PRICE_NOTE`) et Complétion (« N % », `title` = le texte de ce qu'il manque) ;
  - le commutateur Classeur / Inventaire, deux `RiftChip` à choix unique dans un `role="group"` avec `aria-label`, liés à `state.vue` (synchronisé à l'URL, épargné par la réinitialisation) ;
  - `CollectionBinder` (`:active="state.vue === 'classeur'"`) ou `CollectionInventory`.
- **Chargements** : `/api/collection/sets`, `/api/sets` et le premier `load()`, comme aujourd'hui. Le fetcher n'est actif qu'en mode inventaire.
- **Spec** : migrer « stats : totaux de l'inventaire et complétion globale » et « commutateur : passe à l'inventaire et le note dans l'URL ». Supprimer les cas migrés vers les tâches 1 à 3, et retirer le cas de la cascade.

- [ ] Steps : tests, échec, implémentation, succès, commit `Web : nouvelle page collection (stats, commutateur, classeur et inventaire)`.

---

### Task 5 : nouvelle wishlist

**Files :** Modify `src/views/WishlistView.vue` (réécrit) et `src/views/WishlistView.spec.js` (adapté).

**Interfaces :**
- `h1` « Ma wishlist ».
- `CollectionStats` avec Cartes souhaitées et Valeur estimée.
- Grille de cellules, chacune avec :
  - `ui/CardTile` (`preview: false`) ;
  - un stepper en `role="group"` (aria-label « Quantité souhaitée de X »), composé de `RiftButton ghost sm` « − » et « + » (`aria-label` « Un exemplaire de moins / de plus ») et d'un `input type=number` non contrôlé ;
  - un bouton « Retirer » (`aria-label` « Retirer X de ma liste de souhaits »).
- `RiftEmpty` « Votre wishlist est vide », avec le texte « Le cœur sur la fiche d'une carte l'ajoute ici. » et un bouton « Parcourir les cartes » vers `/cartes`.
- Squelettes au premier chargement.
- Toute la logique actuelle est conservée : `refresh`, `clampQty`, `setQty` avec réécriture de l'input, `removeItem`, `busyId`.
- Les classes `souhait-…` doivent être absentes de `main.css`.
- **Spec** : garder les six cas en adaptant les sélecteurs.

- [ ] Steps : adapter, échec, implémentation, succès, commit `Web : nouvelle wishlist Forgée`.

---

### Task 6 : nettoyage et documentation

- [ ] **`main.css`** : supprimer les règles de l'ancien classeur, de l'inventaire et de la wishlist, après vérification par grep dans `src/**/*.vue` pour chaque classe :
  - `binder*`, `pocket*`, `view-switch`, `col-stats`, `bulk-*`, `col-cell`, `col-state`, `price-lot`, `board-actions` ;
  - `wish-cell`, `wish-controls`, `wish-stepper`, `wish-remove`, `wish-empty` ;
  - les keyframes de tournage et de cascade du classeur (`turn-*`, `deal`…) ;
  - `col-empty` et `t-meta` **si** plus aucune vue ne les utilise.

  À l'inverse, garder `wish-from-deck`, et tout ce qu'une autre vue utilise encore (le lister dans le rapport). Penser aux listes groupées et aux `@media` vidés.
- [ ] **Spec** : à la fin de la section « PR 4 : collection et wishlist », ajouter une puce « Livré » qui résume le découpage (`src/collection/`), les préfixes de classes, le tournage raccourci et la cascade supprimée.
- [ ] `npm run check` vert. Deux commits : `Web : retrait des styles de l'ancienne collection` et `Docs : spec — livré en PR 4`.

### Task 7 : validation par le mainteneur (contrôleur)

- [ ] Transmettre au mainteneur la liste suivante et attendre son accord :
  - **Classeur** : onglets, progression, filtres, fantômes, tournage à la souris et au clavier, collection vide.
  - **Inventaire** : filtres en feuille, tri, sélection à la souris et au clavier, opérations de masse, retrait confirmé, export CSV.
  - **Wishlist** : stepper, retrait, état vide.
- [ ] Ensuite : push, PR vers `refonte/forge`, puis merge si la CI est verte.
