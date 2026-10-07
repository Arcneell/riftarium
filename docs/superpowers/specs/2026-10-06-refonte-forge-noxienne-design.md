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
| Méthode | Refonte progressive, une PR par bloc de pages, mergée dans la branche d'intégration `refonte/forge` ; un seul merge vers `main` (donc en production) quand tout est validé |

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
| `--blood-text` | `#e0605a` | accent dans du texte courant (≥ 5,3:1) ; `--blood-bright` est réservé aux grands titres et graphismes |
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
| `RiftChip` | puce de domaine, de rareté ou de filtre (supprimable) ; la prop `static` en fait un simple affichage (`<span>` sans bascule ni tabulation), utilisée pour les domaines affichés dans l'analyse d'un deck ; livré en PR 5 |
| `RiftField` | champ texte, champ de recherche, sélecteur ; label et erreur intégrés |
| `RiftTabs` | onglets de sous-pages liés aux routes (rubriques) ; défilants sur téléphone. Réservé aux sous-pages : pas pour des onglets dans une page |
| `RiftSegments` | onglets dans une page, `role="tablist"` (flèches, Début, Fin), panneaux posés par la page (`id="${idBase}-panel-${value}"`, `role="tabpanel"`) ; livré en PR 5 |
| `RiftModal` | modale accessible (focus piégé, Échap, défilement bloqué) ; remplace `ModalDialog` |
| `RiftSheet` | feuille du bas sur téléphone (filtres, menu du compte) |
| `RiftSkeleton` | squelettes de chargement |
| `RiftEmpty` | état vide (titre, phrase, action) |
| `RiftStepper` | compteur − valeur + (cibles de 44 px ; 28 à 32 px sur les vignettes et dans les pochettes), valeur en `aria-live="polite"` ; livré en PR 4b |
| `RiftChoice` | choix unique en puces (`role="radiogroup"`), à la place d’un menu déroulant ; livré en PR 4b |
| `RiftStat` | glyphe officiel + valeur Cinzel + étiquette |
| `CardTile` | vignette de carte : illustration, nom, prix, quantité possédée, reflet foil si rare / showcase |
| `RiftGlyph`, `RiftText` | rendu du texte de jeu à partir de `cardText.js` (glyphes Riot, pastilles de mots-clés, `**gras**`) ; seul rendu de texte de jeu du site, remplace `CardText` et `RuleText`. Une prop `rules` active la conversion des symboles abrégés des règles officielles (`[R]`, `[E]`, `[M]`…) ; `[X]`, `[N]`, `[C]` (et `[Y]` à côté de `[X]`) deviennent des pastilles texte à libellé accessible. Une prop `refs` transforme les renvois « règle 123.4 » / « section 103 » en boutons `[data-ref]`, la page délègue le clic |

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

- `src/styles/`, et les composants de `src/ui/` utilisés par la coquille (`RiftButton`, `RiftField`, `RiftTabs`, `RiftModal`, `RiftSheet`, `RiftText`, `RiftGlyph`) ; `RiftPanel` et `RiftSkeleton` arrivent en PR 2, `RiftChip`, `RiftEmpty`, `RiftStat` et `CardTile` en PR 3, avec leur premier usage ; redirection des
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
- Composants livrés : `RiftPanel` et `RiftSkeleton` ; `RiftChip` et `RiftEmpty`, sans
  usage sur l'accueil, arrivent en PR 3 avec leur premier consommateur. La rivière de
  cartes (`CardRiver`) est remplacée par le mur.

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

- **Livré** :
  - composants : `RiftChip`, `RiftEmpty`, `RiftStat`, `CardTile` (`src/ui/`),
    plus `CardFilters`, `ActiveFilters` et `CardCollectionPanel`
    (`src/cards/`) ;
  - la nouvelle vignette a pour classe racine `rift-tile` et la fiche utilise le
    préfixe `fiche-`, pour éviter toute collision avec les anciennes classes
    globales ;
  - l'ancienne vignette (`components/CardTile.vue`) et `FilterSelect` restent
    pour les pages collection, wishlist et decks jusqu'à leurs PR ;
  - les styles de l'ancienne liste et de l'ancienne fiche sont retirés de
    `main.css`.

### PR 4 : collection et wishlist

- Résumé chiffré et complétion par set (barres Forgées).
- Classeur actuel (pochettes, cartes manquantes en fantôme) rhabillé ;
  l'édition fine des lots (quantité ±1 par lot) se fait sur la fiche carte
  (`CardCollectionPanel`, un stepper par lot depuis la PR 4b) ; le reclassement d'un
  lot (état, langue) passe par retrait puis ajout précis, et l'inventaire couvre
  l'état et la langue en masse (pas de `RiftModal` d'édition des lots).
