# Refonte Forge noxienne — PR 4b : ajout à la collection — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** remplacer la saisie actuelle des exemplaires (champ numérique, menus déroulants d'état et de langue, bouton « + Ajouter un lot ») par la mécanique validée par le mainteneur le 6 octobre 2026, qui fusionne trois propositions :
- **A, compteur rapide** sur la fiche : un gros − / + ; chaque clic ajoute ou retire un exemplaire dans l'état et la langue habituels (mémorisés) ;
- **B, lots en puces** : les exemplaires lisibles (« 2× NM · Français »), retirables d'un clic. L'ajout précis se fait par puces d'état et de langue, sans aucun menu déroulant ni champ numérique ;
- **C, saisie rapide sur les vignettes** : un interrupteur « Saisie rapide » sur la cartothèque et dans le classeur, qui pose un − / + sur chaque vignette pour saisir un booster ou un classeur à la chaîne.

**Architecture :**
- La logique d'une carte (lots, +1, −1, ajout précis, retrait d'un lot, garde anti-course) passe dans un composable `useOwnedCopies`, partagé par la fiche et la saisie rapide.
- Deux composants de base rejoignent `src/ui/` : `RiftStepper` (− valeur +) et `RiftChoice` (choix unique en puces, `role="radiogroup"`).
- Les préférences d'état et de langue vivent dans `localStorage`. C'est une commodité par visiteur, toujours lue et écrite sous `try/catch`.
- **Aucun changement d'API.** `POST /api/collection/{id}/entries` additionne déjà un lot de même état et de même langue ; `PATCH /api/collection/entries/{id}` gère la quantité (0 supprime le lot) ; `GET /api/collection/{id}` renvoie `{ card_id, total_qty, entries }`.

**Tech Stack :** Vue 3.5, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§3.3, §5). Ce plan ajoute une étape « PR 4b » entre les PR 4 et 5.

## Global Constraints

- **Branche** : `feat/refonte-ajout-collection` depuis `origin/refonte/forge`. La PR vise `refonte/forge`. Aucun push sans validation du mainteneur.
- **Langue et commits** : français ; commits `Web : …` terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `npm run check` vert.
- **Leçon des PR précédentes** : les classes nouvelles doivent être absentes de `src/assets/main.css` (le vérifier par grep) ; les balises héritées (`input`, `select`, `button`, `h2`, `h3`) sont neutralisées localement. Le test `src/assets/cssCoverage.spec.js` doit rester vert : toute classe statique d'un gabarit a une règle.
- **Accessibilité** :
  - cibles de 44 px au minimum sur le stepper principal et les puces d'ajout (36 px tolérés sur les vignettes, réparties sur toute la largeur) ;
  - libellés explicites : « Ajouter un exemplaire de X », « Retirer un exemplaire de X », « Retirer le lot 2× NM · Français » ;
  - compteurs en `aria-live="polite"`.
- **Libellés** : les états restent en code (MT, NM, EX, GD, LP, PL, PO) avec le nom complet en `title` et en `aria-label` (`CONDITIONS` de `api.js`). Les langues s'affichent en toutes lettres dans les puces de lot (« Français ») et en code dans le choix (FR, EN…), nom complet en `title` (`LANGS`).
- **Préférence par défaut** : `{ condition: "NM", lang: "FR" }`, c'est-à-dire « NM · Français » comme dans la maquette validée.

## Review Focus

- **Clics rapides sur + ou −** : aucune requête ne part tant que la précédente n'est pas revenue, ou bien les clics sont mis en file. Le compteur affiché reste toujours égal au total du serveur. Testé en tâche 1.
- **Retirer un exemplaire** quand plusieurs lots existent : on retire d'abord dans le lot qui correspond à la préférence, sinon dans le dernier lot ajouté (le plus grand `id`). À 0 exemplaire, le − est désactivé. Testé en tâche 1.
- **Saisie rapide pour un visiteur** : l'interrupteur n'apparaît pas. Testé en tâche 4.
- **Saisie rapide** : un clic sur − ou + n'ouvre jamais la fiche, et la vignette d'une carte manquante du classeur passe de fantôme à possédée sans recharger la page. Testé en tâches 4 et 5.
- **`localStorage` bloqué** : la préférence par défaut s'applique et rien ne casse. Testé en tâche 1.

---

### Task 1 : préférences et `useOwnedCopies`

**Files :** Create `src/collection/collectionDefaults.js`, `src/collection/useOwnedCopies.js` et leurs `.spec.js`.

**Interfaces :**
- `collectionDefaults.js`, clé `riftarium_collection_defaults` :
  - `readDefaults() → { condition, lang }` : valeurs validées contre `CONDITIONS` et `LANGS` ; repli sur `{ condition: "NM", lang: "FR" }` ;
  - `writeDefaults({ condition, lang })` : silencieux si le stockage est bloqué.
