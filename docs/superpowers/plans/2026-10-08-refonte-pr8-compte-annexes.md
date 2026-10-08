# Refonte Forge noxienne — PR 8 : compte, pages annexes, administration, fin de `main.css` — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** passer en style Forgé les dernières pages et composants hérités, sans perdre aucune fonction, puis **supprimer `src/assets/main.css`**. Sont concernés :
- connexion et inscription ;
- mot de passe oublié et réinitialisation ;
- vérification d'e-mail ;
- pages légales ;
- page 404 ;
- administration ;
- bandeaux globaux ;
- aperçu de carte au survol.

**Architecture :**
- **Fondations encore fournies par `main.css`** : elles passent dans `src/styles/` (`base.css`, ou un nouveau `layout.css`) avec les mêmes noms, pour ne pas toucher les pages déjà refaites. Concrètement :
  - les conteneurs de mise en page `.wrap` et `.cards-wrap` ;
  - la classe de corps `drag-active` ;
  - les styles d'éléments de base que `base.css` ne couvre pas encore.
- **Pages et composants restants** : ils sont refaits avec `src/ui/`.
  - L'administration est découpée dans `src/admin/`, un composant par onglet.
  - Les pages de compte vont dans `src/account/`, avec un gabarit commun posé sur le splash.
- **Fin** :
  - les directives `v-tilt` et `v-reveal` de `main.js` disparaissent, avec le `components/CardTile.vue` mort ;
  - `PageBanner` disparaît avec ses derniers usages ;
  - `main.css` est supprimé ;
  - `cssCoverage.spec.js` vérifie désormais toute classe statique contre les seules feuilles de `src/styles/` et les styles des composants.

**Tech Stack :** Vue 3.5, vue-router 5, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§3, §4.6, §5 PR 8, §8)

## Global Constraints

