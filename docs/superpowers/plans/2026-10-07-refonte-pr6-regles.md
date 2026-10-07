# Refonte Forge noxienne — PR 6 : règles — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** refaire en style Forgé les pages de règles, sans rien perdre de leurs fonctions ni de leur contenu :
- `/regles` : le hub ;
- `/regles/debutant/:slug` : le guide en chapitres ;
- `/regles/debutant/plateau` : le plateau animé ;
- `/regles/avancee` et `/regles/avancee/:slug` : l'aide avancée et ses sujets ;
- `/regles/officielles` : le texte officiel.

**Architecture :**
- Les données ne changent pas : `rules/learn.js`, `rules/guide.js`, `rules/topics.js`, `rules/rulesStore.js` et `data/rules-fr.json`. Le mobile les exporte, donc on ne touche à aucune donnée.
- Les pages passent sur `src/ui/`. Trois pièces communes sont créées :
  - `RiftText` sait rendre les renvois « règle 123.4 » en boutons (option `refs`) ;
  - `src/rules/CardZoom.vue` remplace les quatre copies de la superposition `tb-zoom` ;
  - `src/rules/RulesHeader.vue` fournit l'en-tête de page (`h1`, sur-titre et filet), à la place de `PageBanner`.
- Le plateau est extrait dans `src/rules/TableBoard.vue`, avec son CSS en style scoped. Le CSS sort de `main.css`.
- Le texte officiel utilise `RiftText` à la place du `v-html` maison.

**Tech Stack :** Vue 3.5, vue-router 5, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§3.3, §3.4, §5 PR 6, §8)

## Global Constraints