- `useOwnedCopies(cardId: Ref<string|null>, { onChange } = {})` renvoie :
  - `entries` : `Ref<[{ id, qty, condition, lang }]>` ;
  - `total` : `Ref<number>` ;
  - `loading`, `busy` : `Ref<boolean>` ;
  - `error` : `Ref<string>` ;
  - `defaults` : réactif, initialisé par `readDefaults()` ;
  - `setDefaults(patch)` : met à jour et persiste ;
  - `load()` : `GET /api/collection/<id>` ;
  - `increment()` : `POST /entries` avec `{ qty: 1, ...defaults }` ;
  - `decrement()` : `PATCH` du lot choisi (règle du Review Focus) à `qty - 1` ;
  - `addLot({ qty, condition, lang })` : `POST` ;
  - `removeLot(entry)` : `PATCH` à `qty: 0`.
- Chaque mutation applique la réponse (`card_state`) aux refs et appelle `onChange({ id, owned_qty: total })`.
- Une mutation lancée alors qu'une autre est en vol est **ignorée**, et le bouton est désactivé (`busy`).
- Une réponse arrivée après un changement de `cardId` est ignorée (garde par id).
- En cas d'erreur, `error` reçoit le message et l'état est inchangé.
- `load()` se lance quand `cardId` change, mais seulement si `session.token` existe.

- [ ] Tests :
  - préférences : valeurs par défaut, persistance, stockage bloqué, valeurs invalides ignorées ;
  - `increment` envoie les préférences ;
  - `decrement` choisit le lot de la préférence, sinon le plus grand id ;
  - − sans exemplaire n'envoie rien ;
  - un double clic pendant `busy` n'envoie qu'une requête ;
  - une réponse tardive après changement de carte est ignorée ;
  - une erreur est conservée et l'état intact ;
  - `onChange` est appelé avec l'id et le total.
- [ ] Puis implémentation, succès, commit `Web : logique d'ajout à la collection (préférences, compteur, lots)`.

### Task 2 : `RiftStepper` et `RiftChoice`

**Files :** Create `src/ui/RiftStepper.vue`, `src/ui/RiftChoice.vue` et leurs specs.

**Interfaces :**
- `<RiftStepper :value :min="0" :max="999" :busy :label="nom" size="md|sm" @increment @decrement />` :
  - deux `<button type="button">` avec `aria-label` « Retirer un exemplaire de {label} » et « Ajouter un exemplaire de {label} » ;
  - la valeur au centre, en `aria-live="polite"` ;
  - − désactivé à `min`, + désactivé à `max`, les deux désactivés si `busy` ;
  - le + en rouge biseauté, le − en filet de bronze ;
  - `md` fait 44 px, `sm` (vignettes) 32 px.
- `<RiftChoice v-model :options="[{ value, label, title }]" :label />` :
  - `role="radiogroup"` avec `aria-label` ;
  - chaque option est un `<button type="button" role="radio" :aria-checked>` à tabindex itinérant ;
  - les flèches gauche et droite déplacent la sélection ;
  - les puces font 44 px de haut au minimum.

- [ ] Tests (rendu, événements, désactivations, clavier du groupe radio), puis implémentation, commit `Web : composants RiftStepper et RiftChoice`.

### Task 3 : nouveau panneau de la fiche (`CardCollectionPanel`)

**Files :** Modify `src/cards/CardCollectionPanel.vue` (réécrit avec `useOwnedCopies`) et sa spec.

**Interfaces** (props et événements inchangés : `card` ; `change({ id, ...patch })`) :
- **Visiteur** : invitation à se connecter, inchangée.
- **Membre** :
  1. **« Dans ma collection »** : un `RiftStepper` `md` sur `total`.
  2. **Préférence** : la ligne « Ajouté en NM · Français · changer ». Le bouton « changer » ouvre en ligne deux `RiftChoice` (État, Langue) liés à `setDefaults`.
  3. **Détail des exemplaires** : un `<details>` replié par défaut, titré « Détail des exemplaires (N lots) », qui contient :
     - un lot par puce retirable (`RiftChip removable`) libellée « 2× NM · Français », avec l'`aria-label` « Retirer le lot … » ;
     - le bloc « Ajouter un lot précis » : un `RiftStepper` pour la quantité (local, de 1 à 999), un `RiftChoice` État, un `RiftChoice` Langue, et un `RiftButton` « Ajouter ».
  4. **Wishlist** : le bouton reste tel quel (`.panel-wish`).
- Les messages (`.panel-saved`) et les erreurs (`role="alert"`) sont conservés.
- **Plus aucun** `<select>` ni `<input type="number">` dans le panneau.

