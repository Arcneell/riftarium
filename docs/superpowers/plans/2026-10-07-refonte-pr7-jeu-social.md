# Refonte Forge noxienne — PR 7 : jeu et social — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** refaire en style Forgé les pages de jeu et de social, sans perdre aucune fonction :
- `/salon/:code?` ;
- `/historique` ;
- `/statistiques`, avec les graphiques ;
- `/profil` ;
- `/u/:handle` (profil public, hauts faits) ;
- `/amis`.

**Architecture :**
- Un nouveau dossier `src/play/` reçoit les pièces du jeu, et `src/social/` celles du profil et des amis.
- Les composants partagés sont déplacés et rhabillés :
  - `MatchRow` va dans `src/play/` ;
  - `AchievementMedal` va dans `src/social/` ;
  - les graphiques de `src/components/charts/` restent en place mais sont rhabillés par tokens. `AdminView` les utilise aussi : on ne change pas leur API.
- La logique ne change pas : `play.js`, `social.js`, `achievementIcons.js`, `usePlayStats` et le polling du salon restent tels quels.
- Les contrats `riftarium/docs/suivi-des-matchs.md` et `riftarium/docs/profils-et-hauts-faits.md` ne changent pas.

**Tech Stack :** Vue 3.5, vue-router 5, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§3.3, §3.4, §5 PR 7, §8)

## Global Constraints