- Wishlist avec les mêmes composants.
- **Livré** : la page est découpée dans `src/collection/` (page, stats,
  classeur, inventaire, composable) ; les classes neuves portent les préfixes
  `classeur-`, `inventaire-`, `collection-page-`, `collection-stats-` et
  `souhait-` (les anciens `binder-`, `pocket`, `wish-`… de `main.css` sont
  retirés). Le tournage de page est raccourci (fondu et glissement, 200 ms au
  plus) et la cascade d'apparition des pochettes est supprimée ; le classeur
  reste monté entre les deux affichages, et l'inventaire a une sélection dont la
  tuile est inerte. L'édition fine des lots n'est pas dans une `RiftModal` : la
  quantité de chaque lot se règle sur la fiche carte (stepper par lot, PR 4b), le
  reclassement d'un lot n'existe que par retrait puis ajout précis, et l'inventaire
  ne propose que l'état et la langue en masse. Après une opération de masse, les statistiques sont rechargées et le
  classeur recharge sa double page.

### PR 4b : ajout à la collection (`feat/refonte-ajout-collection`)

Décision du mainteneur (6 octobre 2026) : fusion de trois propositions, **A + B + C**.

- **A, compteur rapide** sur la fiche carte : un − / + (`RiftStepper`) ajoute ou retire un
  exemplaire dans l’état et la langue habituels.
- **B, lots** : sur la fiche carte, chaque lot se lit « NM · Français » avec son propre
  stepper `sm` (`RiftStepper`) : ± 1 par `PATCH /api/collection/entries/{id}`, et le « − »
  d'un lot à 1 le supprime (qty 0) ; il n'y a plus de puce ✕, le « − » la remplace (un
  seul geste, pas de suppression d'un lot entier par mégarde). **Pas de reclassement d'un
  lot** (changement d'état ou de langue) : retrait puis ajout précis, et l'Inventaire
  permet le reclassement de masse. L’ajout précis se fait par puces d’état et de langue
  (`RiftChoice`, nom accessible « NM, Near Mint »).
- **C, saisie rapide** : un interrupteur « Saisie rapide » (membres seulement) sur la
  cartothèque et dans le classeur pose un − / + sur chaque vignette ou pochette, fantômes
  compris, pour saisir un booster ou un classeur à la chaîne. L’interrupteur est mémorisé
  pour la session (`sessionStorage`).
- **Aucun menu déroulant ni champ numérique** dans la saisie des exemplaires.
- **Préférence mémorisée** : état et langue d’ajout, par défaut « NM · Français », dans
  `localStorage` (clé `riftarium_collection_defaults`), toujours sous `try/catch`. Un rappel pour la modifier :
  sur la cartothèque et dans le classeur, « Ajouts en NM · Français · changer » ouvre une
  feuille (`RiftSheet`) ; sur la fiche carte, le libellé est « Ajouté en NM · Français ·
  changer » et le réglage s'ouvre en ligne, sous le libellé, sans feuille.
- **Règle du « − »** (fiche et saisie rapide) : on retire un exemplaire du lot de la
  préférence (état et langue par défaut) s'il existe, sinon du lot de plus grand id (le plus
  récent). Dans la saisie rapide, les lots ne sont lus qu'au « − » (chargement paresseux,
  `GET /api/collection/{id}`) et relus à chaque « − » : si le total réel diffère de celui
  affiché, la vignette s'aligne et émet `change` sans rien retirer.
- **API inchangée** : `POST /api/collection/{id}/entries` additionne un lot identique,
  `PATCH /api/collection/entries/{id}` (qty 0 supprime), `GET /api/collection/{id}`.