- **Branche** : `feat/refonte-regles`, créée depuis `refonte/forge` (84bae80). La PR vise `refonte/forge`. Rien n'est poussé sans validation locale du mainteneur.
- **Langue** : français pour les commentaires, l'interface et les commits. Identifiants en anglais.
- **Commits** : `Web : …` ou `Docs : …`, puis une ligne vide, puis `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Vérification** : `npm run check` vert (lint, format:check, test, build) avant chaque commit, depuis `riftarium/apps/web`.
- **Composants disponibles** :
  - `src/ui/` : `RiftButton`, `RiftField`, `RiftChip` (dont `static`), `RiftChoice`, `RiftSegments`, `RiftPanel`, `RiftEmpty`, `RiftSkeleton`, `RiftModal`, `RiftSheet`, `RiftText` (prop `rules`), `RiftGlyph`, `RiftStat` ;
  - `src/composables/useBreakpoint.js` : `"mobile" | "tablet" | "desktop"` ;
  - `src/composables/useOnline.js` ;
  - tokens dans `src/styles/tokens.css`. L'encre rouge des textes est `--blood-text`, le rouge vif est réservé aux grands titres.
  - Pour la mise en page des pages déjà refaites, voir `src/views/DecksView.vue` (`h1` neutralisé, `wrap cards-wrap`).
- **Leçon des PR précédentes (obligatoire)** : `src/assets/main.css` est hérité et chargé APRÈS `src/styles/*`. Il fuit sur tout nom de classe qu'il connaît, ainsi que sur `h1`, `h2`, `h3`, `section`, `input`, `select`, `textarea`, `button`, `table` et `th`.
  - **Préfixes réservés à cette PR** (absents de `main.css`, vérifié) : `regles-`, `portail-`, `chapitre-`, `lecon-`, `plateau-`, `aide-`, `sujet-`, `scene-`, `officiel-`, `carte-zoom`, `rift-ref`.
  - **Classes héritées interdites** : `tier*`, `learn-*`, `guide-*`, `tb-*`, `topic-*`, `rules-*`, `rule`, `rule-*`, `toc-*`, `rref`, `rtoken`, `eyebrow`, `quick-topic*`, `golden-rule*`, `offline-note`, `panel`, `btn*`, `filter*`, `search`, `m-go`, `mono`, `muted`.
  - Vérifie toute nouvelle classe par grep dans `main.css`.
  - Neutralise localement les balises héritées : `h1` (`background: none; color: var(--ink); animation: none; font-weight: 700`), `h2`, `h3` et `h4` (marges, taille et couleur explicites), `section` (`padding: 0`), `table` et `th`.
  - `cssCoverage.spec.js` doit rester vert.
- **Pas de `PageBanner`** ni de `v-reveal` sur les pages refaites. Le sur-titre et le fil sont portés par `RulesHeader`. La coquille affiche déjà la rubrique dans la barre haute et les onglets de sous-rubriques (Apprendre, Plateau animé, Aide avancée, Texte officiel).
- **Effets** (§3.4) : transitions de 150 à 200 ms. La lecture automatique des mini-scènes et le plateau gardent leur animation, coupée sous `prefers-reduced-motion`. Pas de cascade d'apparition.
- **Texte de jeu** : `RiftText rules` partout (glyphes Riot, mots-clés en pastille, `**gras**`). Plus aucun `v-html` dans les pages de règles. Seule exception : le plateau et ses `step.text`, qui passent eux aussi par `RiftText` (le `**gras**` y est pris en charge).
- **Accessibilité** :
  - cibles d'au moins 44 px, focus visible en `--bronze-light` ;
  - `aria-current` sur l'élément courant des sommaires ;
  - le zoom de carte est un vrai dialogue : focus piégé, Échap, retour du focus.
- **Comportements conservés** : tous les cas des specs `RulesHubView`, `RulesView`, `LearnGuideView`, `BeginnerGuideView`, `AdvancedHelpView`, `AdvancedTopicView` et `TopicDemo`, migrés sans perte d'intention. On garde aussi :
  - les redirections : `/regles?doc=…` vers `/regles/officielles`, `?etape=` vers le plateau, chapitre par défaut ;
  - `?etape=` comme mémoire du plateau ;
  - le plein écran ;
  - la recherche accent-insensible ;
  - les renvois cliquables entre règles ;
  - la mention « hors ligne ».
- **Aucun changement d'API ni de données.**

## Review Focus

- **Renvoi vers une règle d'un autre document** (règles de tournoi, numéro absent) : le clic va à la bonne section du bon document. Un numéro introuvable ne fait rien et ne lève pas d'erreur. Testé en tâches 1 et 6.
- **Texte officiel sur téléphone** : la table des matières ne pousse pas le texte hors de l'écran. Elle s'ouvre dans une feuille, et choisir une section la ferme puis amène le lecteur sur le texte. Testé en tâche 6.
- **Plateau au clavier et en plein écran** : ← et → changent d'étape seulement quand le focus est sur le plateau, pas dans un champ. Échap ferme d'abord le zoom, puis le plein écran. Quitter la page en plein écran rend la main au navigateur. Testé en tâche 4.
- **Zoom de carte** : le focus revient sur la carte d'origine à la fermeture, et le défilement de la page est bloqué pendant l'ouverture. Testé en tâche 1.
- **Recherche sans résultat ou réduite à un caractère** (aide avancée, texte officiel) : on affiche un état vide clair, pas une liste fantôme. Testé en tâches 5 et 6.

---

### Task 1 : pièces communes (`RiftText` refs, `CardZoom`, `RulesHeader`)

**Files :**
- Modify : `src/ui/richText.js`, `src/ui/RiftText.vue`, `src/ui/RiftGlyph.vue` (si les parties y sont rendues) et leurs specs.
- Create : `src/rules/CardZoom.vue`, `src/rules/CardZoom.spec.js`, `src/rules/RulesHeader.vue`, `src/rules/RulesHeader.spec.js`.

**Interfaces :**
- **`RiftText`, prop `refs`** (booléen, faux par défaut). Quand elle est vraie, les motifs `règle(s)|section(s) NNN(.N…)(.a)` du texte deviennent des `button.rift-ref` avec `type="button"` et `data-ref="<numéro sans point final>"`. Le libellé reste le texte d'origine, par exemple « règle 123.4 ».
  - L'expression régulière est celle de `RulesView.formatText` : `/\b(règles?|sections?)\s+(\d{3}(?:\.\d+)*(?:\.[a-z])?(?:\.\d+)*)/gi`.
  - Le découpage se fait dans `richSegments` (nouvelle option `refs`, nouveau type de partie `ref`). Il passe avant les glyphes et ne casse ni le gras ni les mots-clés.
  - Le composant n'émet rien : la page délègue le clic sur `[data-ref]`, comme aujourd'hui.
  - Style : souligné pointillé `--bronze-light`, cible de 44 px en hauteur sous `(hover: none)`, focus visible.
- **`<CardZoom :card="{ name, img }" @close />`**, rendu dans une `RiftModal`. Le titre est le nom de la carte, visuellement masqué si la modale le permet ; sinon on l'affiche, c'est acceptable.
  - Contenu : l'image `cardThumb(card.img, 1024)` (`alt` = nom), à 90 % de la hauteur de la fenêtre au maximum.
  - Un clic sur l'image ferme. Échap, le fond et le focus sont gérés par `useDialog`.
  - La page garde l'élément déclencheur pour lui rendre le focus. `useDialog` le fait-il déjà ? Vérifier, et sinon l'ajouter dans `CardZoom` (`document.activeElement` mémorisé à l'ouverture).
- **`<RulesHeader :title :kicker? :crumbs="[{ label, to? }]" />`** :
  - `nav aria-label="Fil d'Ariane"` avec des liens, le dernier élément sans lien et en `aria-current="page"` ;
  - `h1.regles-title` en Cinzel, `clamp(26px, 4vw, 40px)`, neutralisé ;
  - le sur-titre `kicker` en Barlow Condensed capitales `--bronze-light` ;
  - un filet bronze dégradé sous le titre ;
  - un slot par défaut, sous le titre (méta, recherche).

- [ ] **Step 1 : tests.**
  - `richText.spec` :
    - « refs : règle 123.4 devient une partie ref » ;
    - « sections 103 et 104 » ;
    - « sans l'option, rien ne change » ;
    - « une ref dans du gras reste en gras ».
  - `RiftText.spec` : « refs : button.rift-ref avec data-ref ».
  - `CardZoom.spec` :
    - « dialogue avec image grande taille et alt » ;
    - « Échap émet close » ;
    - « clic sur l'image émet close » ;
    - « le focus revient au déclencheur ».
  - `RulesHeader.spec` : « fil d'Ariane avec aria-current et h1 ».
- [ ] **Step 2 à 4** : vérifier l'échec, écrire le code, vérifier le succès.
- [ ] **Step 5** : commit `Web : pièces communes des règles (renvois, zoom de carte, en-tête)`.

---

### Task 2 : hub des règles (`/regles`)

**Files :** Modify `src/views/RulesHubView.vue` et `RulesHubView.spec.js`.

**Gabarit** (`div.wrap.cards-wrap.regles-hub`) :
1. `RulesHeader`, titre « Règles », sur-titre « Riftbound ». Si le site est hors ligne, un `p.regles-offline` avec `role="status"` : « Hors ligne — règles servies depuis le cache ».
2. **Trois portails** `portail` (les `TIERS` actuels, mêmes textes et mêmes liens) :
   - grille : le premier occupe toute la largeur, les deux autres côte à côte ; une colonne sous 768 px ;
   - chaque portail est un `RouterLink` Forgé : angles coupés, filet `--line`, liseré gauche de 3 px `--blood` sur le premier et `--bronze` sur les autres ;
   - contenu : le chiffre romain en Cinzel 48 px `--bronze` (`aria-hidden`), le sur-titre, un `h2` (neutralisé), le texte, puis l'action « Ouvrir le guide → » ;
   - au survol ou au focus : filet `--bronze-light` et translation de 2 px, coupée sous reduced-motion.
3. **« Chapitres du guide »** : un `h2` et une grille des 6 premiers chapitres. Chaque chapitre est un lien avec son numéro en Cinzel, son titre et son résumé, et une case « + Tous les chapitres ».
4. **« Accès rapide »** : les 8 sujets sous forme de liens en puce (style `RiftChip`, mais rendus en `RouterLink`, classe `regles-quick`).
5. **Plaque « Règle d'or »** : bloc Forgé avec le sur-titre « Règle 002 — la Règle d'or » et la citation en Cinzel italique.

La logique est conservée : redirection des anciens liens `?doc`, `?section` et `?rule`.

- [ ] **Step 1 : tests.** Migrer les 2 cas existants et ajouter :
  - « trois portails avec les bons liens, le premier en pleine largeur (classe) » ;
  - « hors ligne : statut affiché » ;
  - « accès rapide : 8 liens vers /regles/avancee/… ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : hub des règles Forgé`.

---

### Task 3 : guide en chapitres (`/regles/debutant/:slug`)

**Files :**
- Modify : `src/views/LearnGuideView.vue` et sa spec.
- Create : `src/rules/LessonBlock.vue` et sa spec, le rendu d'un bloc.
- Move et rewrite : `src/components/LearnRuneDemo.vue` vers `src/rules/LearnRuneDemo.vue` (`git mv`, avec sa spec si elle existe).

**Interfaces :**
- **`<LessonBlock :block @zoom="card" />`** rend un bloc de `learn.js` : `h`, `p`, `stat`, `ul`, `ol`, `table`, `note` (`kind`), `steps`, `compare`, `abcd`, `types`, `loop`, `runes`. Mêmes contenus qu'aujourd'hui, avec `RiftText rules` pour tous les textes.
  - Les `types` gardent leur sélection interne. Le double clic, ou un bouton « Agrandir » visible au clavier, émet `zoom`. On ajoute ce bouton, car le double clic seul n'est pas accessible.
  - Préfixe `lecon-`. Styles : `note` en panneau à liseré (`tip` bronze, `warn` sang) ; tableau neutralisé (bordures `--line`, en-têtes Barlow Condensed) ; `steps` et `abcd` numérotés en Cinzel.
- **La page** :
  - `RulesHeader` avec le fil Règles › Apprendre à jouer › Chapitre N / total, et le titre du chapitre en sur-titre `kicker` ;
  - à gauche, un sommaire collant `chapitre-toc` (`nav aria-label="Chapitres du guide"`, numéro, titre et sous-titre, `aria-current="page"` sur le chapitre courant), puis « Voir sur le plateau → » ;
  - au centre, l'article : `lead` en Barlow 19 px, les `LessonBlock`, le lien « Règle N ↗ », puis la pagination « ← précédent » (`RiftButton ghost`) et « suivant → » (`RiftButton primary`, « Voir sur le plateau → » au dernier chapitre) ;
  - sous 1 024 px, le sommaire devient un `details` « Chapitres (N) » au-dessus de l'article.
- **Zoom** : `CardZoom`, qui remplace la superposition locale. La gestion `nav-locked` est retirée si `RiftModal` bloque déjà le défilement ; à vérifier.
- **`LearnRuneDemo`** : même logique, rhabillé (préfixe `lecon-runes`), et son zoom passe par `CardZoom`.
- **Conservé** : SEO, redirection `?etape=`, chapitre par défaut, chapitre introuvable (passe en `RiftEmpty`).

- [ ] **Step 1 : tests.**
  - Migrer les 6 cas de `LearnGuideView.spec`.
  - `LessonBlock.spec` :
    - « chaque type de bloc rend son contenu » (un cas par famille : liste, tableau, note, comparaison, types) ;
    - « types : bouton Agrandir émet zoom ».
  - Page : « sommaire : aria-current sur le chapitre courant » et « chapitre introuvable : RiftEmpty avec lien de retour ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : guide en chapitres Forgé`.

---

### Task 4 : plateau animé (`/regles/debutant/plateau`)

**Files :**
- Create : `src/rules/TableBoard.vue` et `src/rules/TableBoard.spec.js`.
- Modify : `src/views/BeginnerGuideView.vue` et sa spec.

**Interfaces :**
- **`<TableBoard :scene :spots :cards @zoom="card" />`** rend exactement le plateau actuel (`div.tb` et ses enfants) : bases, défausses, zones, champs de bataille contestés ou contrôlés, main adverse, pistes de score, flèche SVG, combat, cartes (`TransitionGroup`), gros plan annoté, réserve runique.
  - Le CSS du plateau (`tb-*` dans `main.css`, sections « Guide du débutant : table de jeu », « Panneau d'explications », « Plein écran ») est **déplacé** en style scoped et **renommé** avec le préfixe `plateau-`.
  - Les classes d'état sont préfixées aussi : `plateau-card--tapped`, `--dead`, etc.
  - Il est **rhabillé** en Forge :
    - tapis `--bg-sunken` avec un motif de filets bronze très discret ;
    - zones en pointillés `--line` ;
    - gemmes de score `--blood` pour vous, `--bronze` pour l'adversaire ;
    - champ contesté avec halo `--blood`, champ contrôlé avec filet `--bronze-light` ;
    - flèche `--bronze-light` ;
    - réserve : énergie en glyphe Riot `energy_1`, essence en glyphe de rune quand c'est possible (sinon on garde le ✦).
  - Le zoom ne vit plus dans le plateau : le composant émet `zoom`.
- **La page** :
  - `RulesHeader` « Sur le plateau » ;
  - une mise en page `plateau-layout` : le plateau (avec son défilement horizontal sous 560 px) et, à droite (dessous sous 1 024 px), le panneau `plateau-panel` ;
  - le panneau contient :
    - le compteur « Étape N / total — titre » ;
    - Plein écran, avec `aria-pressed` ;
    - Précédent (ghost) et Suivant (primary), puis « Passer à l'aide avancée → » à la fin ;
    - les points d'étape (boutons de 12 px dans une cible de 44 px sous `(hover: none)`, `aria-current`) ;
    - le titre ;
    - les termes en `RiftChip static` ;
    - le texte de l'étape en liste, avec `RiftText rules` (le `**gras**` y est pris en charge) ;
    - le lien « Règle N ↗ » ;
  - en bas, deux `RiftPanel` : « Guide en chapitres » et « Aide avancée ».
- **Conservé tel quel** :
  - `?etape=` dans les deux sens, avec sa garde anti-boucle ;
  - les flèches clavier sur le conteneur focalisable ;
  - Échap : zoom d'abord, puis plein écran ;
  - l'API Fullscreen avec repli ;
  - la sortie du plein écran au démontage.

- [ ] **Step 1 : tests.**
  - Migrer les 8 cas de `BeginnerGuideView.spec`.
  - `TableBoard.spec` :
    - « scène : cartes placées aux bons pourcentages » ;
    - « champ contesté : classe » ;
    - « clic sur une carte face visible émet zoom, pas sur une face cachée » ;
    - « score : gemmes remplies ».
  - Page :
    - « flèches ignorées quand la cible est un champ » (si un champ existe ; sinon tester l'événement venant d'un bouton) ;
    - « Échap ferme le zoom avant le plein écran ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : plateau animé Forgé`.

---

### Task 5 : aide avancée (`/regles/avancee` et `/regles/avancee/:slug`)

**Files :**
- Modify : `src/views/AdvancedHelpView.vue`, `src/views/AdvancedTopicView.vue` et leurs specs.
- Move et rewrite : `src/components/TopicDemo.vue` vers `src/rules/TopicDemo.vue` avec sa spec (`git mv`).

**Liste** :
- `RulesHeader` « Aide avancée », avec dans le slot un `RiftField search` « Rechercher une mécanique » (placeholder inchangé).
- Puis une section par catégorie : un `h2` avec le compteur, et des lignes `aide-row` (titre en Barlow Condensed, résumé `--ink-muted`, flèche), chacune en `RouterLink` de 44 px minimum.
- Recherche vide de résultats : `RiftEmpty` « Aucune mécanique ne correspond », avec un lien vers le texte officiel.
- En bas : `RiftButton secondary` « Chercher dans les règles officielles ».

**Sujet** :
- `RulesHeader`, avec le titre du sujet et le fil Règles › Aide avancée › Catégorie. Les mots-clés sont des pastilles `rb-kw` (classes de `cardText`, conservées car partagées avec les cartes ; vérifier qu'elles viennent bien de `src/styles` ou de `RiftText`, sinon passer par `RiftText`).
- Colonne principale :
  - « L'essentiel » en liste avec `RiftText rules` ;
  - « En animation » avec `TopicDemo` ;
  - « Cas concrets » en `RiftPanel`, avec la question en gras et la réponse ;
  - « Le texte officiel » : sections en `RiftPanel`, numéros en Barlow Condensed, `RiftText rules refs`, et un clic sur une ref qui navigue vers `/regles/officielles?doc=…&section=…`. On réutilise la localisation du lecteur ; si c'est trop lourd, on renvoie vers `/regles/officielles?doc=&rule=` et on le documente dans le rapport.
  - Erreur de chargement : message conservé.
- Colonne latérale :
  - « Exemple » : les cartes cliquables, qui ouvrent `CardZoom` ;
  - « Dans la même catégorie » ;
  - « ← Toute l'aide avancée ».
- Sous 1 024 px, la colonne latérale passe sous la principale.

**TopicDemo** : même logique (lecture et pause, points, reduced-motion, frames vides). Il est rhabillé en préfixe `scene-` : tapis `--bg-sunken`, jetons d'unité, flèches et étiquettes. Le CSS des « mini-scènes animées » sort de `main.css` et passe en style scoped.

- [ ] **Step 1 : tests.**
  - Migrer les cas de `AdvancedHelpView` (2), `AdvancedTopicView` (5) et `TopicDemo` (4).
  - Ajouter :
    - « recherche sans résultat : RiftEmpty » ;
    - « exemple : clic ouvre CardZoom » ;
    - « sujet introuvable : RiftEmpty ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : aide avancée Forgée`.

---

### Task 6 : texte officiel (`/regles/officielles`)

**Files :**
- Modify : `src/views/RulesView.vue` et sa spec.
- Create si utile : `src/rules/useRulesReader.js` et sa spec, pour sortir la logique (index, localisation, recherche, `go`, `applyQuery`) du gabarit.

**Interfaces :**
- **`useRulesReader()`** renvoie :
  - `documents`, `error` ;
  - `doc`, `sectionId`, `ruleId`, `openChapters` ;
  - `currentDoc`, `sections`, `currentSection`, `previousSection`, `nextSection` ;
  - `searchQuery`, `searchHits`, `onSearchInput` ;
  - `go(docKey, sectionId, rule?)`, `switchDoc`, `followRef(number)`, `pickHit`, `toggleChapter`.

  La logique est déplacée sans changement de comportement depuis `RulesView.vue`. Le défilement vers une règle reste dans le composable (`requestAnimationFrame` puis `scrollIntoView`).
- **La page** :
  1. `RulesHeader` « Règles officielles ». Sous le titre :
     - le document : `RiftChoice` sur les documents (`core`, `tournament`, avec les titres du JSON) ;
     - la méta : « mis à jour le … · N règles · PDF officiel ↗ ».
  2. **Recherche en haut, collante** (`position: sticky; top: var(--topbar-h)`) : `RiftField search` « Rechercher dans les règles » (placeholder « Mot-clé ou numéro de règle… »).
     - Les résultats s'affichent dans un panneau sous le champ, jusqu'à 40 boutons `officiel-hit`. Chacun montre le numéro en Barlow Condensed `--bronze-light`, le chemin en `--ink-muted` et l'extrait.
     - « Aucune règle trouvée… » en état vide quand la recherche fait au moins 2 caractères.
     - Échap vide la recherche.
  3. **Mise en page `officiel-layout`.**
     - **≥ 1 024 px** : à gauche, la table des matières collante `officiel-toc` (280 px, `position: sticky; top: calc(var(--topbar-h) + 64px)`, défilement interne). Elle liste les chapitres repliables (bouton avec `aria-expanded`, chevron) et leurs sections, avec `aria-current` sur la section courante et la section courante ramenée dans la vue. À droite, le texte.
     - **< 1 024 px** : un bouton « Sommaire » collant ouvre une `RiftSheet` avec la même table. Choisir une section ferme la feuille et amène le lecteur sur le texte. Le raccourci flottant « Sommaire ↑ » disparaît, puisque ce bouton collant le remplace.
  4. **Le texte** :
     - le chemin « Document › chapitre » ;
     - le `h2` de la section (neutralisé) et la méta « Section N · M règles » ;
     - les règles `officiel-rule` : numéro à gauche en Barlow Condensed, retrait selon `depth` (au plus 4), texte en `RiftText rules refs` ;
     - les exemples en encart `--bg-sunken` avec « Exemple » ;
     - les renvois `entry.refs` en `button.rift-ref` « → N libellé » ;
     - la règle ciblée surlignée par un filet gauche `--blood` et un fond `--bg-raised`.

     Le clic délégué sur `[data-ref]` appelle `followRef`. Plus de `v-html` ni de `formatText`, et `escapeHtml` n'est plus importé ici.
  5. Navigation de section : précédente et suivante en `RiftButton ghost`, avec le titre.
  6. La mention de source et le lien vers le PDF sont conservés.
  7. Chargement : `RiftSkeleton`. Erreur : `RiftEmpty` avec « Réessayer ».
  8. Hors ligne : statut affiché.

- [ ] **Step 1 : tests.**
  - Migrer les 8 cas de `RulesView.spec`.
  - `useRulesReader.spec` :
    - « followRef vers un autre document » ;
    - « numéro introuvable : rien ne se passe » ;
    - « recherche accent-insensible, 2 caractères minimum » ;
    - « applyQuery n'appelle pas router.replace ».
  - Page :
    - « téléphone : sommaire en feuille ; choisir une section ferme la feuille » ;
    - « bureau : table des matières avec aria-current » ;
    - « clic sur un renvoi dans le texte navigue » ;
    - « Échap vide la recherche ».
- [ ] **Step 2 à 4** : échec, code, succès.
- [ ] **Step 5** : commit `Web : texte officiel Forgé (table des matières, recherche, renvois)`.

---

### Task 7 : nettoyage et documentation

**Files :**
- Modify : `src/assets/main.css`, `src/assets/cssCoverage.spec.js` si besoin, la spec, et `riftarium/apps/web/README.md` si la liste des dossiers change.

- [ ] **Step 1 : retirer de `main.css` les tranches des règles devenues inutiles.**
  - Repères : « Page Règles » (vers la ligne 1277), « Hub des règles », « Guide d'apprentissage », « Démo interactive énergie / essence », « Plaque gravée », « Guide du débutant : table de jeu », « Panneau d'explications », « Plein écran », « Aide avancée », « Page d'un sujet », « Mini-scenes animees », « Lecture / pause », « Exemple : carte agrandie ».
  - Ajouter les règles des paliers responsive qui les visent.
  - **Règle de sûreté** : avant de supprimer un sélecteur, chercher chacune de ses classes dans `src` hors `main.css` (`grep -rn`, fichiers `.vue` et `.js`, classes dynamiques et `classList` comprises). Une classe encore utilisée garde sa règle. Attention aux classes partagées :
    - `rb-kw` et `rb-glyph` (cartes) ;
    - `eyebrow`, `offline-note` et `nav-locked` (autres pages) ;
    - `tb-credit` et `guide-term` (cités dans des paliers communs).
  - Lister dans le rapport ce qui est supprimé et ce qui est gardé, avec la raison.
- [ ] **Step 2 : composants.** `PageBanner` reste, car d'autres pages l'utilisent. Supprimer `BANNERS.rules` seulement si plus rien ne s'en sert, et vérifier `banners.spec.js`.
- [ ] **Step 3 : spec.**
  - Au §3.3 : la prop `refs` de `RiftText`.
  - Au §5 PR 6 : une puce « **Livré** » qui décrit `src/rules/` (`CardZoom`, `RulesHeader`, `LessonBlock`, `TableBoard`, `TopicDemo`, `LearnRuneDemo`, `useRulesReader`), les préfixes, la table des matières (collante sur bureau, en feuille sous 1 024 px), la suppression du `v-html` et les données inchangées (export mobile intact).
- [ ] **Step 4 : vérifier.** `npm run check` vert, puis un grep pour s'assurer qu'aucun gabarit n'utilise une classe dont la règle a été supprimée.
- [ ] **Step 5 : commits.** `Web : nettoyage des styles hérités des règles`, puis `Docs : spec — PR 6 règles livrée`.

---

## Validation locale (après la revue finale, avant tout push)

À montrer au mainteneur sur `http://localhost:8888` :
1. `/regles` : les portails, les chapitres, l'accès rapide, la Règle d'or.
2. Un chapitre du guide :
   - le sommaire collant ;
   - les blocs (tableau, notes, types de cartes avec Agrandir) ;
   - la démo des runes ;
   - sur téléphone, le sommaire repliable.
3. `/regles/debutant/plateau` :
   - les étapes, au clavier ← → ;
   - le zoom ;
   - le plein écran ;
   - le défilement horizontal sur téléphone.
4. `/regles/avancee` :
   - la recherche (avec un résultat et sans résultat) ;
   - un sujet avec animation, cas concrets, texte officiel et exemple zoomé.
5. `/regles/officielles` :
   - la recherche (mot-clé, puis numéro « 002 ») ;
   - le changement de document ;
   - un renvoi cliquable ;
   - la table des matières collante sur bureau, en feuille sur téléphone.