- **Branche :** `feat/refonte-compte-annexes`, créée depuis `refonte/forge` (c19a15d). La PR vise `refonte/forge`. Aucun push sans validation locale du mainteneur.
- **Langue :** français pour les commentaires, l'interface et les commits. Identifiants en anglais.
- **Commits :** `Web : …` ou `Docs : …`, puis une ligne vide, puis `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Vérification :** `npm run check` vert (lint, format:check, test, build) avant chaque commit, depuis `riftarium/apps/web`.
- **Composants disponibles :**
  - `src/ui/` :
    - `RiftButton` (primary / secondary / ghost, sm / md ; sm fait 44 px au tactile) ;
    - `RiftField` (`search`, `type`, `error`, `hide-label`, v-model ; transmet `$attrs` à l'input) ;
    - `RiftChoice`, `RiftChip` (`selected`, `static`) ;
    - `RiftSegments` (onglets dans une page) ;
    - `RiftPanel` (`title`, `accent`), `RiftEmpty`, `RiftSkeleton`, `RiftStat`, `RiftModal`, `RiftSheet` ;
    - `CardTile` (racine `rift-tile`).
  - Composants hérités à rhabiller ou à retirer : `src/components/charts/*`, `UserAvatar`, `Icon` et `Logo`.
  - Accueil : `src/home/HomeSplash.vue`, le splash d'accueil.
  - `useBreakpoint`, et `fold` de `src/search/search.js`.
  - Modèles de mise en page des pages déjà refaites : `src/views/DecksView.vue`, `src/views/ProfileView.vue`, `src/social/ProfileHero.vue`.
  - Tokens : voir `src/styles/tokens.css`. L'encre rouge des textes est `--blood-text` ; le rouge vif est réservé aux grands titres.
- **Leçon des PR précédentes (obligatoire) :** tant que `main.css` existe (jusqu'à la tâche 5), il est chargé APRÈS `src/styles/*`. Il fuit sur tout nom de classe qu'il connaît, ainsi que sur `h1`, `h2`, `h3`, `section`, `input`, `select`, `textarea`, `table`, `th` et `td`.
  - Préfixes réservés à cette PR, absents de `main.css` (vérifiés) : `acces-` (pages de compte), `mentions-` (pages légales), `perdu-` (404), `console-` (administration), `bandeau-` (bandeaux globaux), `apercu-` (aperçu de carte).
  - Vérifier par grep toute classe nouvelle.
  - Neutraliser localement les balises héritées, comme dans les PR précédentes.
- **Pas de `PageBanner`** ni de `v-reveal` / `v-tilt` sur les pages refaites. Le `h1` est dans la page.
- **Accessibilité :**
  - cibles de 44 px, focus visible en `--bronze-light` (outline rentrant d'au moins -6 px sur les éléments en `clip-path`) ;
  - erreurs en `role="alert"`, succès en `role="status"` ;
  - formulaires avec un `autocomplete` correct (`username`, `email`, `current-password`, `new-password`).
- **Comportements conservés :** tous les cas des specs `AuthView`, `ForgotPasswordView`, `ResetPasswordView`, `VerifyEmailView`, `LegalView`, `NotFoundView`, `AdminView`, `AdminGateView`, `EmailVerifyNotice`, `TraceursNotice`, `CardHoverPreview`, `PageBanner` (supprimé avec le composant) et `App`, migrés sans perte d'intention. Notamment :
  - bêta fermée et code d'invitation, si c'est le cas ;
  - acceptation des CGU ;
  - redirection `suite=` après connexion ;
  - limites de débit et messages ;
  - jeton de réinitialisation et de vérification ;
  - consentement aux traceurs ;
  - porte admin qui rend la 404 ;
  - modération et sanctions de l'admin.
- **Aucun changement d'API.**

## Review Focus

- **Formulaires de compte sous erreur réseau ou 429 :** le message s'affiche, le bouton se réactive, la saisie est conservée (sauf les mots de passe après succès), et un double envoi ne part qu'une fois. Testé en tâche 2.
- **Suppression de `main.css` :** aucune page déjà refaite ne perd un style dont elle dépendait sans le savoir (`.wrap`, `.cards-wrap`, éléments de base, `drag-active`, focus, sélection de texte, barre de défilement). Testé par `cssCoverage` en tâche 5 et vérifié visuellement à la validation.
- **Administration :** une action de modération ou de sanction échoue → l'erreur s'affiche sur la ligne concernée, l'état ne change pas. Une sanction définitive demande une confirmation. Testé en tâche 4.
- **Bandeaux globaux :** l'e-mail non vérifié, le mode hors ligne et les traceurs ne masquent pas le contenu sur téléphone. Le bandeau des traceurs reste utilisable au clavier et se ferme une fois le choix fait. Testé en tâche 1.
- **404 et porte admin :** un visiteur non admin sur `/admin` voit exactement la 404 (même titre, même texte). Testé en tâche 3.

---

### Task 1 : fondations et composants transverses

**Files :**
- Modify : `src/styles/base.css`, ou Create : `src/styles/layout.css`, importé dans `main.js` après `base.css`.
- Modify : `src/main.js` (retirer `v-tilt` et `v-reveal`).
- Delete : `src/components/CardTile.vue` et sa spec, après avoir vérifié par grep qu'ils ne sont plus importés.
- Move et rewrite :
  - `src/components/EmailVerifyNotice.vue` → `src/shell/EmailVerifyNotice.vue` ;
  - `src/components/TraceursNotice.vue` → `src/shell/TraceursNotice.vue` ;
  - `src/components/CardHoverPreview.vue` → `src/ui/CardHoverPreview.vue`.

  Utiliser `git mv` et mettre les imports à jour.
- Modify : `src/App.vue`, pour l'avis hors ligne (classe `verify-notice` héritée).

**Interfaces :**
- **Fondations.** Recopier dans `src/styles/` les règles de `main.css` encore utilisées par les pages refaites, avec les mêmes noms de classes :
  - `.wrap` et `.cards-wrap` (largeur maximale et gouttières, mêmes valeurs) ;
  - `body.drag-active` ;
  - les styles d'éléments de base absents de `base.css`. Comparer `main.css` (sections « Typographie », « Formulaires », `section`, `table`) avec `base.css`, et ne reprendre que ce qui sert encore, en version Forgée (fonds `--bg-sunken`, filets `--line`, focus `--bronze-light`).
  - **Ne pas** recopier les styles des classes de composants hérités (`btn`, `panel`, `filter`…) : les tâches 2 à 4 les remplacent.
  - Dans le rapport, lister chaque règle déplacée et sa source.
- **Bandeaux** (spec §4.6). `EmailVerifyNotice`, l'avis hors ligne de `App.vue` et `TraceursNotice` deviennent des bandeaux Forgés en haut du contenu (`bandeau-*`) :
  - fond `--bg-raised`, filet gauche de 3 px (bronze pour l'information, sang pour l'action requise) ;
  - texte en Barlow ;
  - actions en `RiftButton sm`.

  `TraceursNotice` garde toute sa logique (consentement, version courte ou détaillée, mémorisation).
- **`CardHoverPreview`** : même API, styles scoped `apercu-*` (illustration, texte de carte via `RiftText`, reflet foil sous reduced-motion coupé).
- **`main.js`** : retirer les deux directives, et vérifier par grep qu'aucun gabarit ne les utilise plus.

- [ ] **Step 1 : tests.**
  - Migrer les specs `EmailVerifyNotice`, `TraceursNotice` et `CardHoverPreview`.
  - Ajouter :
    - « bandeau traceurs : focus dans le bandeau, choix mémorisé, bandeau fermé » ;
    - « avis hors ligne : role=status » ;
    - « App : aucune directive v-reveal / v-tilt enregistrée ».
- [ ] **Step 2 à 4 :** échec, code, succès.
- [ ] **Step 5 :** commit `Web : fondations de mise en page et bandeaux globaux Forgés`.

---

### Task 2 : pages de compte

**Files :**
- Create : `src/account/AccessLayout.vue` (gabarit commun) et sa spec.
- Modify :
  - `src/views/AuthView.vue` ;
  - `src/views/ForgotPasswordView.vue` ;
  - `src/views/ResetPasswordView.vue` ;
  - `src/views/VerifyEmailView.vue` ;
  - et leurs specs.

**Interfaces :**
- **`<AccessLayout :title :kicker?>`** : la page sur le splash (spec §5 PR 8), avec un slot par défaut.
  - L'illustration du splash d'accueil sert de fond plein écran voilé. Lire `src/home/HomeSplash.vue` pour reprendre la source et le voile sans dupliquer la logique. Si le splash expose ses images dans `homeData.js`, les réutiliser.
  - Un `RiftPanel` centré de 440 px au plus contient le `h1` (neutralisé) et le slot.
  - Sur téléphone, le panneau prend toute la largeur avec des gouttières de 16 px.
- **AuthView (connexion et inscription) :**
  - bascule Connexion / Créer un compte en `RiftSegments`, en gardant la synchronisation avec l'URL si elle existe ;
  - champs `RiftField` (pseudo, e-mail, mot de passe, confirmation, code d'invitation en bêta fermée…), avec un `autocomplete` correct ;
  - case d'acceptation des CGU (case native libellée, lien vers les mentions) ;
  - bouton primary « Se connecter » ou « Créer mon compte », désactivé pendant l'envoi ;
  - lien « Mot de passe oublié ? » ;
  - écran « Compte créé » avec « Continuer » ;
  - messages en `role="alert"` ou `role="status"`.

  La logique est conservée telle quelle : redirection `suite=`, `CLOSED_BETA`, vérification, session.
- **ForgotPasswordView, ResetPasswordView et VerifyEmailView** : même gabarit et mêmes messages. Le jeton est lu dans l'URL ; un jeton absent ou invalide donne un message clair avec un lien de retour.
- `PageBanner` n'est plus importé dans ces quatre vues.

- [ ] **Step 1 : tests.**
  - Migrer tous les cas des quatre specs.
  - Ajouter :
    - « double envoi : une seule requête » ;
    - « 429 : message, bouton réactivé, pseudo conservé » ;
    - « autocomplete : current-password à la connexion, new-password à l'inscription » ;
    - « réinitialisation sans jeton : message et lien ».
- [ ] **Step 2 à 4 :** échec, code, succès.
- [ ] **Step 5 :** commit `Web : pages de compte Forgées (connexion, mot de passe, vérification)`.

---

### Task 3 : pages légales et 404

**Files :**
- Modify : `src/views/LegalView.vue`, `src/views/NotFoundView.vue` et leurs specs.
- Delete : `src/components/PageBanner.vue` et sa spec, si plus rien ne l'importe. `BANNERS` (`banners.js`) reste tant que `seo.js` et `homeData.js` l'utilisent.

**Interfaces :**
- **LegalView** (mentions, CGU, confidentialité, cookies selon `legal.js`) :
  - `h1`, puis une mise en page `mentions-layout` : sommaire collant à gauche sur bureau (liens vers les sections, `aria-current`), texte à droite ; sous 1 024 px, le sommaire passe dans un `details` en haut ;
  - typographie de lecture : Barlow 17 px, interligne 1,65, titres en Cinzel ;
  - citations en encart ;
  - date de mise à jour.
  - Même contenu, mêmes ancres.
- **NotFoundView** :
  - fond sombre avec un grand « 404 » en Cinzel `--blood-bright` ;
  - le texte existant ;
  - « Retour à l'accueil » en `RiftButton primary` ;
  - un lien « Chercher une carte » vers `/cartes`.

  La porte admin (`AdminGateView`) rend ce même composant : on garde l'égalité stricte de titre et de texte.

- [ ] **Step 1 : tests.**
  - Migrer les cas existants.
  - Ajouter :
    - « mentions : sommaire avec aria-current, ancres conservées » ;
    - « 404 : lien accueil et lien cartes » ;
    - « porte admin : rend la 404 à l'identique » (si absent).
- [ ] **Step 2 à 4 :** échec, code, succès.
- [ ] **Step 5 :** commit `Web : pages légales et 404 Forgées`.

---

### Task 4 : administration (dense et utilitaire)

**Files :**
- Create :
  - `src/admin/AdminStats.vue` ;
  - `src/admin/AdminUsers.vue` ;
  - `src/admin/AdminDecks.vue` ;
  - si utile, `src/admin/useAdmin.js` (appels et états).
- Modify : `src/views/AdminView.vue` (794 lignes) et sa spec. Découper la spec par onglet si c'est plus clair.

**Interfaces :**
- **La page :**
  - `h1` « Administration » ;
  - `RiftSegments` Statistiques / Utilisateurs / Decks, à la place des boutons `filter` ;
  - un composant par onglet. La logique réseau est déplacée sans changement : statistiques, recherche et filtres d'utilisateurs, sanctions avec durées, modération des decks avec statuts, pagination.
- **Densité utilitaire** (spec §5 PR 8) :
  - tableaux compacts `console-table` (lignes de 40 px sur bureau, 44 px au tactile) ;
  - en-têtes en Barlow Condensed ;
  - statuts en `RiftChip static` aux couleurs : publié `--bronze-light`, en attente `--ink-muted`, rejeté `--blood-text` ;
  - actions en `RiftButton sm`.
  - Sous 768 px, chaque ligne devient une carte empilée.
- **Graphiques** : ils gardent leur API. Les couleurs viennent des tokens et les variables `--chart-*` locales à l'admin disparaissent :
  - volume `--bronze`, victoires `--blood`, troisième série `--ink-muted` ;
  - statuts : ok `--bronze-light`, attente `--ink-muted`, ko `--blood`.
- **Sanction définitive** : confirmation par `RiftModal`. On garde cette confirmation si elle existait, et on l'ajoute sinon (le Review Focus l'exige).
- **Erreur d'action** : affichée sur la ligne concernée (`role="alert"`), sans changer l'état.

- [ ] **Step 1 : tests.**
  - Migrer tous les cas de `AdminView.spec`.
  - Ajouter :
    - « sanction définitive : modale de confirmation, annuler n'envoie rien » ;
    - « modération en échec : erreur sur la ligne, statut inchangé » ;
    - « onglets : RiftSegments au clavier » ;
    - « graphiques : couleurs en tokens, aucune var(--chart-…) ».
- [ ] **Step 2 à 4 :** échec, code, succès.
- [ ] **Step 5 :** commit `Web : administration Forgée (dense et utilitaire)`.

---

### Task 5 : suppression de `main.css` et documentation

**Files :**
- Delete : `src/assets/main.css`.
- Modify :
  - `src/main.js` (import retiré) ;
  - `src/assets/cssCoverage.spec.js` ;
  - la spec ;
  - `riftarium/apps/web/README.md` ;
  - `WORKFLOW.md` (§7 cite encore « la charte du site (`apps/web/src/assets/main.css`) ») ;
  - `CLAUDE.md` et `.cursor/rules/riftarium.mdc`, s'ils citent `main.css`.

- [ ] **Step 1 : inventaire final.** Pour chaque classe de `main.css`, chercher les usages restants dans `src` (gabarits, chaînes JS, `classList`, `index.html`). Toute classe encore utilisée doit avoir une règle ailleurs (`src/styles/` ou un style scoped), ou bien disparaître du gabarit. Lister le résultat dans le rapport. Aucune classe utilisée ne doit rester sans règle.
- [ ] **Step 2 : supprimer** l'import et le fichier.
- [ ] **Step 3 : `cssCoverage.spec.js`.** Il ne lit plus `main.css`. Il vérifie que chaque classe statique d'un gabarit a une règle dans `src/styles/*.css`, dans une feuille `.css` de `src`, ou dans le style du composant. La liste d'exceptions est réduite au strict nécessaire, avec une justification pour chaque entrée. Ajouter un test « main.css n'existe plus et n'est importé nulle part ».
- [ ] **Step 4 : documentation.**
  - Spec : puce « Livré » du §5 PR 8. Préciser au §3.1 que `src/styles/` porte les fondations, et noter que `main.css` n'existe plus.
  - WORKFLOW §7 : la charte de référence pour le mobile devient `apps/web/src/styles/tokens.css` et la spec.
  - README web : retirer toute mention de `main.css`.
- [ ] **Step 5 :** `npm run check` vert. Commits `Web : suppression de main.css` et `Docs : refonte Forge noxienne terminée (PR 8)`.

---

## Validation locale (après la revue finale, avant tout push)

À montrer au mainteneur sur `http://localhost:8888` :

1. **Visiteur** :
   - connexion et inscription, avec les erreurs : mauvais mot de passe, puis pseudo déjà pris ;
   - mot de passe oublié ;
   - `/reinitialiser` sans jeton ;
   - mentions légales et CGU ;
   - une URL inconnue (404) ;
   - `/admin` (404) ;
   - bandeau des traceurs.
2. **Connecté (admin)** :
   - `/admin` : les trois onglets, une modération et une sanction annulée ;
   - bandeau de vérification d'e-mail, si le compte n'est pas vérifié.
3. **Tour complet du site**, pour repérer une régression due à la suppression de `main.css` :
   - accueil, cartes et fiche ;
   - collection et wishlist ;
   - decks et éditeur ;
   - règles ;
   - salon, statistiques, profil, amis.

   À faire à 1 440 px puis à 390 px.