- **Livré** : logique dans `src/collection/` (`useOwnedCopies`, `useQuickAdd`,
  `collectionDefaults`, `QuickCount`, `QuickAddPref`) ; un seul jeton de séquence couvre
  chargements et mutations d’une carte. Classeur : une pochette suit son compteur sans
  recharger la double page (rechargement discret si la page a tourné pendant l’écriture),
  la progression et les statistiques (cartes, uniques, valeur) sont relues ensemble après un
  court débounce (300 ms, une rafale de « + » = une relecture) avec des jetons de
  séquence, et en saisie rapide le classeur reste affiché même à 0 carte possédée (puce
  « Saisie rapide » dans l’état vide). Sur la cartothèque, le badge ×N de la vignette est
  masqué quand le compteur rapide est présent. Dans les pochettes (et sur les vignettes sous 430 px), le stepper `sm` se resserre
  (28 px, « + » à l'échelle 1) pour tenir dans une pochette de ≈ 96 px.

### PR 5 : decks et communauté

- **Mes decks** : fiches de deck sur l'illustration de la légende.
- **Éditeur** : trois zones (recherche de cartes, liste par zone, stats et
  règles en direct), qui passent en `RiftSegments` sur téléphone. La logique
  existante est conservée (`useDeckRules`, `useDeckStats`, `useDeckAutosave`,
  `deckExport`).
- **Communauté** : filtres par légende et par domaine, pagination.
- **Détail d'un deck** : `DeckView` et `DeckVisual` rhabillés.
- **Livré** :
  - dossier `src/decks/` : `DeckCard`, `DeckLegalBadge`, `CommunityFilters`,
    `DeckGallery`, `DeckList`, `DeckEditorBar`, `DeckStatsPanel`,
    `DeckExportBar`, `DeckMissingModal`, `DeckView`, `DeckVisual` et
    `useDeckDrag` (glisser-déposer) ; les pages `DecksView`, `CommunityView` et
    `DeckEditView` les assemblent. Aucun changement d'API ;
  - préfixes de classes propres à chaque pièce (`deck-card-`, `legalite-`,
    `analyse-`, `mesdecks-`, `communaute-`, `lecture-`, `atelier-`, `galerie-`,
    `decklist-`, `rift-segments`), absents de `main.css` ;
  - éditeur : trois colonnes (galerie, liste par zone, analyse) à partir de
    1 280 px, deux colonnes en dessous, puis sur téléphone (< 768 px) trois onglets
    `RiftSegments` « Cartes », « Deck » et « Analyse » (pastille de nombre de
    cartes, « ✕ » si une règle échoue) ;
  - éclat rouge de 600 ms sur la ligne d'une carte ajoutée (`decklist-flash`),
    coupé sous `prefers-reduced-motion` ; `v-reveal` et `v-tilt` n'y servent plus ;
  - `DeckBox` et `FilterSelect` supprimés avec leurs specs et leurs styles hérités
    de `main.css` (builder v2, fiches, lecture, prix des decks, `fsel*`,
    `owned-seg`, `filter-board`) ; seule `body.drag-active`, posée par
    `useDeckDrag`, est conservée ;
  - `CardFilters` (`src/cards/`) sert la galerie de l'éditeur avec sa prop `hide-search`,
    qui masque sa recherche parce que la galerie porte déjà son propre champ ;
    les filtres de la communauté (`CommunityFilters`, puces `RiftChip`) et ceux de
    la galerie s'ouvrent dans un `RiftSheet` sous 1 024 px (téléphone et tablette) ;
  - `.price-tag` reste dans `main.css` : `CardTile` l'utilise encore.

### PR 6 : règles

- Hub à trois entrées.
- Guide en chapitres et plateau animé rhabillés.
- Aide avancée.
- Texte officiel : table des matières collante à gauche, recherche en haut.
- `RiftText` partout.
- **Livré** :
  - dossier `src/rules/` : `CardZoom` (zoom de carte en vrai dialogue), `RulesHeader`
    (sur-titre et fil, à la place de `PageBanner`), `LessonBlock` (blocs de leçon :
    tableau, notes, types de cartes avec « Agrandir »), `TableBoard` (plateau animé),
    `TopicDemo` (mini-scènes de l'aide avancée), `LearnRuneDemo` (démo énergie / essence),
    `OfficialToc`, `useRulesReader` (chargement, recherche accent-insensible, renvois,
    lien profond) et les données `learn.js`, `guide.js`, `topics.js`, `rulesStore.js` ;
    les vues `RulesHubView`, `LearnGuideView`, `BeginnerGuideView`, `AdvancedHelpView`,
    `AdvancedTopicView` et `RulesView` les assemblent ;
  - préfixes de classes propres à la PR (`regles-`, `portail-`, `chapitre-`, `lecon-`,
    `plateau-`, `aide-`, `sujet-`, `scene-`, `officiel-`, `carte-zoom`, `rift-ref`),
    absents de `main.css` ; les styles sont `scoped` ;
  - texte officiel : table des matières collante à gauche sur bureau, en feuille
    (`RiftSheet`) sous 1 024 px ;
  - plus aucun `v-html` dans les pages de règles : le texte passe par
    `<RiftText rules>`, avec `refs` pour les renvois cliquables ;
  - `main.css` : les quelque 1 900 lignes héritées des règles (page Règles, hub, guide,
    plateau, aide avancée, mini-scènes) et leurs paliers responsive sont retirées ;
    `BANNERS.rules` reste (page des mentions légales) ;
  - données inchangées (`learn.js`, `guide.js`, structure de `topics.js`) : le format de
    l'export mobile `guides-fr.json` ne change pas ;
  - correction des abréviations de puissance du texte officiel (135.2.e) : `[A]` est
    l'essence arc-en-ciel, `[C]` la puissance du domaine de la carte (pastille texte),
    `[S]` la puissance et `[T]` l'épuisement (anciennes abréviations), `[X]` et `[N]`
    des valeurs variables (pastilles). `[Y]` reste la rune d'Ordre, sauf quand le texte
    contient aussi `[X]` (règles 438.3, 439.5) : c'est alors le paramètre générique,
    rendu en pastille « valeur variable Y ». Deux textes de `topics.js` écrivaient `[C]`
    pour l'arc-en-ciel : corrigés en `[A]` ;
  - le mobile (`lib/app/design/glyphs.dart`, `'C': 'rune_rainbow'`) garde l'ancienne
    inversion et devra être réaligné ; `guides-fr.json` est à ré-exporter (`topics.js`
    a changé).

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

1. Une branche `feat/refonte-<bloc>` depuis `origin/refonte/forge` ; la PR vise `refonte/forge`, jamais `main`.
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