- **Branche** : `feat/refonte-jeu-social` depuis `refonte/forge` (944ea67). La PR vise `refonte/forge`. Aucun push sans validation locale du mainteneur.
- **Langue** : français pour les commentaires, l'interface et les commits. Identifiants en anglais.
- **Commits** : `Web : …` ou `Docs : …`, puis une ligne vide, puis `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Vérification** : `npm run check` vert (lint, format:check, test, build) avant chaque commit, depuis `riftarium/apps/web`.
- **Composants disponibles** :
  - `src/ui/` :
    - boutons et champs : `RiftButton` (primary / secondary / ghost, sm / md, `to`), `RiftField` (`search`, `type`, `error`, v-model), `RiftChoice` (radiogroup en puces) ;
    - puces et onglets : `RiftChip` (`selected` et `@toggle`, `static`, `removable`), `RiftSegments` (onglets dans une page) ;
    - blocs et états : `RiftPanel` (`title`, `accent`), `RiftEmpty`, `RiftSkeleton`, `RiftStat` (`label`, `value`, `glyph`) ;
    - dialogues : `RiftModal`, `RiftSheet` ;
    - texte : `RiftText` ;
  - `src/decks/DeckCard.vue` (prop `readonly`), `src/decks/LegendPicker.vue` (sélecteur de légende multiple), `src/composables/useBreakpoint.js`, `src/search/search.js` (`fold`) ;
  - mise en page de référence des pages refaites : `src/views/DecksView.vue` (`h1` neutralisé, `wrap cards-wrap`) ;
  - tokens dans `src/styles/tokens.css` : encre rouge des textes `--blood-text`, rouge vif réservé aux grands titres.
- **Leçon des PR précédentes (obligatoire)** : `src/assets/main.css` est chargé APRÈS `src/styles/*` et fuit sur tout nom de classe qu'il connaît, ainsi que sur `h1`, `h2`, `h3`, `section`, `input`, `select`, `textarea`, `button`, `table`, `th` et `form`.
  - Préfixes réservés à cette PR, absents de `main.css` (vérifié) : `salon-`, `partie-`, `histo-`, `stats-`, `profil-`, `amis-`, `trophee-`, `graphe-`, `joueur-`, `compte-`, `duel-`.
  - Classes héritées interdites : `play-*`, `profile-*`, `friends-*`, `chart-*`, `stat`, `stat-row`, `panel`, `field`, `btn*`, `chip*`, `medal*`, `avatar*`, `mono`, `muted`, `switch`.
  - Vérifie toute classe nouvelle par grep dans `main.css`.
  - Neutralise localement les balises héritées : `h1` (`background: none; color: var(--ink); animation: none; font-weight: 700`), `h2` / `h3` (marges, taille et couleur explicites), `section` (`padding: 0`), `table` / `th`, ainsi que `input` et `select` (`box-shadow: none` au focus).
  - `cssCoverage.spec.js` doit rester vert.
- **Pas de `PageBanner`** ni de `v-reveal` / `v-tilt` sur les pages refaites. Le titre est un `h1` dans la page. La coquille affiche déjà la rubrique Jouer avec les onglets Salon / Historique / Statistiques.
- **Couleurs du jeu** : victoire `--bronze-light`, défaite `--blood-text`, contesté `--ink-muted` avec une hachure. Les graphiques prennent leurs couleurs dans les tokens : volume en `--bronze`, victoires en `--blood`, grille en `--line`, textes en `--ink-muted`. Aucune couleur codée en dur dans les graphiques.
- **Glyphes officiels** : runes de domaine par `glyphUrl` ou `RiftGlyph`. Pas d'emoji.
- **Accessibilité** :
  - cibles d'au moins 44 px, focus visible en `--bronze-light` (outline rentrant d'au moins -6 px sur les éléments en `clip-path`) ;
  - les graphiques gardent une alternative textuelle (tableau ou `sr-only`) ;
  - `aria-live` sur le score du salon et sur les états de confirmation.
- **Comportements conservés** : tous les cas des specs `RoomView`, `HistoryView`, `StatsView`, `ProfileView`, `PublicProfileView`, `FriendsView`, `MatchRow`, `AchievementMedal` et des graphiques, migrés sans perte d'intention. Notamment :
  - le polling du salon et son arrêt au démontage ;
  - le code du salon dans l'URL ;
  - la confirmation et la contestation ;
  - les réglages de confidentialité ;
  - le changement d'e-mail et de mot de passe ;
  - l'export RGPD ;
  - la suppression de compte confirmée ;
  - suivre et ne plus suivre ;
  - inviter dans un salon.
- **Aucun changement d'API.**

## Review Focus

- **Salon en direct** : quand le score change pendant que la page est ouverte, la page se met à jour sans perdre le choix en cours (recherche de légende, deck) et sans remettre le focus au début. Le polling s'arrête au démontage et quand l'onglet est caché, si c'était déjà le cas. Testé en tâche 2.
- **Statistiques vides ou partielles** (zéro partie, un seul deck, légende supprimée) : on voit des états vides clairs, sans graphique cassé, sans NaN ni barre invisible. Testé en tâches 1 et 3.
- **Profil public d'un compte privé ou introuvable** : on voit un message clair, jamais un squelette infini. Si un réglage masque les duels ou la collection, la section correspondante n'apparaît pas. Testé en tâche 5.
- **Actions sensibles du profil** (changement de mot de passe, suppression de compte) : confirmation obligatoire, bouton désactivé pendant la requête, erreur affichée sur place. Un double clic n'envoie qu'une requête. Testé en tâche 4.
- **Pseudo long ou sans espace** (24 caractères et plus) dans le salon, l'historique, les amis et le profil : ellipse, aucun débordement. Testé par une classe d'ellipse en tâches 1, 2 et 5.

---

### Task 1 : pièces communes (graphiques, `MatchRow`, `AchievementMedal`, `UserAvatar`)

**Files :**
- Modify : `src/components/charts/ColumnChart.vue`, `HBarChart.vue` et `StackedBar.vue`, avec leurs specs.
- Move et rewrite :
  - `src/components/MatchRow.vue` devient `src/play/MatchRow.vue`, avec sa spec ;
  - `src/components/AchievementMedal.vue` devient `src/social/AchievementMedal.vue`, avec sa spec si elle existe.

  Utiliser `git mv` et mettre à jour tous les imports (grep).
- Modify : `src/components/UserAvatar.vue`. Il garde sa place, car la coquille l'utilise.

**Interfaces** (props et événements inchangés partout) :
- **Graphiques** : les couleurs passent par des variables CSS issues des tokens. Les props qui reçoivent des couleurs gardent leur forme, mais leurs valeurs par défaut deviennent des tokens. Concrètement :
  - axes et grille en `--line` ;
  - libellés en `--ink-muted`, Barlow Condensed ;
  - barres avec angles coupés de 2 px en tête ;
  - info-bulle Forgée (`--bg-raised`, filet `--line`).

  L'alternative accessible existante est conservée. L'admin doit rester correct : vérifier `AdminView` par ses specs.
- **`MatchRow`** : une ligne Forgée `partie-row`. Chaque ligne affiche :
  - l'issue, en pastille `RiftChip static` « Victoire », « Défaite » ou « Contesté », aux couleurs du jeu ;
  - l'adversaire, avec avatar et lien vers son profil, ou « Compte supprimé » ;
  - les légendes des deux côtés, en vignettes rondes de 32 px ;
  - le deck ;
  - le score en Cinzel ;
  - la date relative ;
  - le format.

  Sous 560 px, la ligne passe sur deux lignes. Les pseudos sont tronqués par une ellipse.
- **`AchievementMedal`** : une médaille hexagonale Forgée de 64 px. Le rang (`tier`) donne la couleur du filet : bronze, puis argent, puis or. On garde les couleurs de rang existantes si elles sont définies dans `achievementIcons.js` ou dans le CSS, en les adaptant à la palette. Une médaille verrouillée est atténuée.
- **`UserAvatar`** : liseré `--bronze` de 1 px, et un fond de repli `--bg-sunken` avec l'initiale en Cinzel.

- [ ] **Step 1 : tests.**
  - Migrer les specs existantes.
  - Ajouter :
    - « MatchRow : issue contestée, adversaire supprimé, pseudo long (classe d'ellipse) » ;
    - « graphique sans données : pas de NaN dans les attributs SVG » ;
    - « médaille verrouillée : classe et aria-label ».
- [ ] **Step 2 à 4** : vérifier l'échec, implémenter, vérifier le succès. Lancer aussi `AdminView.spec`.
- [ ] **Step 5** : commit `Web : pièces communes du jeu et du social (graphiques, parties, médailles)`.

---

### Task 2 : salon (`/salon/:code?`)

**Files :** Modify `src/views/RoomView.vue` et sa spec. Si cela allège la vue, create `src/play/useRoom.js` et sa spec, pour extraire le chargement, le polling et les actions sans changer leur comportement.

**Gabarit** (`div.wrap.cards-wrap.salon`) :
1. **`h1`** « Salon de jeu », avec le code du salon en Barlow Condensed et un bouton « Copier le lien ». Ce bouton existe-t-il déjà ? Le conserver s'il existe, sinon ne pas l'inventer.
2. **Sans code** : un `RiftPanel` « Rejoindre un salon ».
   - Il contient un champ de code (`RiftField`, majuscules, `autocomplete="off"`) et le bouton « Rejoindre ».
   - Il contient aussi la phrase actuelle qui explique que le salon se crée depuis l'application.
3. **En-tête du salon `salon-head`** : statut, format, puis les joueurs en deux colonnes face à face. Chaque colonne montre :
   - l'avatar, le pseudo (ellipse) et la mention « hôte » ;
   - la légende choisie (vignette et nom) ;
   - le deck ;
   - l'état « Prêt » (pastille).

   Au centre, un séparateur « contre » en Cinzel.
4. **« Mes choix »**, seulement tant que le salon est ouvert :
   - la légende : la recherche existante (champ et liste de résultats) est rhabillée. Les résultats sont des boutons de 44 px avec vignette, et l'état « Recherche… » ou « Aucune légende trouvée » est conservé ;
   - le deck : un `select` natif rhabillé (fond `--bg-sunken`, filet `--line`, chevron), ou un `RiftChoice` si la liste est courte. Le `select` reste acceptable, mais il doit être neutralisé contre `main.css` ;
   - « Je suis prêt » / « Je ne suis plus prêt » : `RiftButton` primary ou ghost, avec `aria-pressed`.
5. **Notice de lancement** depuis le téléphone, en `RiftPanel` avec un accent bronze.
6. **Actions** : « Annuler le salon » (hôte, `RiftButton` en variante danger : si elle n'existe pas, primary sur fond sang) et « Quitter le salon ».
7. **Partie** :
   - un `RiftPanel` « Partie » avec le statut, la manche et le tour ;
   - les scores en Cinzel de 40 px, face à face, `aria-live="polite"` ;
   - « manche(s) » en mode match ;
   - la mention « Confirmé » ;
   - « Confirmer le résultat » (primary) et « Contester » (ghost) ;
   - les messages « contesté » et « clos » avec leurs liens.
- **Conservé** :
  - le polling ;
  - le code dans l'URL ;
  - les gardes `busy` ;
  - les redirections ;
  - les erreurs (`role="alert"`) ;
  - la logique de `play.js`.

- [ ] **Step 1 : tests.**
  - Migrer les cas de `RoomView.spec`.
  - Ajouter :
    - « une mise à jour du polling ne vide pas la recherche de légende en cours » ;
    - « double clic sur Confirmer : un seul POST » ;
    - « score annoncé en aria-live » ;
    - « pseudo long : ellipse ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : salon de jeu Forgé`.

---

### Task 3 : historique et statistiques

**Files :** Modify `src/views/HistoryView.vue`, `src/views/StatsView.vue` et leurs specs.

**Historique** :
- `h1` « Historique des parties » ;
- liste de `MatchRow` ;
- pagination ou « charger plus », selon l'existant ;
- squelettes au premier chargement ;
- `RiftEmpty` « Aucune partie suivie » avec un lien vers le salon, en conservant le texte existant ;
- erreur en `role="alert"`.

**Statistiques** :
- `h1` « Mes statistiques ».
- Rangée `stats-kpis` de `RiftStat` : parties, victoires, défaites, taux de victoire, série en cours, meilleure série (mêmes données).
- Le graphique des 30 derniers jours (`ColumnChart`) dans un `RiftPanel` pleine largeur.
- « Par deck » : un tableau Forgé `stats-table`, neutralisé contre `main.css`. Il contient :
  - le nom du deck, en lien vers le deck ;
  - le format ;
  - les parties, victoires et défaites ;
  - le taux de victoire, avec une jauge.

  Le tableau défile horizontalement sous 560 px.
- « Par légende » et « Par légende adverse », côte à côte (empilés sous 1 024 px). Chaque ligne affiche la vignette ronde, le nom et une jauge de taux de victoire avec sa valeur en texte.
- « Par format ».
- Statistiques vides : `RiftEmpty` « Aucune partie suivie » avec un lien vers le salon. Aucun graphique n'est rendu.

- [ ] **Step 1 : tests.**
  - Migrer les cas existants.
  - Ajouter :
    - « zéro partie : RiftEmpty, aucun graphique » ;
    - « une seule légende supprimée (null) : la ligne s'affiche avec un libellé de repli » ;
    - « jauge : largeur bornée de 0 à 100 % » ;
    - « historique vide : RiftEmpty avec lien vers le salon ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : historique et statistiques Forgés`.

---

### Task 4 : mon profil (`/profil`)

**Files :** Modify `src/views/ProfileView.vue` et sa spec. Si la vue reste trop longue (plus de 450 lignes), create des sous-composants dans `src/social/` : `ProfileIdentity.vue`, `ProfileSecurity.vue`, `ProfilePrivacy.vue`. Leurs props et événements doivent être explicites, et la logique réseau reste dans la page ou dans des fonctions passées en props.

**Gabarit** :
1. En-tête `profil-hero` :
   - le grand avatar ;
   - le pseudo en `h1`, avec une ellipse ;
   - la date d'inscription et les mentions existantes ;
   - le lien vers le profil public.
2. Sections existantes, chacune en `RiftPanel` avec un titre et dans le même ordre :
   - les hauts faits (médailles, progression) ;
   - Confidentialité : bascules en `RiftChip` avec `aria-pressed`, ou en interrupteur Forgé `compte-switch` construit sur une case à cocher native masquée avec un libellé, sans réutiliser la classe `switch` héritée ;
   - Identité ;
   - Portrait de légende : grille de légendes cliquables, sélection en filet `--blood` ;
   - Email : avec le rappel de vérification existant ;
   - Mot de passe ;
   - Vos données : l'export RGPD ;
   - Zone sensible : un `RiftPanel` avec l'accent sang. La suppression passe par une `RiftModal` de confirmation, avec saisie du pseudo ou du mot de passe si c'est déjà le cas.

   Les champs utilisent `RiftField` (avec `type="email"` et `type="password"`, `autocomplete` conservés). Les boutons de formulaire sont en `RiftButton`, et les messages de succès ou d'erreur en `role="status"` ou `role="alert"`.
3. Mise en page : deux colonnes au-dessus de 1 024 px (hauts faits et confidentialité à gauche, compte à droite), une seule en dessous.

- [ ] **Step 1 : tests.**
  - Migrer les cas de `ProfileView.spec`.
  - Ajouter :
    - « suppression : modale de confirmation, double clic → une seule requête » ;
    - « mot de passe : erreur affichée sur place, bouton réactivé » ;
    - « confidentialité : bascule envoie la valeur et reflète aria-pressed / checked » ;
    - « pseudo long : ellipse ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : profil Forgé`.

---

### Task 5 : profil public et amis

**Files :** Modify `src/views/PublicProfileView.vue`, `src/views/FriendsView.vue` et leurs specs.

**Profil public** :
- Le même en-tête `profil-hero`, en lecture, avec les actions existantes : suivre / ne plus suivre, inviter si c'est déjà le cas.
- Sections en `RiftPanel` :
  - **Hauts faits** : médailles et progression ;
  - **Duels** : `RiftStat`, puis les derniers `MatchRow` ;
  - **Collection** : `RiftStat`, puis la progression par set (barres Forgées, comme le classeur de la PR 4) ;
  - **Decks publics** : `DeckCard readonly` dans la grille `profil-decks-grid` (PR 5).
- Une section masquée par la confidentialité n'apparaît pas.
- Profil introuvable ou privé : `RiftEmpty` avec le message existant.

**Amis** :
- `h1` « Mes amis ».
- « Trouver un joueur » : `RiftField search` avec les résultats en lignes `amis-row` (avatar, pseudo avec ellipse, bouton Suivre / Suivi), en gardant le debounce existant.
- « Je suis » / « Ils me suivent » : deux `RiftPanel` avec un compteur dans le titre. Chaque ligne affiche l'avatar, le pseudo (lien vers le profil), « Inviter dans un salon » et « Ne plus suivre ».
- L'invitation garde son panneau « Salon pour {pseudo} » avec ses actions. Le passer en `RiftModal` seulement s'il était déjà modal ; sinon le garder en ligne, rhabillé.
- États vides : un `RiftEmpty` par liste.

- [ ] **Step 1 : tests.**
  - Migrer les cas de `PublicProfileView.spec` et `FriendsView.spec`.
  - Ajouter :
    - « profil privé : RiftEmpty, pas de squelette » ;
    - « duels masqués par la confidentialité : section absente » ;
    - « double clic sur Suivre : une seule requête » ;
    - « pseudo long : ellipse ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : profil public et amis Forgés`.

---

### Task 6 : nettoyage et documentation

**Files :** Modify `src/assets/main.css`, `src/assets/cssCoverage.spec.js` si besoin, la spec, et `riftarium/apps/web/README.md` si la liste des dossiers change (`src/play/`, `src/social/`).

- [ ] **Step 1 : retirer de `main.css` les tranches devenues inutiles.**
  - Repères :
    - « Profil » (`profile-*`, `avatar*`) ;
    - le bloc jeu : « Pastilles partagées », « Vignette de légende », « Historique », « État vide », « Statistiques », « Salon » ;
    - amis ;
    - les lignes de progression des profils ;
    - les médailles ;
    - leurs paliers responsive.
  - **Règle de sûreté** : avant de supprimer un sélecteur, cherche chacune de ses classes dans `src`, hors `main.css` (grep sur les `.vue` et `.js`, y compris les classes dynamiques et `classList`). Une classe encore utilisée garde sa règle.
  - **Attention à `AdminView`** (PR 8). Il utilise des classes de tableau de bord (`chart-*`, `stat`, `kpi`…) qui doivent rester tant qu'il n'est pas refait.
  - Lister dans le rapport ce qui est supprimé et ce qui est gardé, avec la raison.
- [ ] **Step 2 : `PageBanner`.** Le supprimer avec `BANNERS` si plus rien ne s'en sert. Sinon, noter qui l'utilise encore.
- [ ] **Step 3 : spec.**
  - §5 PR 7 : ajouter une puce « Livré » qui décrit `src/play/` et `src/social/`, les couleurs du jeu, les graphiques par tokens (API inchangée, admin compris) et les préfixes.
  - Rappeler que les contrats `docs/suivi-des-matchs.md` et `docs/profils-et-hauts-faits.md` sont inchangés.
- [ ] **Step 4 : vérifier.** `npm run check` vert. Grep : aucun gabarit n'utilise une classe dont la règle a été supprimée.
- [ ] **Step 5 : commits.** `Web : nettoyage des styles hérités du jeu et du social`, puis `Docs : spec — PR 7 jeu et social livrée`.

---

## Validation locale (après la revue finale, avant tout push)

À montrer au mainteneur sur `http://localhost:8888`, avec les données de test : parties confirmées de l'admin contre Kael. Ajouter au script de seed un salon ouvert et des abonnements si nécessaire.

1. **`/salon`** :
   - saisie d'un code ;
   - un salon ouvert : joueurs face à face, choix de légende et de deck, prêt ;
   - une partie avec score et confirmation.
2. **`/historique`** et **`/statistiques`** :
   - liste, graphiques, tableaux et jauges ;
   - compte vide (`testeur_vide`).
3. **`/profil`** : toutes les sections, la confidentialité et la modale de suppression (sans confirmer).
4. **`/u/Kael`** et **`/u/admin`** : hauts faits, duels, collection et decks publics.
5. **`/amis`** : recherche, suivre, inviter.
6. **Téléphone (390 px)** pour chacune de ces pages.