- [ ] Tests :
  - migrer les cas existants vers les nouveaux contrôles : wishlist PUT puis DELETE ; ajout qui envoie POST et remet la quantité à 1 ; échec qui conserve la saisie ; échec de chargement des lots qui laisse le panneau utilisable ; garde de variante ;
  - ajouter : + et − du compteur ; changement de préférence persisté et utilisé par le + suivant ; retrait d'un lot par sa puce ; aucun `select` ni `input[type=number]` rendu.
- [ ] Puis commit `Web : fiche carte — compteur rapide, lots en puces, ajout précis sans menus`.

### Task 4 : saisie rapide sur la cartothèque

**Files :** Create `src/collection/QuickCount.vue` (+ spec). Modify `src/ui/CardTile.vue` (slot `overlay`), `src/views/CardsView.vue` et leurs specs.

**Interfaces :**
- `<QuickCount :card @change />` :
  - une barre posée en bas de l'illustration : `RiftStepper` `sm` sur `card.owned_qty`, avec le nom de la carte pour libellé ;
  - le + appelle `POST` avec les préférences ;
  - le − fait `GET /api/collection/<id>`, puis `PATCH` selon la règle du Review Focus. Utiliser `useOwnedCopies` avec un `cardId` fixe, sans `load()` automatique : le chargement des lots n'a lieu qu'au premier −.
  - émet `change({ id, owned_qty })` ;
  - les clics appellent `stopPropagation` et `preventDefault`, pour ne jamais naviguer.
- `CardTile` reçoit un slot `overlay`, rendu dans `.tile-art`.
- **CardsView** :
  - pour un membre seulement, un `RiftChip` à bascule « Saisie rapide » dans l'en-tête ;
  - interrupteur actif : chaque vignette affiche `QuickCount`, et `change` met à jour `owned_qty` de l'élément de `result.items` ;
  - l'état de l'interrupteur est mémorisé pour la session (`sessionStorage`, sous `try/catch`) ;
  - un rappel discret « Ajouts en NM · Français · changer » ouvre une `RiftSheet` avec les deux `RiftChoice`.

- [ ] Tests :
  - interrupteur absent pour un visiteur ;
  - activation qui fait apparaître les compteurs ;
  - + qui envoie POST avec les préférences et met à jour la vignette ;
  - − qui enchaîne GET puis PATCH ;
  - clic qui ne navigue pas ;
  - préférence modifiable depuis la feuille.
- [ ] Puis commit `Web : saisie rapide sur la cartothèque`.

### Task 5 : saisie rapide dans le classeur

**Files :** Modify `src/collection/CollectionBinder.vue` et sa spec (et `useCollectionBinder.js` si nécessaire).

**Interfaces :**
- Pour un membre, un `RiftChip` « Saisie rapide » dans l'en-tête du classeur, avec le même rappel de préférence que sur la cartothèque.
- Interrupteur actif :
  - chaque pochette, pleine ou fantôme, affiche `QuickCount` ;
  - `change` met à jour `owned_qty` de la carte dans `spread.items` : une pochette fantôme devient pleine à 1 exemplaire, une pleine revient en fantôme à 0 ;
  - le classeur émet aussi `changed`, et la page recharge les statistiques et la progression (`loadProgress`), comme après une opération de masse ;
  - le tournage de page aux flèches reste actif.
- [ ] Tests :
  - + sur un fantôme le rend possédé (×1) sans recharger la double page ;
  - − à 1 le rend fantôme ;
  - la page recharge la progression ;
  - un clic ne navigue pas.
- [ ] Puis commit `Web : saisie rapide dans le classeur`.

### Task 6 : nettoyage et documentation

- [ ] **Code mort** : supprimer les styles et classes du panneau devenus inutiles. Garder `cssCoverage.spec` vert, mettre sa liste d'exceptions à jour si besoin, et vérifier par grep.
- [ ] **Spec** :
  - ajouter une « PR 4b : ajout à la collection » au §5, avec la décision du mainteneur (A + B + C), l'absence de menus déroulants et la préférence mémorisée ;
  - mentionner `RiftStepper` et `RiftChoice` au §3.3.
- [ ] `npm run check` vert. Commits `Web : …` et `Docs : …`.

### Task 7 : validation par le mainteneur (contrôleur)

- [ ] Transmettre au mainteneur la liste suivante et attendre son accord :
  - **Fiche** : compteur, préférence, lots en puces, ajout précis.
  - **Cartothèque** : saisie rapide.
  - **Classeur** : saisie rapide sur les fantômes.
  - **Téléphone** : tailles des cibles.
- [ ] Après accord : push, PR vers `refonte/forge`, puis merge si la CI est verte.
