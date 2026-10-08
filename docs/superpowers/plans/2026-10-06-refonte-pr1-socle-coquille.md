# Refonte Forge noxienne — PR 1 : socle et coquille — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** poser le design system « Forge noxienne » (tokens, polices, base, premiers composants `src/ui/`), remplacer l'en-tête et le tiroir par la nouvelle coquille (rail latéral, barre haute, onglets mobiles, recherche universelle, pied de page) et retirer le scanner web, sans casser les pages existantes.

**Architecture :** trois feuilles globales (`src/styles/`) chargées avant l'ancien `main.css`, dont les variables sont redirigées vers les nouveaux tokens, pour que les pages pas encore refaites prennent la palette. Les composants de base vivent dans `src/ui/` avec `<style scoped>`. La coquille vit dans `src/shell/` et pilote la navigation à partir d'une seule table (`navigation.js`). La recherche universelle est une fonction pure (`src/search/search.js`) branchée sur les endpoints existants, affichée par `SearchPalette.vue`.

**Tech Stack :** Vue 3.5 (`<script setup>`), vue-router 5, Vite 8, Vitest 4 + @vue/test-utils + jsdom, ESLint 10, Prettier 3 (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md`

## Global Constraints

- Langue : commentaires, textes d'interface, messages de commit et documentation en **français**. Identifiants en anglais.
- Commits : préfixe `Web : …` (ou `Docs : …` pour la seule documentation), terminés par la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Aucun push** : la PR n'est poussée qu'après validation locale explicite du mainteneur (tâche 15).
- Branche : `feat/refonte-socle` (déjà créée depuis `origin/main`, contient la spec).
- Toutes les commandes `npm` se lancent depuis `riftarium/apps/web`. Vérification finale : `npm run check` (lint + format:check + test + build).
- Palette : `--bg #0d0d0f`, `--bg-raised #17120f`, `--bg-sunken #110e0c`, `--line #2f2721`, `--blood #b3262b`, `--blood-bright #d23a33`, `--blood-text #e0605a`, `--bronze #8a6e4b`, `--bronze-light #d6b98c`, `--ink #e9e2d8`, `--ink-muted #9a8f80`.
- `--blood-bright` (3,9:1 sur `--bg-raised`) est réservé au texte de grande taille (≥ 24 px) et aux éléments graphiques. Le texte courant en accent utilise `--blood-text` (≥ 5,3:1). C'est un ajout à la spec, qui est mise à jour en tâche 14.
- Polices : Cinzel (titres), Barlow Condensed 600/700 (étiquettes, navigation, boutons), Barlow 400/600 (texte), auto-hébergées en woff2 latin + latin-ext. IBM Plex Mono, Marcellus et Outfit sont retirées.
- Glyphes Riot et pastilles de mots-clés : rendus par `cardText.js` (inchangé). Les classes globales `.rb-glyph` et `.rb-kw` restent disponibles (des vues les utilisent directement).
- Ne pas toucher : l'API, l'app mobile, `ci.yml`, `GET /api/cards/hashes` (utilisé par le mobile), le libellé `scan` de `AdminView.vue` (historique de fréquentation).
- Les directives `v-tilt` et `v-reveal` restent enregistrées pendant cette PR (11 vues s'en servent). Elles seront retirées avec les pages concernées.
- Le logo (`Logo.vue`) est conservé tel quel dans cette PR. Il sera à revoir avec le mainteneur.
- Ajustement de périmètre par rapport au §5 de la spec : `RiftPanel`, `RiftChip`, `RiftEmpty`, `RiftSkeleton`, `RiftStat` et `CardTile` n'ont aucun consommateur dans la coquille. Ils sont livrés avec leur premier usage (PR 2 et PR 3) plutôt qu'en code mort. La PR 1 livre `RiftButton`, `RiftField`, `RiftTabs`, `RiftModal`, `RiftSheet`, `RiftText` et `RiftGlyph`, tous utilisés dès cette PR. La spec est mise à jour en tâche 14.

## Review Focus

- **Raccourci `/` pendant une saisie** : taper `/` dans un champ (recherche de la cartothèque, éditeur de deck) ne doit pas ouvrir la palette. Testé en tâche 13 (`App.spec.js`).
- **Réponses de recherche dans le désordre** : une réponse lente à « ah » arrivant après « ahri » ne doit pas écraser les résultats d'« ahri ». Testé en tâche 12.
- **Un groupe en erreur** : si `/api/community/decks` échoue (pare-feu, 500), les cartes et les règles s'affichent quand même, et le groupe signale l'indisponibilité. Testé en tâche 11.
- **Recherche accentuée** : « reaction » doit trouver « Réaction » et inversement. Testé en tâche 11 (`normalize`).
- **Rail replié mémorisé avec stockage bloqué** : en navigation privée, `localStorage` qui lève ne doit pas casser la coquille. Testé en tâche 13.

---

## Carte des fichiers

| Fichier | Rôle |
| --- | --- |
| `src/styles/tokens.css` | variables de design (couleurs, polices, espaces, rayons, durées, dimensions de coquille, z-index) |
| `src/styles/tokens.spec.js` | contraste des tokens de texte |
| `src/styles/fonts.css` | `@font-face` Cinzel, Barlow, Barlow Condensed |
| `src/styles/base.css` | reset, typographie de base, liens, focus, verrou de défilement, glyphes et mots-clés, réduction des animations |
| `src/assets/fonts/barlow-*.woff2` | polices ajoutées |
| `src/ui/RiftButton.vue` | bouton / lien d'action |
| `src/ui/RiftField.vue` | champ de saisie (texte, recherche) |
| `src/ui/RiftTabs.vue` | onglets de navigation (sous-rubriques) |
| `src/ui/useDialog.js` | pile de dialogues, piège à focus, Échap, verrou de défilement, restitution du focus |
| `src/ui/RiftModal.vue` | modale (remplace `components/ModalDialog.vue`) |
| `src/ui/RiftSheet.vue` | feuille du bas (téléphone) |
| `src/ui/richText.js` | découpage du texte de jeu (gras, abréviations des règles, glyphes) |
| `src/ui/RiftGlyph.vue` | un glyphe officiel ou une pastille de mot-clé |
| `src/ui/RiftText.vue` | texte de jeu enrichi (remplace `CardText.vue` et `RuleText.vue`) |
| `src/shell/navigation.js` | table des rubriques, rubrique active, sous-page active, fil d'Ariane |
| `src/shell/pageCrumb.js` | dernier maillon du fil d'Ariane fourni par une page |
| `src/shell/useLogout.js` | déconnexion (partagée par le menu bureau et la feuille mobile) |
| `src/shell/AppRail.vue` | rail latéral |
| `src/shell/AccountMenu.vue` | menu du compte (bureau) |
| `src/shell/AccountSheet.vue` | feuille du compte (téléphone) |
| `src/shell/AppTopbar.vue` | barre haute (fil d'Ariane + recherche ; version téléphone) |
| `src/shell/AppTabbar.vue` | barre d'onglets du bas (téléphone) |
| `src/shell/AppFooter.vue` | pied de page |
| `src/shell/SearchPalette.vue` | fenêtre de recherche universelle |
| `src/search/search.js` | recherche universelle (fonctions pures + `runSearch`) |
| `src/composables/useBreakpoint.js` | palier `mobile` / `tablet` / `desktop` |
| `src/test/makeRouter.js` | routeur mémoire pour les tests de la coquille |
| `src/App.vue` | composition de la coquille (réécrit) |
| `src/main.js` | imports des feuilles globales |
| `src/assets/main.css` | variables redirigées ; base, polices et styles de l'ancienne coquille supprimés |
| `apps/web/README.md` | charte Forge noxienne (nouveau) |

---

### Task 1 : socle CSS (tokens, polices, base)

**Files :**
- Create : `src/styles/tokens.css`, `src/styles/tokens.spec.js`, `src/styles/fonts.css`, `src/styles/base.css`
- Create : `src/assets/fonts/barlow-latin-400.woff2`, `barlow-latin-ext-400.woff2`, `barlow-latin-600.woff2`, `barlow-latin-ext-600.woff2`, `barlow-condensed-latin-600.woff2`, `barlow-condensed-latin-ext-600.woff2`, `barlow-condensed-latin-700.woff2`, `barlow-condensed-latin-ext-700.woff2`
- Delete : `src/assets/fonts/ibm-plex-mono-*.woff2`, `marcellus-*.woff2`, `outfit-*.woff2`
- Modify : `src/main.js`, `src/assets/main.css` (lignes 1-329 : `@font-face`, `:root`, base)

**Interfaces :**
- Produces : les variables CSS listées dans `tokens.css` ci-dessous, utilisées par toutes les tâches suivantes ; les classes globales `.rb-glyph`, `.rb-kw`, `.sr-only`, `body.nav-locked`.

- [ ] **Step 1 : écrire le test de contraste (en échec)**

`src/styles/tokens.spec.js` :

```js
import fs from "node:fs"
import { fileURLToPath } from "node:url"
import { describe, expect, it } from "vitest"

/* Les tokens de texte doivent rester lisibles (WCAG AA, 4,5:1) sur les trois fonds :
   une retouche de couleur qui casse le contraste doit faire échouer la CI. */
const css = fs.readFileSync(fileURLToPath(new URL("./tokens.css", import.meta.url)), "utf8")

function token(name) {
  const match = css.match(new RegExp(`--${name}:\\s*(#[0-9a-fA-F]{6})\\b`))
  if (!match) throw new Error(`token --${name} absent de tokens.css`)
  return match[1]
}

function luminance(hex) {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const value = parseInt(hex.slice(i, i + 2), 16) / 255
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

function contrast(a, b) {
  const [light, dark] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (light + 0.05) / (dark + 0.05)
}

const BACKGROUNDS = ["bg", "bg-raised", "bg-sunken"]

describe("tokens de couleur", () => {
  it.each(["ink", "ink-muted", "bronze-light", "blood-text"])("--%s reste lisible sur les trois fonds", (name) => {
    for (const background of BACKGROUNDS) {
      expect(contrast(token(name), token(background))).toBeGreaterThanOrEqual(4.5)
    }
  })

  it("le texte blanc d'un bouton principal reste lisible sur --blood", () => {
    expect(contrast("#ffffff", token("blood"))).toBeGreaterThanOrEqual(4.5)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/styles/tokens.spec.js`
Expected : FAIL (`ENOENT … tokens.css`).

- [ ] **Step 3 : écrire `src/styles/tokens.css`**

```css
/* ============================================================
   Riftarium — tokens « Forge noxienne »
   Noir de forge, rouge sang pour l'action, bronze pour la matière.
   Seul endroit où une couleur, une police ou une dimension de
   coquille est définie. Les composants consomment ces variables.
   ============================================================ */
:root {
  /* Fonds */
  --bg: #0d0d0f;
  --bg-raised: #17120f;
  --bg-sunken: #110e0c;
  --line: #2f2721;

  /* Sang : action principale, liseré, rubrique active.
     --blood-bright : grands titres et graphismes seulement (3,9:1).
     --blood-text : accent du texte courant (≥ 5,3:1). */
  --blood: #b3262b;
  --blood-bright: #d23a33;
  --blood-text: #e0605a;

  /* Bronze : filets, bordures (--bronze), intertitres, prix, focus (--bronze-light). */
  --bronze: #8a6e4b;
  --bronze-light: #d6b98c;

  /* Texte */
  --ink: #e9e2d8;
  --ink-muted: #9a8f80;

  /* Domaines officiels (pastilles, graphiques) et variantes texte (≥ 4,5:1). */
  --fury: #cf4437;
  --calm: #178f7f;
  --mind: #7355cf;
  --body: #3f8f50;
  --chaos: #c2439b;
  --order: #ab7c1a;
  --fury-text: #f0705f;
  --calm-text: #3ecfbb;
  --mind-text: #a68df5;
  --body-text: #6cc47e;
  --chaos-text: #e77ac4;
  --order-text: #d9a94e;

  /* Familles officielles des mots-clés. */
  --kw-timing: #24705f;
  --kw-combat: #cc356e;
  --kw-state: #94b42a;
  --kw-utility: #6c6d6c;

  /* Polices */
  --font-display: "Cinzel", Georgia, serif;
  --font-label: "Barlow Condensed", "Arial Narrow", sans-serif;
  --font-body: "Barlow", system-ui, sans-serif;

  /* Espacements */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 24px;
  --space-6: 32px;
  --space-7: 48px;

  /* Formes : la signature vient des angles coupés, pas de l'arrondi. */
  --radius-s: 2px;
  --radius-m: 4px;
  --radius-card: 10px;
  --cut: 10px;

  /* Ombres et durées */
  --shadow-deep: 0 18px 40px rgba(0, 0, 0, 0.55);
  --t-fast: 150ms;
  --t-base: 200ms;

  /* Coquille */
  --rail-w: 220px;
  --rail-w-collapsed: 64px;
  --topbar-h: 52px;
  --tabbar-h: 60px;
  --z-topbar: 30;
  --z-rail: 40;
  --z-tabbar: 50;
  --z-overlay: 100;
}
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/styles/tokens.spec.js`
Expected : PASS (5 tests).

- [ ] **Step 5 : télécharger les polices Barlow (fontsource, licence OFL)**

Run (depuis `riftarium/apps/web`) :

```bash
cd src/assets/fonts
for w in 400 600; do for s in latin latin-ext; do
  curl -fsSL -o "barlow-$s-$w.woff2" "https://cdn.jsdelivr.net/npm/@fontsource/barlow@5/files/barlow-$s-$w-normal.woff2"
done; done
for w in 600 700; do for s in latin latin-ext; do
  curl -fsSL -o "barlow-condensed-$s-$w.woff2" "https://cdn.jsdelivr.net/npm/@fontsource/barlow-condensed@5/files/barlow-condensed-$s-$w-normal.woff2"
done; done
for f in barlow-*.woff2; do printf '%s ' "$f"; head -c4 "$f"; echo; done
git rm -q ibm-plex-mono-*.woff2 marcellus-*.woff2 outfit-*.woff2
cd ../../..
```

Expected : huit lignes `barlow…woff2 wOF2` (l'en-tête d'un woff2 valide).

- [ ] **Step 6 : écrire `src/styles/fonts.css`**

```css
/* Polices auto-hébergées (latin + latin-ext) : aucune requête vers Google.
   Cinzel (variable 400-900) : titres en capitales épigraphiques.
   Barlow Condensed : étiquettes, navigation, boutons. Barlow : texte courant. */
@font-face {
  font-family: "Cinzel";
  font-style: normal;
  font-weight: 400 900;
  font-display: swap;
  src: url("../assets/fonts/cinzel-latin-var.woff2") format("woff2");
  unicode-range:
    U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC,
    U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
@font-face {
  font-family: "Cinzel";
  font-style: normal;
  font-weight: 400 900;
  font-display: swap;
  src: url("../assets/fonts/cinzel-latin-ext-var.woff2") format("woff2");
  unicode-range:
    U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F,
    U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}
@font-face {
  font-family: "Barlow";
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url("../assets/fonts/barlow-latin-400.woff2") format("woff2");
  unicode-range:
    U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC,
    U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
@font-face {
  font-family: "Barlow";
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url("../assets/fonts/barlow-latin-ext-400.woff2") format("woff2");
  unicode-range:
    U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F,
    U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}
@font-face {
  font-family: "Barlow";
  font-style: normal;
  font-weight: 600;
  font-display: swap;
  src: url("../assets/fonts/barlow-latin-600.woff2") format("woff2");
  unicode-range:
    U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC,
    U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
@font-face {
  font-family: "Barlow";
  font-style: normal;
  font-weight: 600;
  font-display: swap;
  src: url("../assets/fonts/barlow-latin-ext-600.woff2") format("woff2");
  unicode-range:
    U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F,
    U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}
@font-face {
  font-family: "Barlow Condensed";
  font-style: normal;
  font-weight: 600;
  font-display: swap;
  src: url("../assets/fonts/barlow-condensed-latin-600.woff2") format("woff2");
  unicode-range:
    U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC,
    U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
@font-face {
  font-family: "Barlow Condensed";
  font-style: normal;
  font-weight: 600;
  font-display: swap;
  src: url("../assets/fonts/barlow-condensed-latin-ext-600.woff2") format("woff2");
  unicode-range:
    U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F,
    U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}
@font-face {
  font-family: "Barlow Condensed";
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url("../assets/fonts/barlow-condensed-latin-700.woff2") format("woff2");
  unicode-range:
    U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC,
    U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD;
}
@font-face {
  font-family: "Barlow Condensed";
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url("../assets/fonts/barlow-condensed-latin-ext-700.woff2") format("woff2");
  unicode-range:
    U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F,
    U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF;
}
```

- [ ] **Step 7 : écrire `src/styles/base.css`**

```css
/* ============================================================
   Riftarium — base globale « Forge noxienne »
   Reset, typographie de base et vocabulaire de jeu partagé
   (glyphes Riot, pastilles de mots-clés). Rien d'autre n'est
   global : chaque composant porte ses styles (scoped).
   ============================================================ */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
  /* Barre haute collante : une ancre ne doit pas finir dessous. */
  scroll-padding-top: calc(var(--topbar-h) + 16px);
}

body {
  background: var(--bg);
  color: var(--ink);
  font-family: var(--font-body);
  font-size: 16px;
  line-height: 1.6;
  /* dvh : 100vh inclut la barre d'adresse rétractable sur mobile. */
  min-height: 100dvh;
  overflow-x: hidden;
}

/* Lueur de forge, sur un calque fixe composité : aucun repaint au défilement. */
body::before {
  content: "";
  position: fixed;
  inset: 0;
  z-index: -1;
  pointer-events: none;
  background: radial-gradient(900px 480px at 85% -10%, rgba(179, 38, 43, 0.14) 0%, transparent 65%);
}

/* Défilement bloqué : posé par toute modale, feuille ou palette ouverte. */
body.nav-locked {
  overflow: hidden;
  overscroll-behavior: none;
}

h1,
h2,
h3 {
  font-family: var(--font-display);
  font-weight: 700;
  line-height: 1.15;
  color: var(--ink);
}

::selection {
  background: rgba(179, 38, 43, 0.45);
  color: #fff;
}
::-webkit-scrollbar {
  width: 10px;
}
::-webkit-scrollbar-track {
  background: var(--bg-sunken);
}
::-webkit-scrollbar-thumb {
  background: var(--bronze);
  border: 3px solid var(--bg-sunken);
  border-radius: 999px;
}

img {
  max-width: 100%;
  display: block;
}
a {
  color: var(--bronze-light);
  text-decoration: none;
  transition: color var(--t-fast);
}
a:hover {
  color: var(--blood-text);
}
button {
  font: inherit;
  color: inherit;
  background: none;
  border: none;
  cursor: pointer;
}
button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 3px;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}

/* ---------- Vocabulaire de jeu : glyphes Riot et mots-clés ---------- */
.rb-glyph {
  display: inline-block;
  width: 1.12em;
  height: 1.12em;
  vertical-align: -0.2em;
  margin: 0 0.1em;
}
/* Les glyphes officiels sont blancs : on les teinte à l'encre via un masque. */
.rb-glyph.ink {
  background-color: currentColor;
  -webkit-mask: var(--glyph) center / contain no-repeat;
  mask: var(--glyph) center / contain no-repeat;
}
.rb-glyph.energy {
  filter: invert(1) saturate(0) brightness(1.12);
}
.rb-kw {
  display: inline-block;
  margin: 0 0.14em;
  padding: 0.05em 0.5em;
  border-radius: 3px;
  background: var(--kw, var(--kw-utility));
  color: #fff;
  font-family: var(--font-body);
  font-size: 0.78em;
  font-style: italic;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  vertical-align: 0.06em;
  white-space: nowrap;
}
.rb-kw.timing {
  --kw: var(--kw-timing);
}
.rb-kw.combat {
  --kw: var(--kw-combat);
}
.rb-kw.state {
  --kw: var(--kw-state);
}
.rb-kw.utility {
  --kw: var(--kw-utility);
}
.rb-kw.arrow {
  padding-right: 0.85em;
  clip-path: polygon(0 0, calc(100% - 0.45em) 0, 100% 50%, calc(100% - 0.45em) 100%, 0 100%);
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation: none !important;
    transition: none !important;
  }
  html {
    scroll-behavior: auto;
  }
}
```

- [ ] **Step 8 : charger les feuilles dans `src/main.js`**

Remplacer la ligne `import "./assets/main.css"` par :

```js
import "./styles/fonts.css"
import "./styles/tokens.css"
import "./styles/base.css"
/* Ancienne feuille globale : rétrécit à chaque PR de la refonte, puis disparaît. */
import "./assets/main.css"
```

- [ ] **Step 9 : rediriger l'ancien `main.css`**

Dans `src/assets/main.css`, supprimer **tout ce qui précède la règle `.wrap {`** (ligne 330 actuelle) : le commentaire d'en-tête, tous les `@font-face`, le bloc `:root`, `*`, la règle `prefers-reduced-motion`, `html`, `body`, `body.nav-locked`, `body::before`, `::selection`, les scrollbars, `img`, `a`, `a:hover`, `.card-back-link`, `.card-back-link:hover`, `button`, `button:disabled` et `:focus-visible`. Avant de supprimer, recopier telles quelles en tête de la nouvelle section (sous le commentaire ci-dessous) les deux règles `.card-back-link`, encore utilisées par `CardView.vue`.

Puis insérer à la place, en tout début de fichier :

```css
/* ============================================================
   Ancienne feuille globale — en cours de démantèlement.
   Chaque PR de la refonte « Forge noxienne » supprime la tranche
   des pages qu'elle réécrit. Les anciennes variables pointent
   vers les tokens de src/styles/tokens.css, pour que les pages
   pas encore refaites prennent déjà la palette.
   ============================================================ */
:root {
  --paper: var(--bg);
  --paper-2: var(--bg-raised);
  --surface: rgba(23, 18, 15, 0.86);
  --surface-solid: var(--bg-sunken);
  --line-strong: rgba(138, 110, 75, 0.55);
  --ink-strong: #f4ede2;
  --muted: var(--ink-muted);
  --gold: var(--bronze);
  --gold-deep: var(--bronze-light);
  --gold-soft: #6f5639;
  --gold-grad: linear-gradient(135deg, #c9343a 0%, #b3262b 55%, #8f1c21 100%);
  --hex: var(--blood-text);
  --hex-soft: #3a1416;
  --hex-text: var(--blood-text);
  --prism: linear-gradient(90deg, var(--fury), var(--order), var(--body), var(--calm), var(--mind), var(--chaos));
  --r-sm: 4px;
  --r: 6px;
  --r-lg: 8px;
  --r-full: 999px;
  --shadow: var(--shadow-deep);
  --shadow-soft: 0 8px 22px rgba(0, 0, 0, 0.45);
  --glow-hex: 0 0 0 3px rgba(210, 58, 51, 0.25);
  --glow-gold: 0 10px 30px rgba(179, 38, 43, 0.25);
  --font-mono: var(--font-label);
}
```

Puis supprimer de `main.css` les règles `.rb-glyph`, `.rb-glyph.ink`, `.rb-glyph.energy`, `.rb-kw` et ses variantes (`timing`, `combat`, `state`, `utility`, `arrow`), désormais dans `base.css`. Garder `.card-text` (interligne du texte de carte) : la tâche 6 pose cette classe sur `RiftText`.

Run : `grep -nE "^\s*(@font-face|--paper:|--line:|--ink:|--fury:|--font-display:|--font-body:)" src/assets/main.css`
Expected : une seule ligne, `--paper: var(--bg);`.

- [ ] **Step 10 : vérifier le build et les tests**

Run : `npm run build && npx vitest run`
Expected : build OK ; tous les tests PASS. Les polices Barlow apparaissent dans `dist/assets/`, et aucune `ibm-plex`, `marcellus` ni `outfit` : `ls dist/assets | grep -E "plex|marcellus|outfit"` ne renvoie rien.

- [ ] **Step 11 : commit**

```bash
git add src/styles src/assets/fonts src/main.js src/assets/main.css
git commit -m "Web : socle CSS Forge noxienne (tokens, polices Barlow, base)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : `RiftButton`

**Files :**
- Create : `src/ui/RiftButton.vue`, `src/ui/RiftButton.spec.js`

**Interfaces :**
- Produces : `<RiftButton variant="primary|secondary|ghost" size="sm|md" :to? :href? type="button" :disabled :block>slot</RiftButton>`. Rend un `RouterLink` si `to`, un `<a>` si `href`, sinon un `<button>`. Racine : classe `rift-btn` + `rift-btn--<variant>` + `rift-btn--<size>`.

- [ ] **Step 1 : écrire le test**

`src/ui/RiftButton.spec.js` :

```js
import { mount, RouterLinkStub } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftButton from "./RiftButton.vue"

const stubs = { RouterLink: RouterLinkStub }

describe("RiftButton", () => {
  it("rend un bouton type=button par défaut, en variante principale", () => {
    const wrapper = mount(RiftButton, { slots: { default: "Voir" }, global: { stubs } })
    const button = wrapper.get("button")
    expect(button.attributes("type")).toBe("button")
    expect(button.classes()).toEqual(expect.arrayContaining(["rift-btn", "rift-btn--primary", "rift-btn--md"]))
    expect(button.text()).toBe("Voir")
  })

  it("rend un lien du routeur quand `to` est fourni", () => {
    const wrapper = mount(RiftButton, { props: { to: "/cartes", variant: "secondary" }, global: { stubs } })
    const link = wrapper.getComponent(RouterLinkStub)
    expect(link.props("to")).toBe("/cartes")
    expect(link.classes()).toContain("rift-btn--secondary")
  })

  it("rend un lien externe quand `href` est fourni", () => {
    const wrapper = mount(RiftButton, { props: { href: "https://example.org" }, global: { stubs } })
    expect(wrapper.get("a").attributes("href")).toBe("https://example.org")
  })

  it("transmet disabled et type au bouton, et la taille sm", () => {
    const wrapper = mount(RiftButton, { props: { disabled: true, type: "submit", size: "sm" }, global: { stubs } })
    const button = wrapper.get("button")
    expect(button.attributes("disabled")).toBeDefined()
    expect(button.attributes("type")).toBe("submit")
    expect(button.classes()).toContain("rift-btn--sm")
  })

  it("émet le clic natif", async () => {
    const wrapper = mount(RiftButton, { global: { stubs } })
    await wrapper.get("button").trigger("click")
    expect(wrapper.emitted("click")).toHaveLength(1)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/ui/RiftButton.spec.js`
Expected : FAIL (`Failed to resolve import "./RiftButton.vue"`).

- [ ] **Step 3 : écrire `src/ui/RiftButton.vue`**

```vue
<script setup>
import { computed } from "vue"
import { RouterLink } from "vue-router"

/* Bouton de la Forge : principal (rouge biseauté), secondaire (filet de bronze),
   fantôme. Un seul composant pour les boutons et les liens d'action. */
const props = defineProps({
  variant: { type: String, default: "primary", validator: (v) => ["primary", "secondary", "ghost"].includes(v) },
  size: { type: String, default: "md", validator: (v) => ["sm", "md"].includes(v) },
  to: { type: [String, Object], default: null },
  href: { type: String, default: null },
  type: { type: String, default: "button" },
  disabled: { type: Boolean, default: false },
  block: { type: Boolean, default: false }
})
defineEmits(["click"])

const tag = computed(() => (props.to ? RouterLink : props.href ? "a" : "button"))
const bindings = computed(() => {
  if (props.to) return { to: props.to }
  if (props.href) return { href: props.href }
  return { type: props.type, disabled: props.disabled }
})
</script>

<template>
  <component
    :is="tag"
    v-bind="bindings"
    class="rift-btn"
    :class="[`rift-btn--${variant}`, `rift-btn--${size}`, { 'rift-btn--block': block }]"
    @click="$emit('click', $event)"
  >
    <slot />
  </component>
</template>

<style scoped>
.rift-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  min-height: 44px;
  padding: 0 var(--space-5);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  text-decoration: none;
  white-space: nowrap;
  color: var(--ink);
  transition:
    background-color var(--t-fast),
    color var(--t-fast),
    border-color var(--t-fast);
}
.rift-btn--sm {
  min-height: 36px;
  padding: 0 var(--space-4);
  font-size: 12px;
}
.rift-btn--primary {
  padding-inline: calc(var(--space-5) + var(--cut));
  background: var(--blood);
  color: #fff;
  clip-path: polygon(var(--cut) 0, 100% 0, calc(100% - var(--cut)) 100%, 0 100%);
}
.rift-btn--primary:hover,
.rift-btn--primary:focus-visible {
  background: var(--blood-bright);
  color: #fff;
}
/* Le biseau rogne le contour de focus : on le remplace par un liseré intérieur. */
.rift-btn--primary:focus-visible {
  outline: none;
  box-shadow: inset 0 0 0 2px var(--bronze-light);
}
.rift-btn--secondary {
  border: 1px solid var(--bronze);
  color: var(--bronze-light);
}
.rift-btn--secondary:hover {
  border-color: var(--bronze-light);
  color: var(--ink);
}
.rift-btn--ghost {
  color: var(--ink-muted);
}
.rift-btn--ghost:hover {
  color: var(--ink);
}
.rift-btn--block {
  width: 100%;
}
.rift-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/ui/RiftButton.spec.js`
Expected : PASS (5 tests).

- [ ] **Step 5 : commit**

```bash
git add src/ui/RiftButton.vue src/ui/RiftButton.spec.js
git commit -m "Web : composant RiftButton (principal biseauté, secondaire, fantôme)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : `RiftField` et `RiftTabs`

**Files :**
- Create : `src/ui/RiftField.vue`, `src/ui/RiftField.spec.js`, `src/ui/RiftTabs.vue`, `src/ui/RiftTabs.spec.js`

**Interfaces :**
- Produces : `<RiftField v-model label="…" :hide-label :search :error placeholder type />`. `inheritAttrs: false` : tous les attributs non déclarés (ARIA, `@keydown`, `autocomplete`…) vont sur l'`<input>`. Méthode exposée `focus()`.
- Produces : `<RiftTabs :items="[{ label, to }]" label="…" />`. Une `<nav aria-label>` de `RouterLink`. L'onglet actif (plus long préfixe de chemin) reçoit `aria-current="page"` et la classe `active`.

- [ ] **Step 1 : écrire les tests**

`src/ui/RiftField.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import RiftField from "./RiftField.vue"

const global = { components: { Icon } }

describe("RiftField", () => {
  it("relie le label à l'input et émet update:modelValue", async () => {
    const wrapper = mount(RiftField, { props: { label: "Nom", modelValue: "" }, global })
    const input = wrapper.get("input")
    expect(wrapper.get("label").attributes("for")).toBe(input.attributes("id"))
    await input.setValue("Ahri")
    expect(wrapper.emitted("update:modelValue")[0]).toEqual(["Ahri"])
  })

  it("masque visuellement le label sans le retirer", () => {
    const wrapper = mount(RiftField, { props: { label: "Recherche", hideLabel: true }, global })
    expect(wrapper.get("label").classes()).toContain("sr-only")
  })

  it("annonce l'erreur et marque l'input invalide", () => {
    const wrapper = mount(RiftField, { props: { label: "E-mail", error: "Adresse invalide" }, global })
    const input = wrapper.get("input")
    const error = wrapper.get(".rift-field-error")
    expect(input.attributes("aria-invalid")).toBe("true")
    expect(input.attributes("aria-describedby")).toBe(error.attributes("id"))
    expect(error.text()).toBe("Adresse invalide")
  })

  it("transmet les attributs et écouteurs non déclarés à l'input", async () => {
    let pressed = null
    const wrapper = mount(RiftField, {
      props: { label: "Recherche", search: true },
      attrs: { role: "combobox", "aria-expanded": "false", onKeydown: (event) => (pressed = event.key) },
      global
    })
    const input = wrapper.get("input")
    expect(input.attributes("role")).toBe("combobox")
    expect(input.attributes("type")).toBe("search")
    await input.trigger("keydown", { key: "ArrowDown" })
    expect(pressed).toBe("ArrowDown")
  })
})
```

`src/ui/RiftTabs.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import { makeRouter } from "../test/makeRouter.js"
import RiftTabs from "./RiftTabs.vue"

const ITEMS = [
  { label: "Apprendre", to: "/regles/debutant" },
  { label: "Plateau animé", to: "/regles/debutant/plateau" },
  { label: "Texte officiel", to: "/regles/officielles" }
]

describe("RiftTabs", () => {
  it("marque l'onglet du plus long préfixe comme page courante", async () => {
    const router = await makeRouter("/regles/debutant/plateau")
    const wrapper = mount(RiftTabs, { props: { items: ITEMS, label: "Règles" }, global: { plugins: [router] } })
    expect(wrapper.get("nav").attributes("aria-label")).toBe("Règles")
    const current = wrapper.findAll("a").filter((a) => a.attributes("aria-current") === "page")
    expect(current.map((a) => a.text())).toEqual(["Plateau animé"])
  })

  it("garde l'onglet parent actif sur une page fille sans onglet propre", async () => {
    const router = await makeRouter("/regles/debutant/victoire")
    const wrapper = mount(RiftTabs, { props: { items: ITEMS, label: "Règles" }, global: { plugins: [router] } })
    expect(wrapper.get("a.active").text()).toBe("Apprendre")
  })
})
```

`src/test/makeRouter.js` (helper de test, créé dans cette tâche) :

```js
import { createMemoryHistory, createRouter } from "vue-router"

/* Routeur mémoire pour les tests de la coquille : mêmes chemins que l'application,
   composants vides. `initial` est la page sur laquelle le test démarre. */
const Empty = { template: "<div />" }

export const APP_PATHS = [
  "/",
  "/cartes",
  "/cartes/:id",
  "/decks",
  "/decks/:id",
  "/communaute",
  "/collection",
  "/wishlist",
  "/regles",
  "/regles/debutant",
  "/regles/debutant/plateau",
  "/regles/debutant/:slug",
  "/regles/avancee",
  "/regles/avancee/:slug",
  "/regles/officielles",
  "/salon/:code?",
  "/historique",
  "/statistiques",
  "/profil",
  "/u/:handle",
  "/amis",
  "/admin",
  "/connexion",
  "/mentions-legales",
  "/confidentialite",
  "/cgu",
  "/cookies",
  "/signalement",
  "/:pathMatch(.*)*"
]

export async function makeRouter(initial = "/", paths = APP_PATHS) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: paths.map((path) => ({ path, component: Empty }))
  })
  router.push(initial)
  await router.isReady()
  return router
}
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/ui/RiftField.spec.js src/ui/RiftTabs.spec.js`
Expected : FAIL (modules introuvables).

- [ ] **Step 3 : écrire `src/ui/RiftField.vue`**

```vue
<script setup>
import { ref, useId } from "vue"

/* Champ de la Forge. Les attributs non déclarés (ARIA, écouteurs clavier,
   autocomplete…) vont sur l'<input>, pas sur l'enveloppe : la palette de
   recherche s'en sert pour en faire un combobox. */
defineOptions({ inheritAttrs: false })

const props = defineProps({
  label: { type: String, required: true },
  hideLabel: { type: Boolean, default: false },
  search: { type: Boolean, default: false },
  type: { type: String, default: "text" },
  placeholder: { type: String, default: "" },
  error: { type: String, default: "" }
})
const model = defineModel({ type: String, default: "" })

const id = useId()
const errorId = `${id}-error`
const input = ref(null)

defineExpose({ focus: () => input.value?.focus() })
</script>

<template>
  <div class="rift-field" :class="{ 'rift-field--search': search, 'rift-field--invalid': error }">
    <label :for="id" class="rift-field-label" :class="{ 'sr-only': hideLabel }">{{ label }}</label>
    <div class="rift-field-box">
      <Icon v-if="search" name="search" :size="16" class="rift-field-icon" />
      <input
        :id="id"
        ref="input"
        v-model="model"
        class="rift-field-input"
        :type="search ? 'search' : props.type"
        :placeholder="placeholder"
        :aria-invalid="error ? 'true' : undefined"
        :aria-describedby="error ? errorId : undefined"
        v-bind="$attrs"
      />
    </div>
    <p v-if="error" :id="errorId" class="rift-field-error">{{ error }}</p>
  </div>
</template>

<style scoped>
.rift-field {
  display: grid;
  gap: var(--space-1);
}
.rift-field-label {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.rift-field-box {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 44px;
  padding: 0 var(--space-3);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  transition: border-color var(--t-fast);
}
.rift-field-box:focus-within {
  border-color: var(--bronze-light);
}
.rift-field--invalid .rift-field-box {
  border-color: var(--blood-bright);
}
.rift-field-icon {
  flex: none;
  color: var(--ink-muted);
}
.rift-field-input {
  flex: 1;
  min-width: 0;
  background: none;
  border: none;
  color: var(--ink);
  font: inherit;
}
.rift-field-input:focus {
  outline: none;
}
.rift-field-input::placeholder {
  color: var(--ink-muted);
}
.rift-field-error {
  font-size: 13px;
  color: var(--blood-text);
}
</style>
```

- [ ] **Step 4 : écrire `src/ui/RiftTabs.vue`**

```vue
<script setup>
import { computed, nextTick, onMounted, ref } from "vue"
import { useRoute } from "vue-router"

/* Onglets de sous-rubriques. Sur téléphone ils défilent horizontalement ;
   l'onglet actif est ramené dans le champ au montage. */
const props = defineProps({
  items: { type: Array, required: true },
  label: { type: String, required: true }
})

const route = useRoute()
const list = ref(null)

/* Plus long préfixe : /regles/debutant/plateau active « Plateau animé », pas « Apprendre ». */
const activeTo = computed(() => {
  const path = route.path
  const matches = props.items.filter((item) => path === item.to || path.startsWith(`${item.to}/`))
  return matches.sort((a, b) => b.to.length - a.to.length)[0]?.to ?? null
})

onMounted(async () => {
  await nextTick()
  list.value?.querySelector(".active")?.scrollIntoView?.({ block: "nearest", inline: "center" })
})
</script>

<template>
  <nav class="rift-tabs" :aria-label="label">
    <ul ref="list">
      <li v-for="item in items" :key="item.to">
        <RouterLink
          :to="item.to"
          class="rift-tab"
          :class="{ active: item.to === activeTo }"
          :aria-current="item.to === activeTo ? 'page' : undefined"
          >{{ item.label }}</RouterLink
        >
      </li>
    </ul>
  </nav>
</template>

<style scoped>
.rift-tabs ul {
  display: flex;
  gap: var(--space-1);
  list-style: none;
  overflow-x: auto;
  scrollbar-width: none;
  border-bottom: 1px solid var(--line);
}
.rift-tabs ul::-webkit-scrollbar {
  display: none;
}
.rift-tab {
  display: block;
  padding: var(--space-3) var(--space-4);
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  white-space: nowrap;
  color: var(--ink-muted);
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
}
.rift-tab:hover {
  color: var(--ink);
}
.rift-tab.active {
  color: var(--ink);
  border-bottom-color: var(--blood-bright);
}
</style>
```

- [ ] **Step 5 : vérifier le succès**

Run : `npx vitest run src/ui/RiftField.spec.js src/ui/RiftTabs.spec.js`
Expected : PASS (6 tests).

- [ ] **Step 6 : commit**

```bash
git add src/ui/RiftField.vue src/ui/RiftField.spec.js src/ui/RiftTabs.vue src/ui/RiftTabs.spec.js src/test/makeRouter.js
git commit -m "Web : composants RiftField et RiftTabs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : `useDialog`, `RiftModal` (remplace `ModalDialog`)

**Files :**
- Create : `src/ui/useDialog.js`, `src/ui/RiftModal.vue`
- Move : `src/components/ModalDialog.spec.js` → `src/ui/RiftModal.spec.js` (adapté)
- Delete : `src/components/ModalDialog.vue`
- Modify : `src/components/DeckMissingModal.vue`, `src/views/AdminView.vue`, `src/views/CollectionView.vue`, `src/views/DeckEditView.vue`, `src/views/DecksView.vue`, `src/views/ProfileView.vue` (imports et balises) ; `src/assets/main.css` (règles `.modal*`) ; les specs de vues qui ciblent `.modal-*`

**Interfaces :**
- Produces : `useDialog(elementRef, close)`. À appeler dans `setup()`. Au montage : empile le dialogue, pose `body.nav-locked`, donne le focus au premier élément focusable (sinon à l'élément), écoute Échap (→ `close()`) et Tab (piège à focus) **pour le seul dialogue du dessus**. Au démontage : dépile, retire `nav-locked` si la pile est vide, rend le focus à l'élément qui l'avait à l'ouverture.
- Produces : `<RiftModal title="…" :wide @close>slot</RiftModal>`. Classes : `rift-modal-overlay`, `rift-modal`, `rift-modal-head`, `rift-modal-close`, `rift-modal-body`.

- [ ] **Step 1 : déplacer et adapter le test**

```bash
git mv src/components/ModalDialog.spec.js src/ui/RiftModal.spec.js
```

Dans `src/ui/RiftModal.spec.js` :
- `import ModalDialog from "./ModalDialog.vue"` devient `import RiftModal from "./RiftModal.vue"` ;
- `components: { ModalDialog }` devient `components: { RiftModal }`, et les balises `<ModalDialog …>` / `</ModalDialog>` du `template` deviennent `<RiftModal …>` / `</RiftModal>` ;
- `describe("ModalDialog"` devient `describe("RiftModal"` ;
- chaque `"modal-close"` devient `"rift-modal-close"`, et chaque sélecteur `.modal-overlay` / `.modal` devient `.rift-modal-overlay` / `.rift-modal`.

Les assertions métier (focus initial, boucle Tab, verrou `nav-locked`, modales empilées, restitution du focus) restent identiques.

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/ui/RiftModal.spec.js`
Expected : FAIL (`./RiftModal.vue` introuvable).

- [ ] **Step 3 : écrire `src/ui/useDialog.js`**

```js
import { nextTick, onBeforeUnmount, onMounted } from "vue"

/* Pile partagée par tous les dialogues (modale, feuille, palette) : un dialogue peut
   en ouvrir un autre (deck builder → cartes manquantes). Seul le dernier ouvert
   reçoit le clavier, et seul le dernier fermé rend son défilement à la page. */
const stack = []

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

export function useDialog(elementRef, close) {
  const token = Symbol("dialog")
  let opener = null

  const focusables = () => (elementRef.value ? [...elementRef.value.querySelectorAll(FOCUSABLE)] : [])

  /* Piège à focus : Tab et Shift+Tab bouclent à l'intérieur du dialogue. */
  function trapTab(event) {
    const items = focusables()
    if (!items.length) {
      event.preventDefault()
      elementRef.value?.focus()
      return
    }
    const first = items[0]
    const last = items[items.length - 1]
    const active = document.activeElement
    const inside = elementRef.value?.contains(active)
    if (event.shiftKey && (!inside || active === first)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && (!inside || active === last)) {
      event.preventDefault()
      first.focus()
    }
  }

  function onKeydown(event) {
    if (stack[stack.length - 1] !== token) return
    if (event.key === "Escape") close()
    else if (event.key === "Tab") trapTab(event)
  }

  onMounted(async () => {
    document.addEventListener("keydown", onKeydown)
    /* La classe et non un style inline : `overflow: hidden` en ligne ne retient pas iOS Safari. */
    stack.push(token)
    document.body.classList.add("nav-locked")
    opener = document.activeElement
    await nextTick()
    const target = focusables()[0] || elementRef.value
    target?.focus()
  })

  onBeforeUnmount(() => {
    document.removeEventListener("keydown", onKeydown)
    const index = stack.lastIndexOf(token)
    if (index !== -1) stack.splice(index, 1)
    if (!stack.length) document.body.classList.remove("nav-locked")
    /* Chaque dialogue rend le focus à SON déclencheur, s'il est encore dans la page. */
    if (opener && document.contains(opener)) opener.focus?.()
  })
}
```

- [ ] **Step 4 : écrire `src/ui/RiftModal.vue`**

```vue
<script setup>
import { ref, useId } from "vue"
import { useDialog } from "./useDialog.js"

const props = defineProps({
  title: { type: String, required: true },
  wide: { type: Boolean, default: false }
})
const emit = defineEmits(["close"])

const modal = ref(null)
const titleId = `${useId()}-title`
useDialog(modal, () => emit("close"))
</script>

<template>
  <Teleport to="body">
    <!-- @click.self et non @pointerdown.self : au doigt, un début de glissement
         sur le fond fermait la modale avant même le relâchement. -->
    <div class="rift-modal-overlay" @click.self="emit('close')">
      <div
        ref="modal"
        class="rift-modal"
        :class="{ wide: props.wide }"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="titleId"
        tabindex="-1"
      >
        <div class="rift-modal-head">
          <h3 :id="titleId">{{ title }}</h3>
          <button type="button" class="rift-modal-close" aria-label="Fermer" @click="emit('close')">✕</button>
        </div>
        <div class="rift-modal-body">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.rift-modal-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--z-overlay);
  display: grid;
  place-items: center;
  padding: var(--space-4);
  background: rgba(5, 4, 4, 0.78);
}
.rift-modal {
  width: min(560px, 100%);
  max-height: calc(100dvh - 2 * var(--space-4));
  display: flex;
  flex-direction: column;
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow:
    inset 0 0 0 1px var(--line),
    var(--shadow-deep);
  clip-path: polygon(
    var(--cut) 0,
    100% 0,
    100% calc(100% - var(--cut)),
    calc(100% - var(--cut)) 100%,
    0 100%,
    0 var(--cut)
  );
}
.rift-modal.wide {
  width: min(960px, 100%);
}
.rift-modal:focus {
  outline: none;
}
.rift-modal-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  padding: var(--space-4) var(--space-5);
  border-bottom: 1px solid var(--line);
}
.rift-modal-head h3 {
  font-size: 18px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.rift-modal-close {
  width: 44px;
  height: 44px;
  color: var(--ink-muted);
}
.rift-modal-close:hover {
  color: var(--ink);
}
.rift-modal-body {
  padding: var(--space-5);
  overflow-y: auto;
}
</style>
```

- [ ] **Step 5 : vérifier le succès du test du composant**

Run : `npx vitest run src/ui/RiftModal.spec.js`
Expected : PASS.

- [ ] **Step 6 : remplacer `ModalDialog` partout**

```bash
for f in src/views/AdminView.vue src/views/CollectionView.vue src/views/DeckEditView.vue src/views/DecksView.vue src/views/ProfileView.vue; do
  sed -i -e 's#import ModalDialog from "../components/ModalDialog.vue"#import RiftModal from "../ui/RiftModal.vue"#' \
         -e 's#<ModalDialog\b#<RiftModal#g' -e 's#</ModalDialog>#</RiftModal>#g' "$f"
done
sed -i -e 's#import ModalDialog from "./ModalDialog.vue"#import RiftModal from "../ui/RiftModal.vue"#' \
       -e 's#<ModalDialog\b#<RiftModal#g' -e 's#</ModalDialog>#</RiftModal>#g' src/components/DeckMissingModal.vue
git rm -q src/components/ModalDialog.vue
grep -rn "ModalDialog" src
```

Expected : le dernier `grep` ne renvoie rien.

- [ ] **Step 7 : retirer les styles de l'ancienne modale de `main.css` et adapter les sélecteurs restants**

Run : `grep -nE "\.modal(-[a-z]+)?\b" src/assets/main.css`

Pour chaque règle trouvée :
- si son sélecteur ne vise que la modale elle-même (`.modal-overlay`, `.modal`, `.modal.wide`, `.modal-head`, `.modal-head h3`, `.modal-close`, `.modal-body`, y compris dans les `@media`), **la supprimer** : ces styles vivent maintenant dans `RiftModal.vue` ;
- si elle vise un contenu de vue à l'intérieur de la modale (par exemple `.modal-body .entry-row`), **garder la règle** en renommant le préfixe (`.modal-body` → `.rift-modal-body`, `.modal` → `.rift-modal`).

Le contenu est rendu dans le slot, donc hors de la portée scoped de `RiftModal` : ces règles globales l'atteignent toujours.

Puis adapter les specs de vues :

Run : `grep -rln "modal-\(close\|body\|head\|overlay\)\|\.modal\b" src --include=*.spec.js`

Dans chaque fichier listé, remplacer `.modal-close` → `.rift-modal-close`, `.modal-body` → `.rift-modal-body`, `.modal-head` → `.rift-modal-head`, `.modal-overlay` → `.rift-modal-overlay`, `".modal"` → `".rift-modal"`.

- [ ] **Step 8 : vérifier toute la suite**

Run : `npx vitest run`
Expected : PASS.

- [ ] **Step 9 : commit**

```bash
git add -A src
git commit -m "Web : RiftModal remplace ModalDialog (pile de dialogues partagée)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : `RiftSheet`

**Files :**
- Create : `src/ui/RiftSheet.vue`, `src/ui/RiftSheet.spec.js`

**Interfaces :**
- Consumes : `useDialog` (tâche 4).
- Produces : `<RiftSheet title="…" @close>slot</RiftSheet>`. Feuille fixée en bas de l'écran, téléportée dans `body`. Classes : `rift-sheet-overlay`, `rift-sheet`, `rift-sheet-close`, `rift-sheet-body`.

- [ ] **Step 1 : écrire le test**

`src/ui/RiftSheet.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import RiftSheet from "./RiftSheet.vue"

const Host = {
  components: { RiftSheet },
  data: () => ({ open: true }),
  template: `<div><RiftSheet v-if="open" title="Compte" @close="open = false"><a href="/profil">Profil</a></RiftSheet></div>`
}

async function mountHost() {
  const wrapper = mount(Host, { attachTo: document.body, global: { components: { Icon } } })
  await nextTick()
  await nextTick()
  return wrapper
}

describe("RiftSheet", () => {
  afterEach(() => {
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("est un dialogue modal titré, qui bloque le défilement de la page", async () => {
    const wrapper = await mountHost()
    const dialog = document.querySelector(".rift-sheet")
    expect(dialog.getAttribute("role")).toBe("dialog")
    expect(document.getElementById(dialog.getAttribute("aria-labelledby")).textContent).toBe("Compte")
    expect(document.body.classList.contains("nav-locked")).toBe(true)
    wrapper.unmount()
  })

  it("se ferme sur Échap et rend le défilement", async () => {
    const wrapper = await mountHost()
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await nextTick()
    expect(document.querySelector(".rift-sheet")).toBeNull()
    expect(document.body.classList.contains("nav-locked")).toBe(false)
    wrapper.unmount()
  })

  it("se ferme au clic sur le voile, pas sur la feuille", async () => {
    const wrapper = await mountHost()
    document.querySelector(".rift-sheet").click()
    await nextTick()
    expect(document.querySelector(".rift-sheet")).not.toBeNull()
    document.querySelector(".rift-sheet-overlay").click()
    await nextTick()
    expect(document.querySelector(".rift-sheet")).toBeNull()
    wrapper.unmount()
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/ui/RiftSheet.spec.js`
Expected : FAIL (module introuvable).

- [ ] **Step 3 : écrire `src/ui/RiftSheet.vue`**

```vue
<script setup>
import { ref, useId } from "vue"
import { useDialog } from "./useDialog.js"

/* Feuille du bas (téléphone) : menu du compte, filtres. Même comportement
   clavier et même verrou de défilement que la modale. */
defineProps({ title: { type: String, required: true } })
const emit = defineEmits(["close"])

const sheet = ref(null)
const titleId = `${useId()}-title`
useDialog(sheet, () => emit("close"))
</script>

<template>
  <Teleport to="body">
    <div class="rift-sheet-overlay" @click.self="emit('close')">
      <div ref="sheet" class="rift-sheet" role="dialog" aria-modal="true" :aria-labelledby="titleId" tabindex="-1">
        <div class="rift-sheet-head">
          <h2 :id="titleId">{{ title }}</h2>
          <button type="button" class="rift-sheet-close" aria-label="Fermer" @click="emit('close')">
            <Icon name="x" :size="20" />
          </button>
        </div>
        <div class="rift-sheet-body">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.rift-sheet-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--z-overlay);
  display: flex;
  align-items: flex-end;
  background: rgba(5, 4, 4, 0.72);
}
.rift-sheet {
  width: 100%;
  max-height: 85dvh;
  overflow-y: auto;
  padding-bottom: env(safe-area-inset-bottom);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  animation: rift-sheet-in var(--t-base) ease-out;
}
.rift-sheet:focus {
  outline: none;
}
.rift-sheet-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3) var(--space-4);
  border-bottom: 1px solid var(--line);
}
.rift-sheet-head h2 {
  font-size: 16px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.rift-sheet-close {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  color: var(--ink-muted);
}
.rift-sheet-body {
  padding: var(--space-4);
}
@keyframes rift-sheet-in {
  from {
    transform: translateY(24px);
    opacity: 0;
  }
}
</style>
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/ui/RiftSheet.spec.js`
Expected : PASS (3 tests).

- [ ] **Step 5 : commit**

```bash
git add src/ui/RiftSheet.vue src/ui/RiftSheet.spec.js
git commit -m "Web : composant RiftSheet (feuille du bas)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : `RiftText` et `RiftGlyph` (remplacent `CardText` et `RuleText`)

**Files :**
- Create : `src/ui/richText.js`, `src/ui/richText.spec.js`, `src/ui/RiftGlyph.vue`, `src/ui/RiftText.vue`
- Move : `src/components/CardText.spec.js` → `src/ui/RiftText.spec.js` (adapté et complété)
- Delete : `src/components/CardText.vue`, `src/components/RuleText.vue`
- Modify : `src/components/CardHoverPreview.vue`, `src/views/CardView.vue`, `src/views/DeckEditView.vue`, `src/views/AdvancedTopicView.vue`, `src/views/LearnGuideView.vue`

**Interfaces :**
- Consumes : `parseCardText(text)` de `src/cardText.js` (parties `{ type: "text", value }`, `{ type: "keyword", label, family, arrow }`, `{ type: "glyph", kind: "ink"|"energy"|"rune", label, src }`).
- Produces : `expandRuleShorthand(text) → string`, `richSegments(text, { rules }) → [{ bold: boolean, parts: [part & { key }] }]`.
- Produces : `<RiftGlyph :part />` (texte, pastille `.rb-kw`, glyphe `.rb-glyph`).
- Produces : `<RiftText :text tag="span" :rules />`. Racine `<component :is="tag" class="rift-text">`.

- [ ] **Step 1 : écrire le test des fonctions pures**

`src/ui/richText.spec.js` :

```js
import { describe, expect, it } from "vitest"
import { expandRuleShorthand, richSegments } from "./richText.js"

describe("expandRuleShorthand", () => {
  it("convertit les symboles abrégés des règles officielles en shortcodes Riot", () => {
    expect(expandRuleShorthand("Payez [2] et [R], épuisez [E], gagnez [M].")).toBe(
      "Payez :rb_energy_2: et :rb_rune_fury:, épuisez :rb_exhaust:, gagnez :rb_might:."
    )
  })

  it("laisse en clair une énergie sans glyphe publié (au-delà de 12)", () => {
    expect(expandRuleShorthand("Coût [42]")).toBe("Coût [42]")
  })
})

describe("richSegments", () => {
  it("découpe le gras et analyse chaque segment", () => {
    const segments = richSegments("Avant **Assaut** après")
    expect(segments.map((s) => s.bold)).toEqual([false, true, false])
    expect(segments[1].parts[0]).toMatchObject({ type: "text", value: "Assaut" })
  })

  it("n'applique les abréviations qu'en mode règles", () => {
    const plain = richSegments("[R]")
    const rules = richSegments("[R]", { rules: true })
    expect(plain[0].parts[0].type).toBe("keyword")
    expect(rules[0].parts[0]).toMatchObject({ type: "glyph", kind: "rune" })
  })

  it("donne une clé distincte à chaque partie", () => {
    const keys = richSegments(":rb_might: [Assault 2] texte")[0].parts.map((p) => p.key)
    expect(new Set(keys).size).toBe(keys.length)
  })

  it("renvoie une liste vide pour un texte vide", () => {
    expect(richSegments("")).toEqual([])
    expect(richSegments(null)).toEqual([])
  })
})
```

- [ ] **Step 2 : déplacer et compléter le test de composant**

```bash
git mv src/components/CardText.spec.js src/ui/RiftText.spec.js
```

Dans `src/ui/RiftText.spec.js` :
- `import CardText from "./CardText.vue"` devient `import RiftText from "./RiftText.vue"` ;
- `describe("CardText"` devient `describe("RiftText"` ;
- chaque `mount(CardText, { props: { text: … } })` devient `mount(RiftText, { props: { text: … } })`.

Puis ajouter, dans le `describe`, ces deux tests :

```js
  it("rend la balise demandée avec la classe rift-text", () => {
    const wrapper = mount(RiftText, { props: { text: "Bonjour", tag: "p" } })
    expect(wrapper.element.tagName).toBe("P")
    expect(wrapper.classes()).toContain("rift-text")
    wrapper.unmount()
  })

  it("en mode règles, met le gras en <b> et convertit les abréviations", () => {
    const wrapper = mount(RiftText, { props: { text: "**Important** : payez [R].", rules: true } })
    expect(wrapper.get("b").text()).toBe("Important")
    expect(wrapper.get("img.rb-glyph.rune").attributes("alt")).toBe("Rune de Fureur")
    wrapper.unmount()
  })
```

- [ ] **Step 3 : vérifier l'échec**

Run : `npx vitest run src/ui/richText.spec.js src/ui/RiftText.spec.js`
Expected : FAIL (modules introuvables).

- [ ] **Step 4 : écrire `src/ui/richText.js`**

```js
import { parseCardText } from "../cardText.js"

/* Abréviations du texte officiel des règles ([R], [1], [E]…) → shortcodes Riot,
   que parseCardText sait ensuite rendre en glyphes. */
const SHORT_TOKENS = {
  R: ":rb_rune_fury:",
  G: ":rb_rune_calm:",
  B: ":rb_rune_mind:",
  O: ":rb_rune_body:",
  P: ":rb_rune_chaos:",
  Y: ":rb_rune_order:",
  C: ":rb_rune_rainbow:",
  E: ":rb_exhaust:",
  M: ":rb_might:"
}

/* Glyphes d'énergie publiés par Riot : de 0 à 12. Au-delà, aucun fichier n'existe :
   mieux vaut laisser « [42] » en clair qu'une image cassée. */
const MAX_ENERGY_GLYPH = 12

export function expandRuleShorthand(text) {
  return String(text ?? "").replace(/\[([RGBOPYCEM]|\d{1,2})\]/g, (raw, token) => {
    if (SHORT_TOKENS[token]) return SHORT_TOKENS[token]
    const amount = Number(token)
    return Number.isInteger(amount) && amount <= MAX_ENERGY_GLYPH ? `:rb_energy_${amount}:` : raw
  })
}

/* Segments gras / normal, chacun découpé en parties (texte, mot-clé, glyphe).
   Clé composite : l'index seul faisait réutiliser un nœud de texte pour un glyphe
   quand le texte changeait à la même position. */
export function richSegments(text, { rules = false } = {}) {
  if (!text) return []
  const source = rules ? expandRuleShorthand(text) : String(text)
  const segments = []
  for (const [i, chunk] of source.split("**").entries()) {
    if (!chunk) continue
    segments.push({
      bold: i % 2 === 1,
      parts: parseCardText(chunk).map((part, j) => ({
        ...part,
        key: `${i}-${j}-${part.type}-${part.kind || ""}-${part.value || part.label || ""}`
      }))
    })
  }
  return segments
}
```

- [ ] **Step 5 : écrire `src/ui/RiftGlyph.vue`**

```vue
<script setup>
/* Une partie de texte de jeu : texte brut, pastille de mot-clé ou glyphe officiel Riot.
   Les glyphes « ink » (puissance, épuisement) sont blancs à l'origine : teintés par masque. */
defineProps({ part: { type: Object, required: true } })
</script>

<template>
  <span v-if="part.type === 'text'">{{ part.value }}</span>
  <span v-else-if="part.type === 'keyword'" class="rb-kw" :class="[part.family, { arrow: part.arrow }]">{{
    part.label
  }}</span>
  <span
    v-else-if="part.kind === 'ink'"
    class="rb-glyph ink"
    :style="{ '--glyph': `url(${part.src})` }"
    role="img"
    :aria-label="part.label"
    :title="part.label"
  ></span>
  <img
    v-else
    class="rb-glyph"
    :class="part.kind"
    :src="part.src"
    :alt="part.label"
    :title="part.label"
    width="18"
    height="18"
    loading="lazy"
  />
</template>
```

- [ ] **Step 6 : écrire `src/ui/RiftText.vue`**

```vue
<script setup>
import { computed } from "vue"
import RiftGlyph from "./RiftGlyph.vue"
import { richSegments } from "./richText.js"

/* Seul rendu du texte de jeu du site : cartes (`tag="p"`), règles (`rules`), aide. */
const props = defineProps({
  text: { type: String, default: "" },
  tag: { type: String, default: "span" },
  rules: { type: Boolean, default: false }
})
const segments = computed(() => richSegments(props.text, { rules: props.rules }))
</script>

<template>
  <component :is="tag" class="rift-text">
    <component :is="segment.bold ? 'b' : 'span'" v-for="(segment, s) in segments" :key="s">
      <RiftGlyph v-for="part in segment.parts" :key="part.key" :part="part" />
    </component>
  </component>
</template>
```

- [ ] **Step 7 : vérifier le succès**

Run : `npx vitest run src/ui/richText.spec.js src/ui/RiftText.spec.js`
Expected : PASS.

- [ ] **Step 8 : remplacer `CardText` et `RuleText` partout**

Run d'abord : `grep -rn "<CardText[^>]*class=\|<RuleText[^>]*class=" src --include=*.vue`
Expected : rien. Sinon, fusionner à la main la classe existante avec `card-text` sur ces lignes avant de lancer le `sed`.

La classe `card-text` est conservée sur les textes de carte : `main.css` y accroche l'interligne (`.card-text`) et une règle descendante (`.builder-preview-copy .card-text`).

```bash
sed -i -e 's#import CardText from "./CardText.vue"#import RiftText from "../ui/RiftText.vue"#' \
       -e 's#<CardText #<RiftText tag="p" class="card-text" #g' src/components/CardHoverPreview.vue
for f in src/views/CardView.vue src/views/DeckEditView.vue; do
  sed -i -e 's#import CardText from "../components/CardText.vue"#import RiftText from "../ui/RiftText.vue"#' \
         -e 's#<CardText #<RiftText tag="p" class="card-text" #g' "$f"
done
for f in src/views/AdvancedTopicView.vue src/views/LearnGuideView.vue; do
  sed -i -e 's#import RuleText from "../components/RuleText.vue"#import RiftText from "../ui/RiftText.vue"#' \
         -e 's#<RuleText #<RiftText rules #g' "$f"
done
git rm -q src/components/CardText.vue src/components/RuleText.vue
grep -rn "CardText\|RuleText" src
```

Expected : le dernier `grep` ne renvoie que des noms de **tests** de vues, éventuellement (par exemple `findComponent({ name: "CardText" })`). Dans ce cas, les remplacer par `{ name: "RiftText" }`.

- [ ] **Step 9 : vérifier toute la suite et le lint**

Run : `npx vitest run && npx eslint src`
Expected : PASS, aucune erreur.

- [ ] **Step 10 : commit**

```bash
git add -A src
git commit -m "Web : RiftText remplace CardText et RuleText (un seul rendu du texte de jeu)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7 : navigation, palier d'écran, fil d'Ariane

**Files :**
- Create : `src/shell/navigation.js`, `src/shell/navigation.spec.js`, `src/shell/pageCrumb.js`, `src/composables/useBreakpoint.js`, `src/composables/useBreakpoint.spec.js`
- Modify : `src/components/Icon.vue` (nouvelles icônes)

**Interfaces :**
- Produces (`navigation.js`) :
  - `NAV` : `[{ key, label, to, icon, prefixes: string[], children?: [{ label, to }] }]`, avec `key` parmi `"home" | "cards" | "decks" | "collection" | "rules" | "play"` ;
  - `TABBAR_KEYS = ["home", "cards", "decks", "collection", "rules"]` ;
  - `ACCOUNT_LINKS = [{ label: "Profil", to: "/profil" }, { label: "Amis", to: "/amis" }]` ;
  - `activeSection(path) → section | null` ;
  - `activeChild(section, path) → child | null` ;
  - `breadcrumbOf(path, pageCrumb?) → [{ label, to? }]`.
- Produces (`pageCrumb.js`) : `pageCrumb` (ref<string|null>), `setPageCrumb(label)`, `clearPageCrumb()`.
- Produces (`useBreakpoint.js`) : `useBreakpoint() → Ref<"mobile" | "tablet" | "desktop">` (mobile < 768 px, tablet < 1 024 px).
- Produces (`Icon.vue`) : nouveaux noms `home`, `cards`, `decks`, `collection`, `rules`, `play`, `user`, `collapse`.

- [ ] **Step 1 : écrire les tests**

`src/shell/navigation.spec.js` :

```js
import { describe, expect, it } from "vitest"
import { activeChild, activeSection, breadcrumbOf, NAV, TABBAR_KEYS } from "./navigation.js"

describe("activeSection", () => {
  it.each([
    ["/", "home"],
    ["/cartes", "cards"],
    ["/cartes/ogn-001", "cards"],
    ["/decks/42", "decks"],
    ["/communaute", "decks"],
    ["/wishlist", "collection"],
    ["/regles/officielles", "rules"],
    ["/salon/ABCD", "play"],
    ["/historique", "play"]
  ])("%s → %s", (path, key) => {
    expect(activeSection(path)?.key).toBe(key)
  })

  it("ne confond pas un préfixe partiel ni une page hors rubrique", () => {
    expect(activeSection("/cartesX")).toBeNull()
    expect(activeSection("/profil")).toBeNull()
    expect(activeSection("/mentions-legales")).toBeNull()
  })
})

describe("activeChild", () => {
  const rules = NAV.find((s) => s.key === "rules")
  it("préfère le plus long préfixe", () => {
    expect(activeChild(rules, "/regles/debutant/plateau")?.label).toBe("Plateau animé")
    expect(activeChild(rules, "/regles/debutant/victoire")?.label).toBe("Apprendre")
  })
  it("renvoie null sur la page d'accueil de la rubrique ou sans enfants", () => {
    expect(activeChild(rules, "/regles")).toBeNull()
    expect(activeChild(NAV.find((s) => s.key === "cards"), "/cartes")).toBeNull()
  })
})

describe("breadcrumbOf", () => {
  it("rubrique puis sous-page, sans doublon de libellé", () => {
    expect(breadcrumbOf("/wishlist")).toEqual([{ label: "Collection", to: "/collection" }, { label: "Wishlist", to: "/wishlist" }])
    expect(breadcrumbOf("/collection")).toEqual([{ label: "Collection", to: "/collection" }])
  })
  it("ajoute le maillon fourni par la page", () => {
    expect(breadcrumbOf("/cartes/ogn-001", "Ahri")).toEqual([{ label: "Cartes", to: "/cartes" }, { label: "Ahri" }])
  })
  it("accueil et pages hors rubrique", () => {
    expect(breadcrumbOf("/")).toEqual([{ label: "Accueil", to: "/" }])
    expect(breadcrumbOf("/profil", "Mon profil")).toEqual([{ label: "Mon profil" }])
  })
})

it("la barre d'onglets mobile garde Accueil et ne contient pas Jouer", () => {
  expect(TABBAR_KEYS).toEqual(["home", "cards", "decks", "collection", "rules"])
})
```

`src/composables/useBreakpoint.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it, vi } from "vitest"
import { defineComponent, h, nextTick } from "vue"
import { useBreakpoint } from "./useBreakpoint.js"

function stubMatchMedia(width) {
  const listeners = []
  const queries = new Map()
  window.matchMedia = vi.fn((query) => {
    const max = Number(query.match(/max-width:\s*(\d+)px/)[1])
    const mql = {
      get matches() {
        return width.value <= max
      },
      addEventListener: (_type, fn) => listeners.push(fn),
      removeEventListener: (_type, fn) => listeners.splice(listeners.indexOf(fn), 1)
    }
    queries.set(query, mql)
    return mql
  })
  return { fire: () => listeners.forEach((fn) => fn()), listeners }
}

const Probe = defineComponent({
  setup() {
    const breakpoint = useBreakpoint()
    return () => h("span", breakpoint.value)
  }
})

const original = window.matchMedia
afterEach(() => {
  window.matchMedia = original
})

describe("useBreakpoint", () => {
  it.each([
    [390, "mobile"],
    [800, "tablet"],
    [1440, "desktop"]
  ])("%i px → %s", (px, expected) => {
    stubMatchMedia({ value: px })
    expect(mount(Probe).text()).toBe(expected)
  })

  it("suit les changements de taille et se désabonne au démontage", async () => {
    const width = { value: 1440 }
    const media = stubMatchMedia(width)
    const wrapper = mount(Probe)
    width.value = 390
    media.fire()
    await nextTick()
    expect(wrapper.text()).toBe("mobile")
    wrapper.unmount()
    expect(media.listeners).toHaveLength(0)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/shell/navigation.spec.js src/composables/useBreakpoint.spec.js`
Expected : FAIL (modules introuvables).

- [ ] **Step 3 : écrire `src/shell/navigation.js`**

```js
/* Table unique de la navigation : le rail, la barre d'onglets mobile, les sous-onglets,
   le fil d'Ariane et la recherche universelle (groupe « Pages ») la lisent tous.
   `prefixes` : chemins qui appartiennent à la rubrique (correspondance exacte ou
   suivie de « / », pour que /cartesX ne soit pas pris pour /cartes). */
export const NAV = [
  { key: "home", label: "Accueil", to: "/", icon: "home", prefixes: [] },
  { key: "cards", label: "Cartes", to: "/cartes", icon: "cards", prefixes: ["/cartes"] },
  {
    key: "decks",
    label: "Decks",
    to: "/decks",
    icon: "decks",
    prefixes: ["/decks", "/communaute"],
    children: [
      { label: "Mes decks", to: "/decks" },
      { label: "Communauté", to: "/communaute" }
    ]
  },
  {
    key: "collection",
    label: "Collection",
    to: "/collection",
    icon: "collection",
    prefixes: ["/collection", "/wishlist"],
    children: [
      { label: "Collection", to: "/collection" },
      { label: "Wishlist", to: "/wishlist" }
    ]
  },
  {
    key: "rules",
    label: "Règles",
    to: "/regles",
    icon: "rules",
    prefixes: ["/regles"],
    children: [
      { label: "Apprendre", to: "/regles/debutant" },
      { label: "Plateau animé", to: "/regles/debutant/plateau" },
      { label: "Aide avancée", to: "/regles/avancee" },
      { label: "Texte officiel", to: "/regles/officielles" }
    ]
  },
  {
    key: "play",
    label: "Jouer",
    to: "/salon",
    icon: "play",
    prefixes: ["/salon", "/historique", "/statistiques"],
    children: [
      { label: "Salon", to: "/salon" },
      { label: "Historique", to: "/historique" },
      { label: "Statistiques", to: "/statistiques" }
    ]
  }
]

/* Téléphone : cinq onglets, les mêmes que l'app Flutter. Jouer passe par l'avatar. */
export const TABBAR_KEYS = ["home", "cards", "decks", "collection", "rules"]

export const ACCOUNT_LINKS = [
  { label: "Profil", to: "/profil" },
  { label: "Amis", to: "/amis" }
]

const within = (path, prefix) => path === prefix || path.startsWith(`${prefix}/`)

export function activeSection(path) {
  if (path === "/") return NAV[0]
  return NAV.find((section) => section.prefixes.some((prefix) => within(path, prefix))) ?? null
}

export function activeChild(section, path) {
  if (!section?.children) return null
  const matches = section.children.filter((child) => within(path, child.to))
  return matches.sort((a, b) => b.to.length - a.to.length)[0] ?? null
}

/* Rubrique › sous-page › maillon de la page (nom d'une carte, d'un deck…). */
export function breadcrumbOf(path, pageCrumb = null) {
  const crumbs = []
  const section = activeSection(path)
  if (section) {
    crumbs.push({ label: section.label, to: section.to })
    const child = activeChild(section, path)
    if (child && child.label !== section.label) crumbs.push({ label: child.label, to: child.to })
  }
  if (pageCrumb) crumbs.push({ label: pageCrumb })
  return crumbs
}
```

- [ ] **Step 4 : écrire `src/shell/pageCrumb.js`**

```js
import { ref } from "vue"

/* Dernier maillon du fil d'Ariane, fourni par la page affichée (nom de la carte, du
   deck…). La coquille le vide à chaque changement de page. */
export const pageCrumb = ref(null)

export function setPageCrumb(label) {
  pageCrumb.value = label || null
}

export function clearPageCrumb() {
  pageCrumb.value = null
}
```

- [ ] **Step 5 : écrire `src/composables/useBreakpoint.js`**

```js
import { onBeforeUnmount, ref } from "vue"

/* Paliers de la coquille : téléphone (< 768 px : onglets du bas), tablette
   (< 1 024 px : rail replié par défaut), bureau. */
const MOBILE = "(max-width: 767px)"
const TABLET = "(max-width: 1023px)"

export function useBreakpoint() {
  const media = typeof window !== "undefined" && window.matchMedia ? window.matchMedia.bind(window) : null
  const mobile = media?.(MOBILE)
  const tablet = media?.(TABLET)
  const compute = () => (mobile?.matches ? "mobile" : tablet?.matches ? "tablet" : "desktop")
  const breakpoint = ref(compute())
  const update = () => {
    breakpoint.value = compute()
  }
  mobile?.addEventListener?.("change", update)
  tablet?.addEventListener?.("change", update)
  onBeforeUnmount(() => {
    mobile?.removeEventListener?.("change", update)
    tablet?.removeEventListener?.("change", update)
  })
  return breakpoint
}
```

- [ ] **Step 6 : ajouter les icônes de navigation dans `src/components/Icon.vue`**

Insérer, avant `<!-- loupe -->`, ces groupes (style existant : contour, `currentColor`) :

```vue
    <!-- accueil -->
    <g v-else-if="name === 'home'">
      <path d="M3.5 11.2 12 4l8.5 7.2" />
      <path d="M6 9.6V20h12V9.6" />
      <path d="M10 20v-5.4h4V20" />
    </g>
    <!-- cartes (éventail) -->
    <g v-else-if="name === 'cards'">
      <rect x="7.6" y="3.6" width="10.4" height="14.8" rx="1.4" />
      <path d="M5.6 6.6 4 7.1a1.2 1.2 0 0 0-.8 1.5l3.4 11a1.2 1.2 0 0 0 1.5.8l6-1.8" />
    </g>
    <!-- decks (pile) -->
    <g v-else-if="name === 'decks'">
      <path d="M12 3.6 20.4 8 12 12.4 3.6 8 12 3.6Z" />
      <path d="M3.6 12 12 16.4 20.4 12" />
      <path d="M3.6 16 12 20.4 20.4 16" />
    </g>
    <!-- collection (classeur) -->
    <g v-else-if="name === 'collection'">
      <rect x="4.4" y="3.6" width="15.2" height="16.8" rx="1.4" />
      <path d="M12 3.6v16.8" />
      <path d="M7 8h2.6M7 12h2.6M14.4 8H17M14.4 12H17" />
    </g>
    <!-- règles (livre ouvert) -->
    <g v-else-if="name === 'rules'">
      <path d="M12 6.4c-2-1.6-4.8-2-8-1.6v13.6c3.2-.4 6 0 8 1.6 2-1.6 4.8-2 8-1.6V4.8c-3.2-.4-6 0-8 1.6Z" />
      <path d="M12 6.4V20" />
    </g>
    <!-- jouer (épées croisées) -->
    <g v-else-if="name === 'play'">
      <path d="M4 4l9.6 9.6M4 4h3.4L17 13.6M4 4v3.4" />
      <path d="M20 4l-9.6 9.6M20 4h-3.4M20 4v3.4" />
      <path d="M8.4 15.6 5.2 18.8M15.6 15.6l3.2 3.2" />
    </g>
    <!-- compte (silhouette) -->
    <g v-else-if="name === 'user'">
      <circle cx="12" cy="8.4" r="3.8" />
      <path d="M4.4 20.4c.8-3.8 3.8-6 7.6-6s6.8 2.2 7.6 6" />
    </g>
    <!-- replier le rail -->
    <g v-else-if="name === 'collapse'">
      <path d="M14.6 6.4 9 12l5.6 5.6" />
      <path d="M19.4 6.4 13.8 12l5.6 5.6" opacity=".5" />
    </g>
```

- [ ] **Step 7 : vérifier le succès**

Run : `npx vitest run src/shell/navigation.spec.js src/composables/useBreakpoint.spec.js`
Expected : PASS.

- [ ] **Step 8 : commit**

```bash
git add src/shell/navigation.js src/shell/navigation.spec.js src/shell/pageCrumb.js src/composables/useBreakpoint.js src/composables/useBreakpoint.spec.js src/components/Icon.vue
git commit -m "Web : table de navigation, fil d'Ariane et paliers d'écran de la coquille

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8 : rail latéral et menu du compte (bureau)

**Files :**
- Create : `src/shell/useLogout.js`, `src/shell/AccountMenu.vue`, `src/shell/AccountMenu.spec.js`, `src/shell/AppRail.vue`, `src/shell/AppRail.spec.js`

**Interfaces :**
- Consumes : `NAV`, `activeSection`, `activeChild`, `ACCOUNT_LINKS` (tâche 7) ; `session`, `api`, `setSession` (`src/api.js`) ; `RiftButton` (tâche 2) ; `Logo.vue`, `UserAvatar.vue` ; `CLOSED_BETA` (`src/legal.js`).
- Produces : `useLogout() → { loggingOut: Ref<boolean>, logout(): Promise<void> }`. Appelle `POST /api/auth/logout` (échec ignoré), puis `setSession(null, null)`, puis `router.push("/")`. Réentrance bloquée.
- Produces : `<AccountMenu :compact />`, `<AppRail :collapsed @toggle />`.

- [ ] **Step 1 : écrire les tests**

`src/shell/AccountMenu.spec.js` :

```js
import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AccountMenu from "./AccountMenu.vue"

async function mountMenu() {
  const router = await makeRouter("/cartes")
  const wrapper = mount(AccountMenu, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
  return { wrapper, router }
}

describe("AccountMenu", () => {
  beforeEach(() => {
    Object.assign(session, { token: "1", handle: "Kaelis", avatarUrl: null, isAdmin: false })
    globalThis.fetch = vi.fn(async () => ({ ok: true, status: 204, json: async () => ({}) }))
  })
  afterEach(() => {
    Object.assign(session, { token: null, handle: null, isAdmin: null })
    document.body.innerHTML = ""
  })

  it("déroule Profil, Amis et Déconnexion ; Administration seulement pour un admin", async () => {
    const { wrapper } = await mountMenu()
    await wrapper.get(".account-btn").trigger("click")
    expect(wrapper.findAll("[role=menuitem]").map((item) => item.text())).toEqual(["Profil", "Amis", "Déconnexion"])
    session.isAdmin = true
    await wrapper.vm.$nextTick()
    expect(wrapper.text()).toContain("Administration")
    wrapper.unmount()
  })

  it("se ferme sur Échap et au clic à l'extérieur", async () => {
    const { wrapper } = await mountMenu()
    await wrapper.get(".account-btn").trigger("click")
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    await wrapper.vm.$nextTick()
    expect(wrapper.find("[role=menu]").exists()).toBe(false)
    await wrapper.get(".account-btn").trigger("click")
    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }))
    await wrapper.vm.$nextTick()
    expect(wrapper.find("[role=menu]").exists()).toBe(false)
    wrapper.unmount()
  })

  it("la déconnexion ferme la session et revient à l'accueil", async () => {
    const { wrapper, router } = await mountMenu()
    await wrapper.get(".account-btn").trigger("click")
    await wrapper.findAll("[role=menuitem]").at(-1).trigger("click")
    await flushPromises()
    expect(globalThis.fetch).toHaveBeenCalledWith("/api/auth/logout", expect.objectContaining({ method: "POST" }))
    expect(session.token).toBeNull()
    expect(router.currentRoute.value.path).toBe("/")
    wrapper.unmount()
  })
})
```

`src/shell/AppRail.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AppRail from "./AppRail.vue"

async function mountRail(path, props = {}) {
  const router = await makeRouter(path)
  return mount(AppRail, { props, global: { plugins: [router], components: { Icon } } })
}

describe("AppRail", () => {
  afterEach(() => {
    Object.assign(session, { token: null, handle: null })
  })

  it("liste les six rubriques et marque la rubrique et la sous-page actives", async () => {
    const wrapper = await mountRail("/wishlist")
    const items = wrapper.findAll(".rail-item")
    expect(items.map((item) => item.text())).toEqual(["Accueil", "Cartes", "Decks", "Collection", "Règles", "Jouer"])
    expect(wrapper.get(".rail-item.active").text()).toBe("Collection")
    expect(wrapper.get(".rail-item.active").attributes("aria-current")).toBe("true")
    expect(wrapper.get(".rail-sub a[aria-current=page]").text()).toBe("Wishlist")
  })

  it("ne déplie que les sous-pages de la rubrique active", async () => {
    const wrapper = await mountRail("/cartes")
    expect(wrapper.find(".rail-sub").exists()).toBe(false)
    expect(wrapper.get(".rail-item.active").attributes("aria-current")).toBe("page")
  })

  it("replié : masque les libellés, garde les infobulles, émet toggle", async () => {
    const wrapper = await mountRail("/decks", { collapsed: true })
    expect(wrapper.find(".rail-label").exists()).toBe(false)
    expect(wrapper.find(".rail-sub").exists()).toBe(false)
    expect(wrapper.get(".rail-item.active").attributes("title")).toBe("Decks")
    await wrapper.get(".rail-collapse").trigger("click")
    expect(wrapper.emitted("toggle")).toHaveLength(1)
    expect(wrapper.get(".rail-collapse").attributes("aria-label")).toBe("Déplier le menu")
  })

  it("propose la connexion à un visiteur, le menu du compte à un membre", async () => {
    let wrapper = await mountRail("/")
    expect(wrapper.text()).toContain("Connexion")
    Object.assign(session, { token: "1", handle: "Kaelis" })
    wrapper = await mountRail("/")
    expect(wrapper.find(".account-btn").exists()).toBe(true)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/shell/AccountMenu.spec.js src/shell/AppRail.spec.js`
Expected : FAIL (modules introuvables).

- [ ] **Step 3 : écrire `src/shell/useLogout.js`**

```js
import { ref } from "vue"
import { useRouter } from "vue-router"
import { api, setSession } from "../api.js"

/* Déconnexion partagée par le menu du compte (bureau) et la feuille (téléphone).
   Réentrance bloquée : deux clics rapides enverraient deux POST /logout. */
export function useLogout() {
  const router = useRouter()
  const loggingOut = ref(false)

  async function logout() {
    if (loggingOut.value) return
    loggingOut.value = true
    try {
      await api("/api/auth/logout", { method: "POST" })
    } catch {
      /* la session locale se ferme même si le cookie a déjà expiré */
    }
    setSession(null, null)
    loggingOut.value = false
    router.push("/")
  }

  return { loggingOut, logout }
}
```

- [ ] **Step 4 : écrire `src/shell/AccountMenu.vue`**

```vue
<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute } from "vue-router"
import { session } from "../api.js"
import UserAvatar from "../components/UserAvatar.vue"
import { ACCOUNT_LINKS } from "./navigation.js"
import { useLogout } from "./useLogout.js"

/* Menu du compte, en bas du rail : il s'ouvre vers le haut. */
defineProps({ compact: { type: Boolean, default: false } })

const route = useRoute()
const open = ref(false)
const root = ref(null)
const { loggingOut, logout } = useLogout()

watch(
  () => route.fullPath,
  () => {
    open.value = false
  }
)

/* pointerdown : précède la navigation du lien cliqué ailleurs dans la page. */
function onPointerDown(event) {
  if (open.value && root.value && !root.value.contains(event.target)) open.value = false
}
function onKeydown(event) {
  if (event.key === "Escape") open.value = false
}

onMounted(() => {
  window.addEventListener("pointerdown", onPointerDown)
  window.addEventListener("keydown", onKeydown)
})
onBeforeUnmount(() => {
  window.removeEventListener("pointerdown", onPointerDown)
  window.removeEventListener("keydown", onKeydown)
})
</script>

<template>
  <div ref="root" class="account">
    <button
      type="button"
      class="account-btn"
      :aria-expanded="open"
      aria-haspopup="menu"
      aria-controls="menu-compte"
      :title="`Compte de ${session.handle}`"
      @click="open = !open"
    >
      <UserAvatar :src="session.avatarUrl" :handle="session.handle" :size="28" />
      <span v-if="!compact" class="account-name">{{ session.handle }}</span>
      <Icon v-if="!compact" name="chevron" :size="14" class="account-chevron" />
    </button>
    <div v-if="open" id="menu-compte" class="account-menu" role="menu" aria-label="Mon compte">
      <RouterLink v-for="link in ACCOUNT_LINKS" :key="link.to" role="menuitem" :to="link.to">{{
        link.label
      }}</RouterLink>
      <RouterLink v-if="session.isAdmin" role="menuitem" to="/admin">Administration</RouterLink>
      <button role="menuitem" type="button" :disabled="loggingOut" @click="logout">Déconnexion</button>
    </div>
  </div>
</template>

<style scoped>
.account {
  position: relative;
}
.account-btn {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  min-height: 44px;
  padding: var(--space-1) var(--space-2);
  color: var(--ink);
  text-align: left;
}
.account-btn:hover {
  background: rgba(255, 255, 255, 0.04);
}
.account-name {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}
.account-chevron {
  transform: rotate(180deg);
  color: var(--ink-muted);
}
.account-menu {
  position: absolute;
  left: 0;
  bottom: calc(100% + var(--space-2));
  z-index: var(--z-overlay);
  display: grid;
  min-width: 200px;
  padding: var(--space-1);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow:
    inset 0 0 0 1px var(--line),
    var(--shadow-deep);
}
.account-menu a,
.account-menu button {
  display: block;
  padding: var(--space-2) var(--space-3);
  text-align: left;
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.account-menu a:hover,
.account-menu button:hover,
.account-menu a:focus-visible,
.account-menu button:focus-visible {
  background: rgba(179, 38, 43, 0.25);
  color: #fff;
}
</style>
```

- [ ] **Step 5 : écrire `src/shell/AppRail.vue`**

```vue
<script setup>
import { computed } from "vue"
import { useRoute } from "vue-router"
import { session } from "../api.js"
import Logo from "../components/Logo.vue"
import { CLOSED_BETA } from "../legal.js"
import RiftButton from "../ui/RiftButton.vue"
import AccountMenu from "./AccountMenu.vue"
import { activeChild, activeSection, NAV } from "./navigation.js"

/* Rail latéral de la Forge (bureau et tablette). Seules les sous-pages de la
   rubrique active sont dépliées, pour que le rail reste court. */
defineProps({ collapsed: { type: Boolean, default: false } })
const emit = defineEmits(["toggle"])

const route = useRoute()
const section = computed(() => activeSection(route.path))
const child = computed(() => activeChild(section.value, route.path))

/* Rubrique à sous-pages : « true » (on est dans la rubrique), la page exacte est la
   sous-page. Rubrique sans sous-pages : c'est la page elle-même. */
function sectionCurrent(item) {
  if (item !== section.value) return undefined
  return item.children ? "true" : "page"
}
</script>

<template>
  <aside class="rail" :class="{ collapsed }">
    <RouterLink to="/" class="rail-brand" aria-label="Riftarium, accueil">
      <Logo />
      <span v-if="!collapsed" class="rail-name">Riftarium</span>
    </RouterLink>
    <span v-if="!collapsed" class="rail-beta">{{ CLOSED_BETA ? "bêta fermée" : "bêta" }}</span>

    <nav class="rail-nav" aria-label="Navigation principale">
      <ul>
        <li v-for="item in NAV" :key="item.key">
          <RouterLink
            :to="item.to"
            class="rail-item"
            :class="{ active: item === section }"
            :aria-current="sectionCurrent(item)"
            :title="collapsed ? item.label : undefined"
          >
            <Icon :name="item.icon" :size="18" />
            <span v-if="!collapsed" class="rail-label">{{ item.label }}</span>
          </RouterLink>
          <ul v-if="!collapsed && item === section && item.children" class="rail-sub">
            <li v-for="sub in item.children" :key="sub.to">
              <RouterLink
                :to="sub.to"
                :class="{ active: sub === child }"
                :aria-current="sub === child ? 'page' : undefined"
                >{{ sub.label }}</RouterLink
              >
            </li>
          </ul>
        </li>
      </ul>
    </nav>

    <div class="rail-foot">
      <AccountMenu v-if="session.token" :compact="collapsed" />
      <RiftButton v-else-if="!collapsed" to="/connexion" size="sm" block>Connexion</RiftButton>
      <RouterLink v-else to="/connexion" class="rail-item" title="Connexion"><Icon name="user" :size="18" /></RouterLink>
      <button
        type="button"
        class="rail-collapse"
        :aria-label="collapsed ? 'Déplier le menu' : 'Replier le menu'"
        :aria-expanded="!collapsed"
        @click="emit('toggle')"
      >
        <Icon name="collapse" :size="18" />
      </button>
    </div>
  </aside>
</template>

<style scoped>
.rail {
  position: fixed;
  inset: 0 auto 0 0;
  z-index: var(--z-rail);
  width: var(--rail-w);
  display: flex;
  flex-direction: column;
  padding: var(--space-4) 0 var(--space-3);
  background: var(--bg-sunken);
  border-right: 2px solid var(--blood);
}
.rail.collapsed {
  width: var(--rail-w-collapsed);
}
.rail-brand {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  padding: 0 var(--space-4);
  color: var(--ink);
}
.rail.collapsed .rail-brand {
  justify-content: center;
  padding: 0;
}
.rail-brand :deep(.logo) {
  width: 30px;
  height: 30px;
  flex: none;
}
.rail-name {
  font-family: var(--font-display);
  font-size: 17px;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.rail-beta {
  margin: var(--space-1) var(--space-4) 0 calc(var(--space-4) + 38px);
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.rail-nav {
  flex: 1;
  margin-top: var(--space-5);
  overflow-y: auto;
}
.rail-nav ul {
  list-style: none;
}
.rail-item {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-height: 44px;
  padding: 0 var(--space-4);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.rail.collapsed .rail-item {
  justify-content: center;
  padding: 0;
}
.rail-item:hover {
  color: var(--ink);
}
.rail-item.active {
  color: #fff;
  background: linear-gradient(90deg, rgba(179, 38, 43, 0.35), transparent);
  box-shadow: inset 3px 0 0 var(--blood-bright);
}
.rail-sub a {
  display: block;
  padding: var(--space-2) var(--space-4) var(--space-2) calc(var(--space-4) + 30px);
  font-size: 14px;
  color: var(--ink-muted);
}
.rail-sub a:hover {
  color: var(--ink);
}
.rail-sub a.active {
  color: var(--bronze-light);
}
.rail-foot {
  display: grid;
  gap: var(--space-2);
  padding: var(--space-3) var(--space-3) 0;
  border-top: 1px solid var(--line);
}
.rail-collapse {
  display: grid;
  place-items: center;
  height: 36px;
  color: var(--ink-muted);
}
.rail-collapse:hover {
  color: var(--ink);
}
.rail.collapsed .rail-collapse {
  transform: rotate(180deg);
}
</style>
```

- [ ] **Step 6 : vérifier le succès**

Run : `npx vitest run src/shell/AccountMenu.spec.js src/shell/AppRail.spec.js`
Expected : PASS (7 tests).

- [ ] **Step 7 : commit**

```bash
git add src/shell/useLogout.js src/shell/AccountMenu.vue src/shell/AccountMenu.spec.js src/shell/AppRail.vue src/shell/AppRail.spec.js
git commit -m "Web : rail latéral et menu du compte

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9 : barre haute, onglets mobiles, feuille du compte

**Files :**
- Create : `src/shell/AppTopbar.vue`, `src/shell/AppTopbar.spec.js`, `src/shell/AppTabbar.vue`, `src/shell/AppTabbar.spec.js`, `src/shell/AccountSheet.vue`, `src/shell/AccountSheet.spec.js`

**Interfaces :**
- Consumes : `breadcrumbOf`, `NAV`, `TABBAR_KEYS`, `activeSection` (tâche 7) ; `pageCrumb` (tâche 7) ; `RiftSheet` (tâche 5) ; `RiftButton` (tâche 2) ; `useLogout` (tâche 8).
- Produces : `<AppTopbar :mobile @search @account />` ; `<AppTabbar />` ; `<AccountSheet @close />`.

- [ ] **Step 1 : écrire les tests**

`src/shell/AppTopbar.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AppTopbar from "./AppTopbar.vue"
import { clearPageCrumb, setPageCrumb } from "./pageCrumb.js"

async function mountBar(path, props = {}) {
  const router = await makeRouter(path)
  return mount(AppTopbar, { props, global: { plugins: [router], components: { Icon } } })
}

describe("AppTopbar", () => {
  afterEach(() => {
    clearPageCrumb()
    Object.assign(session, { token: null, handle: null })
  })

  it("bureau : fil d'Ariane, dernier maillon non cliquable", async () => {
    setPageCrumb("Ahri")
    const wrapper = await mountBar("/cartes/ogn-001")
    const items = wrapper.findAll(".crumbs li")
    expect(items.map((li) => li.text())).toEqual(["Cartes", "Ahri"])
    expect(items[0].find("a").exists()).toBe(true)
    expect(items[1].get("[aria-current=page]").text()).toBe("Ahri")
  })

  it("bureau : le déclencheur de recherche émet search", async () => {
    const wrapper = await mountBar("/")
    await wrapper.get(".search-trigger").trigger("click")
    expect(wrapper.emitted("search")).toHaveLength(1)
  })

  it("téléphone : logo, loupe et compte ; plus de fil d'Ariane", async () => {
    const wrapper = await mountBar("/decks", { mobile: true })
    expect(wrapper.find(".crumbs").exists()).toBe(false)
    await wrapper.get("[aria-label=Rechercher]").trigger("click")
    await wrapper.get(".topbar-account").trigger("click")
    expect(wrapper.emitted("search")).toHaveLength(1)
    expect(wrapper.emitted("account")).toHaveLength(1)
  })
})
```

`src/shell/AppTabbar.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AppTabbar from "./AppTabbar.vue"

describe("AppTabbar", () => {
  it("cinq onglets, Accueil compris, et l'onglet de la rubrique courante actif", async () => {
    const router = await makeRouter("/communaute")
    const wrapper = mount(AppTabbar, { global: { plugins: [router], components: { Icon } } })
    expect(wrapper.findAll(".tab").map((tab) => tab.text())).toEqual(["Accueil", "Cartes", "Decks", "Collection", "Règles"])
    expect(wrapper.get(".tab[aria-current=page]").text()).toBe("Decks")
  })

  it("aucun onglet actif sur une page hors rubrique", async () => {
    const router = await makeRouter("/profil")
    const wrapper = mount(AppTabbar, { global: { plugins: [router], components: { Icon } } })
    expect(wrapper.find(".tab[aria-current=page]").exists()).toBe(false)
  })
})
```

`src/shell/AccountSheet.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AccountSheet from "./AccountSheet.vue"

async function mountSheet() {
  const router = await makeRouter("/")
  const wrapper = mount(AccountSheet, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
  await nextTick()
  return wrapper
}

const texts = () => [...document.querySelectorAll(".rift-sheet a, .rift-sheet button")].map((n) => n.textContent.trim())

describe("AccountSheet", () => {
  afterEach(() => {
    Object.assign(session, { token: null, handle: null, isAdmin: null })
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("visiteur : Jouer et Connexion", async () => {
    const wrapper = await mountSheet()
    expect(texts()).toEqual(expect.arrayContaining(["Salon", "Historique", "Statistiques", "Connexion"]))
    expect(texts()).not.toContain("Déconnexion")
    wrapper.unmount()
  })

  it("membre : Jouer, compte, wishlist, déconnexion ; admin en plus", async () => {
    Object.assign(session, { token: "1", handle: "Kaelis", isAdmin: true })
    const wrapper = await mountSheet()
    expect(texts()).toEqual(
      expect.arrayContaining(["Salon", "Profil", "Amis", "Wishlist", "Administration", "Déconnexion"])
    )
    wrapper.unmount()
  })

  it("un lien choisi ferme la feuille", async () => {
    const wrapper = await mountSheet()
    document.querySelector(".rift-sheet a[href='/salon']").click()
    await nextTick()
    expect(wrapper.emitted("close")).toBeTruthy()
    wrapper.unmount()
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/shell/AppTopbar.spec.js src/shell/AppTabbar.spec.js src/shell/AccountSheet.spec.js`
Expected : FAIL (modules introuvables).

- [ ] **Step 3 : écrire `src/shell/AppTopbar.vue`**

```vue
<script setup>
import { computed } from "vue"
import { useRoute } from "vue-router"
import { session } from "../api.js"
import Logo from "../components/Logo.vue"
import UserAvatar from "../components/UserAvatar.vue"
import { breadcrumbOf } from "./navigation.js"
import { pageCrumb } from "./pageCrumb.js"

/* Barre haute du contenu. Bureau : fil d'Ariane + recherche. Téléphone : logo,
   loupe et compte (le rail est remplacé par les onglets du bas). */
defineProps({ mobile: { type: Boolean, default: false } })
const emit = defineEmits(["search", "account"])

const route = useRoute()
const crumbs = computed(() => breadcrumbOf(route.path, pageCrumb.value))
const isMac = typeof navigator !== "undefined" && /Mac|iPhone|iPad/.test(navigator.platform || "")
const shortcut = isMac ? "⌘ K" : "Ctrl K"
</script>

<template>
  <header class="topbar" :class="{ mobile }">
    <template v-if="mobile">
      <RouterLink to="/" class="topbar-brand" aria-label="Riftarium, accueil">
        <Logo />
        <span>Riftarium</span>
      </RouterLink>
      <button type="button" class="topbar-icon" aria-label="Rechercher" @click="emit('search')">
        <Icon name="search" :size="20" />
      </button>
      <button
        type="button"
        class="topbar-icon topbar-account"
        :aria-label="session.token ? `Compte de ${session.handle}` : 'Compte et Jouer'"
        @click="emit('account')"
      >
        <UserAvatar v-if="session.token" :src="session.avatarUrl" :handle="session.handle" :size="28" />
        <Icon v-else name="user" :size="20" />
      </button>
    </template>
    <template v-else>
      <nav class="crumbs" aria-label="Fil d'Ariane">
        <ol>
          <li v-for="(crumb, i) in crumbs" :key="`${i}-${crumb.label}`">
            <RouterLink v-if="crumb.to && i < crumbs.length - 1" :to="crumb.to">{{ crumb.label }}</RouterLink>
            <span v-else aria-current="page">{{ crumb.label }}</span>
          </li>
        </ol>
      </nav>
      <button type="button" class="search-trigger" @click="emit('search')">
        <Icon name="search" :size="16" />
        <span>Rechercher une carte, un deck, une règle…</span>
        <kbd>{{ shortcut }}</kbd>
      </button>
    </template>
  </header>
</template>

<style scoped>
.topbar {
  position: sticky;
  top: 0;
  z-index: var(--z-topbar);
  display: flex;
  align-items: center;
  gap: var(--space-4);
  height: var(--topbar-h);
  padding: 0 var(--space-5);
  background: rgba(13, 13, 15, 0.92);
  border-bottom: 1px solid var(--line);
  backdrop-filter: blur(8px);
}
.topbar.mobile {
  gap: var(--space-1);
  padding: 0 var(--space-2) 0 var(--space-4);
  border-bottom: 2px solid var(--blood);
}
.crumbs {
  flex: 1;
  min-width: 0;
}
.crumbs ol {
  display: flex;
  align-items: center;
  list-style: none;
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  white-space: nowrap;
  overflow: hidden;
}
.crumbs li + li::before {
  content: "›";
  margin: 0 var(--space-2);
  color: var(--bronze);
}
.crumbs a {
  color: var(--ink-muted);
}
.crumbs a:hover {
  color: var(--ink);
}
.crumbs [aria-current] {
  color: var(--ink);
}
.search-trigger {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: min(380px, 40vw);
  min-height: 36px;
  padding: 0 var(--space-3);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  color: var(--ink-muted);
  font-size: 14px;
  text-align: left;
}
.search-trigger:hover {
  border-color: var(--bronze);
}
.search-trigger span {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.search-trigger kbd {
  font-family: var(--font-label);
  font-size: 11px;
  padding: 1px 6px;
  border: 1px solid var(--line);
  color: var(--bronze-light);
}
.topbar-brand {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin-right: auto;
  color: var(--ink);
  font-family: var(--font-display);
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.topbar-brand :deep(.logo) {
  width: 26px;
  height: 26px;
}
.topbar-icon {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  color: var(--ink);
}
</style>
```

- [ ] **Step 4 : écrire `src/shell/AppTabbar.vue`**

```vue
<script setup>
import { computed } from "vue"
import { useRoute } from "vue-router"
import { activeSection, NAV, TABBAR_KEYS } from "./navigation.js"

/* Barre d'onglets du bas (téléphone), à la manière d'une app. */
const route = useRoute()
const tabs = NAV.filter((section) => TABBAR_KEYS.includes(section.key))
const current = computed(() => activeSection(route.path)?.key ?? null)
</script>

<template>
  <nav class="tabbar" aria-label="Navigation principale">
    <RouterLink
      v-for="tab in tabs"
      :key="tab.key"
      :to="tab.to"
      class="tab"
      :class="{ active: tab.key === current }"
      :aria-current="tab.key === current ? 'page' : undefined"
    >
      <Icon :name="tab.icon" :size="20" />
      <span>{{ tab.label }}</span>
    </RouterLink>
  </nav>
</template>

<style scoped>
.tabbar {
  position: fixed;
  inset: auto 0 0 0;
  z-index: var(--z-tabbar);
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  height: calc(var(--tabbar-h) + env(safe-area-inset-bottom));
  padding-bottom: env(safe-area-inset-bottom);
  background: var(--bg-sunken);
  border-top: 2px solid var(--blood);
}
.tab {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 2px;
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.tab.active {
  color: #fff;
  box-shadow: inset 0 2px 0 var(--blood-bright);
}
</style>
```

- [ ] **Step 5 : écrire `src/shell/AccountSheet.vue`**

```vue
<script setup>
import { session } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import { ACCOUNT_LINKS, NAV } from "./navigation.js"
import { useLogout } from "./useLogout.js"

/* Feuille de l'avatar (téléphone) : Jouer n'a pas d'onglet en bas, il vit ici,
   avec les entrées du compte. */
const emit = defineEmits(["close"])
const play = NAV.find((section) => section.key === "play")
const accountLinks = [...ACCOUNT_LINKS, { label: "Wishlist", to: "/wishlist" }]
const { loggingOut, logout } = useLogout()

async function onLogout() {
  await logout()
  emit("close")
}
</script>

<template>
  <RiftSheet :title="session.token ? session.handle : 'Compte'" @close="emit('close')">
    <p class="sheet-label">Jouer</p>
    <ul class="sheet-links">
      <li v-for="link in play.children" :key="link.to">
        <RouterLink :to="link.to" @click="emit('close')">{{ link.label }}</RouterLink>
      </li>
    </ul>
    <template v-if="session.token">
      <p class="sheet-label">Mon compte</p>
      <ul class="sheet-links">
        <li v-for="link in accountLinks" :key="link.to">
          <RouterLink :to="link.to" @click="emit('close')">{{ link.label }}</RouterLink>
        </li>
        <li v-if="session.isAdmin">
          <RouterLink to="/admin" @click="emit('close')">Administration</RouterLink>
        </li>
      </ul>
      <RiftButton variant="secondary" block :disabled="loggingOut" @click="onLogout">Déconnexion</RiftButton>
    </template>
    <RiftButton v-else to="/connexion" block @click="emit('close')">Connexion</RiftButton>
  </RiftSheet>
</template>

<style scoped>
.sheet-label {
  margin: var(--space-2) 0 var(--space-1);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.sheet-links {
  list-style: none;
  margin-bottom: var(--space-4);
}
.sheet-links a {
  display: flex;
  align-items: center;
  min-height: 44px;
  color: var(--ink);
  border-bottom: 1px solid var(--line);
}
</style>
```

- [ ] **Step 6 : vérifier le succès**

Run : `npx vitest run src/shell/AppTopbar.spec.js src/shell/AppTabbar.spec.js src/shell/AccountSheet.spec.js`
Expected : PASS (8 tests).

- [ ] **Step 7 : commit**

```bash
git add src/shell/AppTopbar.* src/shell/AppTabbar.* src/shell/AccountSheet.*
git commit -m "Web : barre haute, onglets mobiles et feuille du compte

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10 : pied de page

**Files :**
- Create : `src/shell/AppFooter.vue`, `src/shell/AppFooter.spec.js`

**Interfaces :**
- Consumes : `LEGAL_NAV`, `RIOT_DISCLAIMER_EN`, `RIOT_GENERAL_DISCLAIMER_EN`, `CONTACT_EMAIL`, `CONTACT_MAILTO`, `GITHUB_REPO`, `GITHUB_ISSUES`, `CLOSED_BETA`, `SHOW_DONATIONS` (`src/legal.js`).
- Produces : `<AppFooter />`.

- [ ] **Step 1 : écrire le test**

`src/shell/AppFooter.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import { LEGAL_NAV, RIOT_DISCLAIMER_EN, RIOT_GENERAL_DISCLAIMER_EN } from "../legal.js"
import { makeRouter } from "../test/makeRouter.js"
import AppFooter from "./AppFooter.vue"

describe("AppFooter", () => {
  it("reprend les mentions Riot obligatoires et les liens légaux, sans dupliquer la navigation", async () => {
    const router = await makeRouter("/")
    const wrapper = mount(AppFooter, { global: { plugins: [router] } })
    expect(wrapper.text()).toContain(RIOT_DISCLAIMER_EN)
    expect(wrapper.text()).toContain(RIOT_GENERAL_DISCLAIMER_EN)
    for (const item of LEGAL_NAV) expect(wrapper.text()).toContain(item.label)
    expect(wrapper.find("a[href='/cartes']").exists()).toBe(false)
    expect(wrapper.find("a[href='/scan']").exists()).toBe(false)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/shell/AppFooter.spec.js`
Expected : FAIL (module introuvable).

- [ ] **Step 3 : écrire `src/shell/AppFooter.vue`**

```vue
<script setup>
import {
  CLOSED_BETA,
  CONTACT_EMAIL,
  CONTACT_MAILTO,
  GITHUB_ISSUES,
  GITHUB_REPO,
  LEGAL_NAV,
  RIOT_DISCLAIMER_EN,
  RIOT_GENERAL_DISCLAIMER_EN,
  SHOW_DONATIONS
} from "../legal.js"

/* Bande sobre en bas du contenu : la navigation vit dans le rail, pas ici.
   Les avertissements Riot restent en anglais, la seule version que la politique
   « Legal Jibber Jabber » impose de reproduire. */
</script>

<template>
  <footer class="footer">
    <div class="footer-row">
      <nav class="footer-links" aria-label="Liens du site">
        <RouterLink v-for="item in LEGAL_NAV" :key="item.key" :to="item.path">{{ item.label }}</RouterLink>
        <a :href="GITHUB_REPO" target="_blank" rel="noopener">Code source</a>
        <a :href="GITHUB_ISSUES" target="_blank" rel="noopener">Signaler un bug</a>
        <!-- Toujours la dernière release : l'asset garde le nom fixe riftarium.apk. -->
        <a
          href="https://github.com/Arcneell/riftarium/releases/latest/download/riftarium.apk"
          title="Version de test signée hors Play Store : autoriser l'installation de sources inconnues."
          >Application Android</a
        >
        <a v-if="SHOW_DONATIONS" href="https://ko-fi.com/arcneell" target="_blank" rel="noopener">Soutenir</a>
      </nav>
      <p class="footer-contact">
        <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a>
        <span v-if="CLOSED_BETA"> · bêta fermée, accès sur invitation</span>
      </p>
    </div>
    <div class="footer-legal">
      <p>{{ RIOT_GENERAL_DISCLAIMER_EN }}</p>
      <p>{{ RIOT_DISCLAIMER_EN }}</p>
      <p>
        Visuels et textes officiels © Riot Games, Inc., servis depuis le CDN de Riot. Détail sur les
        <RouterLink to="/mentions-legales">mentions légales</RouterLink>.
      </p>
    </div>
  </footer>
</template>

<style scoped>
.footer {
  margin-top: var(--space-7);
  padding: var(--space-5);
  border-top: 1px solid var(--line);
  font-size: 13px;
  color: var(--ink-muted);
}
.footer-row {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: var(--space-3) var(--space-5);
}
.footer-links {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2) var(--space-4);
  font-family: var(--font-label);
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.footer-links a {
  color: var(--ink-muted);
}
.footer-links a:hover {
  color: var(--ink);
}
.footer-legal {
  display: grid;
  gap: var(--space-2);
  margin-top: var(--space-4);
  font-size: 12px;
  line-height: 1.5;
}
</style>
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/shell/AppFooter.spec.js`
Expected : PASS.

- [ ] **Step 5 : commit**

```bash
git add src/shell/AppFooter.vue src/shell/AppFooter.spec.js
git commit -m "Web : pied de page sobre (mentions Riot, liens légaux, contact)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11 : recherche universelle — logique

**Files :**
- Create : `src/search/search.js`, `src/search/search.spec.js`

**Interfaces :**
- Consumes : `api(path, { signal })`, `cardThumb(url, width)` (`src/api.js`) ; `loadRulesDocuments()` (`src/rules/rulesStore.js`) ; `TOPICS` (`src/rules/topics.js`) ; `NAV` (tâche 7).
- Produces :
  - `MIN_QUERY = 2`, `GROUP_LIMIT = 5` ;
  - `normalize(text) → string` (sans accents, minuscules, espaces bordants retirés) ;
  - `searchPages(query) → item[]` ;
  - `buildRulesIndex(documents, topics = TOPICS) → entry[]` ;
  - `searchRules(index, query) → item[]` ;
  - `runSearch(query, { signal }) → Promise<group[]>` ;
  - `resetSearchCache()`.

  Un `item` vaut `{ id, label, hint, to, image? }`. Un `group` vaut `{ key: "cards" | "decks" | "rules" | "pages", label, items, error: boolean }`. `runSearch` ne garde que les groupes non vides ou en erreur, dans l'ordre cartes, decks, règles, pages.

- [ ] **Step 1 : écrire le test**

`src/search/search.spec.js` :

```js
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", () => ({
  api: vi.fn(),
  cardThumb: (url, width) => `${url}?w=${width}`
}))
vi.mock("../rules/rulesStore.js", () => ({ loadRulesDocuments: vi.fn() }))

const { api } = await import("../api.js")
const { loadRulesDocuments } = await import("../rules/rulesStore.js")
const { buildRulesIndex, normalize, resetSearchCache, runSearch, searchPages, searchRules } = await import(
  "./search.js"
)

const DOCUMENTS = {
  core: {
    title: "Règles du jeu",
    chapters: [
      {
        sections: [
          {
            id: "350",
            title: "Réactions",
            entries: [{ id: "351", number: "351.", text: "Une Réaction se joue pendant une chaîne." }]
          }
        ]
      }
    ]
  }
}
const TOPICS = [{ slug: "chaine", title: "La chaîne", summary: "Répondre à un sort adverse." }]

describe("normalize", () => {
  it("ignore accents, casse et espaces bordants", () => {
    expect(normalize("  Réaction ÉPÉE ")).toBe("reaction epee")
  })
})

describe("searchPages", () => {
  it("trouve une rubrique ou une sous-page par son libellé, accents ignorés", () => {
    expect(searchPages("regles").map((item) => item.to)).toContain("/regles")
    expect(searchPages("wish").map((item) => item.to)).toEqual(["/wishlist"])
  })
})

describe("règles", () => {
  const index = buildRulesIndex(DOCUMENTS, TOPICS)

  it("indexe les sujets d'aide puis les règles officielles, avec un lien vers la règle", () => {
    const hits = searchRules(index, "reaction chaine")
    expect(hits[0]).toMatchObject({ label: "351. Réactions", to: "/regles/officielles?doc=core&section=350&rule=351" })
  })

  it("trouve un sujet d'aide par son titre ou son résumé", () => {
    expect(searchRules(index, "repondre sort")[0]).toMatchObject({ to: "/regles/avancee/chaine" })
  })

  it("exige tous les mots de la requête", () => {
    expect(searchRules(index, "reaction dragon")).toEqual([])
  })
})

describe("runSearch", () => {
  beforeEach(() => {
    resetSearchCache()
    loadRulesDocuments.mockResolvedValue(DOCUMENTS)
  })
  afterEach(() => {
    vi.clearAllMocks()
  })

  it("ne lance rien sous deux caractères", async () => {
    expect(await runSearch(" a ")).toEqual([])
    expect(api).not.toHaveBeenCalled()
  })

  it("interroge cartes et decks en parallèle et regroupe les résultats", async () => {
    api.mockImplementation(async (path) =>
      path.startsWith("/api/cards")
        ? { items: [{ id: "ogn-1", name: "Ahri", riftbound_id: "ogn-001", image_url: "https://cdn/x.png" }] }
        : { items: [{ id: 7, name: "Ahri Contrôle", owner: "Kaelis" }] }
    )
    const groups = await runSearch("ahri")
    expect(api).toHaveBeenCalledWith("/api/cards?q=ahri&size=5", expect.any(Object))
    expect(api).toHaveBeenCalledWith("/api/community/decks?q=ahri&size=5", expect.any(Object))
    expect(groups.map((g) => g.key)).toEqual(["cards", "decks"])
    expect(groups[0].items[0]).toMatchObject({ label: "Ahri", hint: "OGN-001", to: "/cartes/ogn-1" })
    expect(groups[1].items[0]).toMatchObject({ label: "Ahri Contrôle", hint: "par Kaelis", to: "/decks/7" })
  })

  it("un groupe en échec est signalé sans masquer les autres", async () => {
    api.mockImplementation(async (path) => {
      if (path.startsWith("/api/community")) throw new Error("405")
      return { items: [] }
    })
    const groups = await runSearch("reaction")
    expect(groups.find((g) => g.key === "decks")).toMatchObject({ error: true, items: [] })
    expect(groups.find((g) => g.key === "rules").items.length).toBeGreaterThan(0)
  })

  it("encode la requête dans l'URL", async () => {
    api.mockResolvedValue({ items: [] })
    await runSearch("kai'sa & co")
    expect(api).toHaveBeenCalledWith("/api/cards?q=kai'sa%20%26%20co&size=5", expect.any(Object))
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/search/search.spec.js`
Expected : FAIL (`./search.js` introuvable).

- [ ] **Step 3 : écrire `src/search/search.js`**

```js
import { api, cardThumb } from "../api.js"
import { loadRulesDocuments } from "../rules/rulesStore.js"
import { TOPICS } from "../rules/topics.js"
import { NAV } from "../shell/navigation.js"

/* Recherche universelle (Ctrl K) : cartes et decks via l'API existante, règles et
   aide via l'index local, pages via la table de navigation. Aucun endpoint dédié :
   un /api/search agrégé ne viendra que si la latence mesurée le justifie. */
export const MIN_QUERY = 2
export const GROUP_LIMIT = 5

export function normalize(text) {
  return String(text ?? "")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim()
}

const wordsOf = (query) => normalize(query).split(/\s+/).filter(Boolean)

/* Destinations hors rubriques, avec des mots-clés pour les trouver autrement que par leur nom. */
const EXTRA_PAGES = [
  { label: "Profil", to: "/profil", keywords: "compte" },
  { label: "Amis", to: "/amis", keywords: "suivis" },
  { label: "Nouveau deck", to: "/decks", keywords: "creer construire deck builder" },
  { label: "Connexion", to: "/connexion", keywords: "inscription compte se connecter" }
]

function pageEntries() {
  const entries = []
  for (const section of NAV) {
    entries.push({ label: section.label, to: section.to })
    for (const child of section.children ?? []) {
      if (child.label !== section.label) entries.push({ label: child.label, to: child.to })
    }
  }
  return [...entries, ...EXTRA_PAGES]
}

export function searchPages(query) {
  const words = wordsOf(query)
  return pageEntries()
    .filter((page) => {
      const haystack = normalize(`${page.label} ${page.keywords ?? ""}`)
      return words.every((word) => haystack.includes(word))
    })
    .slice(0, GROUP_LIMIT)
    .map((page) => ({ id: `page:${page.to}:${page.label}`, label: page.label, hint: "Page", to: page.to }))
}

/* Sujets d'aide d'abord (une page complète par mécanique), puis chaque règle officielle. */
export function buildRulesIndex(documents, topics = TOPICS) {
  const index = topics.map((topic) => ({
    id: `topic:${topic.slug}`,
    label: topic.title,
    hint: "Aide avancée",
    to: `/regles/avancee/${topic.slug}`,
    norm: normalize(`${topic.title} ${topic.summary ?? ""}`)
  }))
  for (const [key, doc] of Object.entries(documents ?? {})) {
    for (const chapter of doc.chapters ?? []) {
      for (const section of chapter.sections ?? []) {
        for (const entry of section.entries ?? []) {
          index.push({
            id: `rule:${key}:${entry.id}`,
            label: `${entry.number} ${section.title}`,
            hint: doc.title,
            to: `/regles/officielles?doc=${key}&section=${section.id}&rule=${entry.id}`,
            norm: normalize(`${section.title} ${entry.text}`)
          })
        }
      }
    }
  }
  return index
}

export function searchRules(index, query) {
  const words = wordsOf(query)
  return index
    .filter((entry) => words.every((word) => entry.norm.includes(word)))
    .slice(0, GROUP_LIMIT)
    .map(({ norm: _norm, ...item }) => item)
}

let rulesIndex = null
async function rulesIndexOnce() {
  if (!rulesIndex) rulesIndex = buildRulesIndex(await loadRulesDocuments())
  return rulesIndex
}

/** Vide l'index des règles — réservé aux tests. */
export function resetSearchCache() {
  rulesIndex = null
}

const settled = (result, map) =>
  result.status === "fulfilled" ? { items: map(result.value), error: false } : { items: [], error: true }

export async function runSearch(query, { signal } = {}) {
  const text = String(query ?? "").trim()
  if (normalize(text).length < MIN_QUERY) return []
  const encoded = encodeURIComponent(text)

  /* allSettled : un groupe en échec (pare-feu, 500) n'empêche pas les autres de s'afficher. */
  const [cards, decks, rules] = await Promise.allSettled([
    api(`/api/cards?q=${encoded}&size=${GROUP_LIMIT}`, { signal }),
    api(`/api/community/decks?q=${encoded}&size=${GROUP_LIMIT}`, { signal }),
    rulesIndexOnce().then((index) => searchRules(index, text))
  ])

  const groups = [
    {
      key: "cards",
      label: "Cartes",
      ...settled(cards, (page) =>
        (page.items ?? []).map((card) => ({
          id: `card:${card.id}`,
          label: card.name,
          hint: String(card.riftbound_id ?? "").toUpperCase(),
          to: `/cartes/${card.id}`,
          image: card.image_url ? cardThumb(card.image_url, 80) : null
        }))
      )
    },
    {
      key: "decks",
      label: "Decks de la communauté",
      ...settled(decks, (page) =>
        (page.items ?? []).map((deck) => ({
          id: `deck:${deck.id}`,
          label: deck.name,
          hint: `par ${deck.owner}`,
          to: `/decks/${deck.id}`
        }))
      )
    },
    { key: "rules", label: "Règles et aide", ...settled(rules, (items) => items) },
    { key: "pages", label: "Pages", items: searchPages(text), error: false }
  ]
  return groups.filter((group) => group.items.length || group.error)
}
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/search/search.spec.js`
Expected : PASS.

- [ ] **Step 5 : commit**

```bash
git add src/search
git commit -m "Web : logique de la recherche universelle (cartes, decks, règles, pages)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12 : `SearchPalette`

**Files :**
- Create : `src/shell/SearchPalette.vue`, `src/shell/SearchPalette.spec.js`

**Interfaces :**
- Consumes : `runSearch`, `normalize`, `MIN_QUERY` (tâche 11) ; `useDialog` (tâche 4) ; `RiftField` (tâche 3).
- Produces : `<SearchPalette @close />`. Montée seulement quand elle est ouverte (`v-if` côté App). Anti-rebond de 200 ms ; seule la réponse à la dernière requête est affichée ; ↑ ↓ / Entrée / Échap.

- [ ] **Step 1 : écrire le test**

`src/shell/SearchPalette.spec.js` :

```js
import { flushPromises, mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

vi.mock("../search/search.js", async (importOriginal) => ({
  ...(await importOriginal()),
  runSearch: vi.fn()
}))

const { runSearch } = await import("../search/search.js")
const { default: Icon } = await import("../components/Icon.vue")
const { makeRouter } = await import("../test/makeRouter.js")
const { default: SearchPalette } = await import("./SearchPalette.vue")

const GROUPS = [
  { key: "cards", label: "Cartes", error: false, items: [{ id: "c1", label: "Ahri", hint: "OGN-001", to: "/cartes/c1" }] },
  { key: "decks", label: "Decks de la communauté", error: true, items: [] },
  { key: "pages", label: "Pages", error: false, items: [{ id: "p1", label: "Collection", hint: "Page", to: "/collection" }] }
]

async function mountPalette() {
  const router = await makeRouter("/")
  const wrapper = mount(SearchPalette, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
  await nextTick()
  return { wrapper, router, input: () => document.querySelector(".palette input") }
}

async function type(input, value) {
  input.value = value
  input.dispatchEvent(new Event("input"))
  await nextTick()
}

const key = (input, name) => input.dispatchEvent(new KeyboardEvent("keydown", { key: name, bubbles: true }))

describe("SearchPalette", () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.clearAllMocks()
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("prend le focus dans le champ et n'interroge qu'après 200 ms de pause", async () => {
    runSearch.mockResolvedValue(GROUPS)
    const { wrapper, input } = await mountPalette()
    expect(document.activeElement).toBe(input())
    await type(input(), "ah")
    await type(input(), "ahr")
    vi.advanceTimersByTime(199)
    expect(runSearch).not.toHaveBeenCalled()
    vi.advanceTimersByTime(1)
    await flushPromises()
    expect(runSearch).toHaveBeenCalledTimes(1)
    expect(runSearch).toHaveBeenCalledWith("ahr", expect.objectContaining({ signal: expect.any(AbortSignal) }))
    wrapper.unmount()
  })

  it("affiche les groupes, signale le groupe indisponible", async () => {
    runSearch.mockResolvedValue(GROUPS)
    const { wrapper, input } = await mountPalette()
    await type(input(), "ahri")
    vi.advanceTimersByTime(200)
    await flushPromises()
    const text = document.querySelector(".palette").textContent
    expect(text).toContain("Ahri")
    expect(text).toContain("Collection")
    expect(text).toContain("Recherche indisponible")
    wrapper.unmount()
  })

  it("ignore une réponse périmée arrivée après la plus récente", async () => {
    let resolveOld
    runSearch
      .mockImplementationOnce(() => new Promise((resolve) => (resolveOld = resolve)))
      .mockResolvedValueOnce([GROUPS[2]])
    const { wrapper, input } = await mountPalette()
    await type(input(), "ah")
    vi.advanceTimersByTime(200)
    await type(input(), "coll")
    vi.advanceTimersByTime(200)
    await flushPromises()
    resolveOld([GROUPS[0]])
    await flushPromises()
    const text = document.querySelector(".palette").textContent
    expect(text).toContain("Collection")
    expect(text).not.toContain("Ahri")
    wrapper.unmount()
  })

  it("↓ puis Entrée ouvre le résultat choisi et ferme la palette", async () => {
    runSearch.mockResolvedValue(GROUPS)
    const { wrapper, router, input } = await mountPalette()
    await type(input(), "ahri")
    vi.advanceTimersByTime(200)
    await flushPromises()
    key(input(), "ArrowDown")
    await nextTick()
    expect(input().getAttribute("aria-activedescendant")).toBe("palette-opt-1")
    key(input(), "Enter")
    await flushPromises()
    expect(router.currentRoute.value.path).toBe("/collection")
    expect(wrapper.emitted("close")).toBeTruthy()
    wrapper.unmount()
  })

  it("affiche un état vide explicite", async () => {
    runSearch.mockResolvedValue([])
    const { wrapper, input } = await mountPalette()
    await type(input(), "zzzz")
    vi.advanceTimersByTime(200)
    await flushPromises()
    expect(document.querySelector(".palette").textContent).toContain("Aucun résultat")
    wrapper.unmount()
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/shell/SearchPalette.spec.js`
Expected : FAIL (module introuvable).

- [ ] **Step 3 : écrire `src/shell/SearchPalette.vue`**

```vue
<script setup>
import { computed, onBeforeUnmount, ref, watch } from "vue"
import { useRouter } from "vue-router"
import { MIN_QUERY, normalize, runSearch } from "../search/search.js"
import RiftField from "../ui/RiftField.vue"
import { useDialog } from "../ui/useDialog.js"

/* Palette de recherche universelle (Ctrl K, « / »). Un combobox : le focus reste
   dans le champ, ↑ ↓ déplacent la sélection, Entrée ouvre, Échap ferme. */
const emit = defineEmits(["close"])
const router = useRouter()

const panel = ref(null)
const query = ref("")
const groups = ref([])
const loading = ref(false)
const searched = ref(false)
const activeIndex = ref(0)
useDialog(panel, () => emit("close"))

const flat = computed(() => groups.value.flatMap((group) => group.items))
const indexOf = (item) => flat.value.indexOf(item)

let timer = null
let controller = null

watch(query, (value) => {
  clearTimeout(timer)
  controller?.abort()
  controller = null
  if (normalize(value).length < MIN_QUERY) {
    groups.value = []
    loading.value = false
    searched.value = false
    return
  }
  loading.value = true
  timer = setTimeout(async () => {
    const current = new AbortController()
    controller = current
    const result = await runSearch(value, { signal: current.signal })
    /* Une frappe plus récente a remplacé cette requête : sa réponse est périmée. */
    if (controller !== current) return
    groups.value = result
    activeIndex.value = 0
    loading.value = false
    searched.value = true
  }, 200)
})

onBeforeUnmount(() => {
  clearTimeout(timer)
  controller?.abort()
})

function move(delta) {
  const count = flat.value.length
  if (!count) return
  activeIndex.value = (activeIndex.value + delta + count) % count
}

function open(item) {
  emit("close")
  router.push(item.to)
}

function onKeydown(event) {
  if (event.key === "ArrowDown") {
    event.preventDefault()
    move(1)
  } else if (event.key === "ArrowUp") {
    event.preventDefault()
    move(-1)
  } else if (event.key === "Enter") {
    const item = flat.value[activeIndex.value]
    if (item) {
      event.preventDefault()
      open(item)
    }
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="palette-overlay" @click.self="emit('close')">
      <div ref="panel" class="palette" role="dialog" aria-modal="true" aria-label="Recherche" tabindex="-1">
        <RiftField
          v-model="query"
          search
          hide-label
          label="Rechercher une carte, un deck, une règle"
          placeholder="Une carte, un deck, une règle…"
          role="combobox"
          aria-autocomplete="list"
          aria-controls="palette-results"
          :aria-expanded="flat.length > 0 ? 'true' : 'false'"
          :aria-activedescendant="flat.length ? `palette-opt-${activeIndex}` : undefined"
          autocomplete="off"
          @keydown="onKeydown"
        />
        <div class="palette-results">
          <p v-if="loading" class="palette-state" role="status">Recherche…</p>
          <p v-else-if="searched && !groups.length" class="palette-state" role="status">
            Aucun résultat pour « {{ query.trim() }} ».
          </p>
          <ul id="palette-results" role="listbox" aria-label="Résultats">
            <template v-for="group in groups" :key="group.key">
              <li class="palette-group" role="presentation">{{ group.label }}</li>
              <li v-if="group.error" class="palette-error" role="presentation">Recherche indisponible pour le moment.</li>
              <li
                v-for="item in group.items"
                :id="`palette-opt-${indexOf(item)}`"
                :key="item.id"
                role="option"
                class="palette-option"
                :class="{ active: indexOf(item) === activeIndex }"
                :aria-selected="indexOf(item) === activeIndex"
                @mouseenter="activeIndex = indexOf(item)"
                @click="open(item)"
              >
                <img v-if="item.image" :src="item.image" alt="" class="palette-thumb" loading="lazy" />
                <span class="palette-label">{{ item.label }}</span>
                <span class="palette-hint">{{ item.hint }}</span>
              </li>
            </template>
          </ul>
        </div>
        <p class="palette-help" aria-hidden="true">↑ ↓ pour choisir · Entrée pour ouvrir · Échap pour fermer</p>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.palette-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--z-overlay);
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding: 12vh var(--space-4) var(--space-4);
  background: rgba(5, 4, 4, 0.78);
}
.palette {
  width: min(640px, 100%);
  max-height: 72vh;
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  padding: var(--space-4);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow:
    inset 0 0 0 1px var(--line),
    var(--shadow-deep);
}
.palette:focus {
  outline: none;
}
.palette-results {
  overflow-y: auto;
}
.palette-results ul {
  list-style: none;
}
.palette-state,
.palette-error {
  padding: var(--space-2) var(--space-1);
  color: var(--ink-muted);
  font-size: 14px;
}
.palette-group {
  padding: var(--space-3) var(--space-1) var(--space-1);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.palette-option {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-height: 44px;
  padding: var(--space-1) var(--space-2);
  cursor: pointer;
}
.palette-option.active {
  background: rgba(179, 38, 43, 0.25);
  box-shadow: inset 3px 0 0 var(--blood-bright);
}
.palette-thumb {
  width: 28px;
  border-radius: 2px;
}
.palette-label {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.palette-hint {
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.08em;
  color: var(--ink-muted);
}
.palette-help {
  font-size: 12px;
  color: var(--ink-muted);
}
@media (max-width: 767px) {
  .palette-overlay {
    padding: 0;
  }
  .palette {
    max-height: none;
    height: 100dvh;
  }
  .palette-help {
    display: none;
  }
}
</style>
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/shell/SearchPalette.spec.js`
Expected : PASS (5 tests).

- [ ] **Step 5 : commit**

```bash
git add src/shell/SearchPalette.vue src/shell/SearchPalette.spec.js
git commit -m "Web : palette de recherche universelle (Ctrl K)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13 : assembler la coquille dans `App.vue`

**Files :**
- Modify : `src/App.vue` (réécrit)
- Create : `src/App.spec.js`
- Modify : `src/assets/main.css` (suppression des styles de l'ancien en-tête, du tiroir, du prisme, de l'ancien pied de page et des transitions de page ; bandeau `.verify-notice` rhabillé)

**Interfaces :**
- Consumes : tout `src/shell/*`, `useBreakpoint`, `RiftTabs`, `clearPageCrumb`, `activeSection`.
- Produces : la coquille de l'application. `localStorage["riftarium_rail_collapsed"]` vaut `"1"` (replié) ou `"0"` (déplié), et l'absence de clé signifie « valeur par défaut du palier ».

- [ ] **Step 1 : écrire le test**

`src/App.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it, vi } from "vitest"
import App from "./App.vue"
import Icon from "./components/Icon.vue"
import { makeRouter } from "./test/makeRouter.js"

vi.mock("./search/search.js", async (importOriginal) => ({ ...(await importOriginal()), runSearch: vi.fn(async () => []) }))

function stubWidth(px) {
  window.matchMedia = (query) => ({
    matches: px <= Number(query.match(/max-width:\s*(\d+)px/)?.[1] ?? 0),
    addEventListener() {},
    removeEventListener() {}
  })
}

const original = window.matchMedia
async function mountApp(path = "/", px = 1440) {
  stubWidth(px)
  const router = await makeRouter(path)
  return mount(App, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
}

const keydown = (init, target = document.body) =>
  target.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, cancelable: true, ...init }))

describe("App (coquille)", () => {
  afterEach(() => {
    window.matchMedia = original
    localStorage.clear()
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("bureau : rail, pas d'onglets du bas", async () => {
    const wrapper = await mountApp("/cartes", 1440)
    expect(wrapper.find(".rail").exists()).toBe(true)
    expect(wrapper.find(".tabbar").exists()).toBe(false)
    wrapper.unmount()
  })

  it("téléphone : onglets du bas et sous-onglets de la rubrique, pas de rail", async () => {
    const wrapper = await mountApp("/regles/officielles", 390)
    expect(wrapper.find(".rail").exists()).toBe(false)
    expect(wrapper.find(".tabbar").exists()).toBe(true)
    expect(wrapper.find(".rift-tabs").text()).toContain("Texte officiel")
    wrapper.unmount()
  })

  it("tablette : rail replié par défaut ; le choix est mémorisé", async () => {
    const wrapper = await mountApp("/", 900)
    expect(wrapper.get(".rail").classes()).toContain("collapsed")
    await wrapper.get(".rail-collapse").trigger("click")
    expect(wrapper.get(".rail").classes()).not.toContain("collapsed")
    expect(localStorage.getItem("riftarium_rail_collapsed")).toBe("0")
    wrapper.unmount()
  })

  it("stockage bloqué : la coquille s'affiche quand même et le rail se replie", async () => {
    /* Navigation privée : tout accès à localStorage lève. On remplace l'objet entier
       (espionner Storage.prototype ne marche pas sous Node 26, où setup.js fournit un
       objet de remplacement qui n'est pas une instance de Storage). */
    const saved = Object.getOwnPropertyDescriptor(globalThis, "localStorage")
    const blocked = () => {
      throw new Error("bloqué")
    }
    Object.defineProperty(globalThis, "localStorage", {
      configurable: true,
      value: { getItem: blocked, setItem: blocked, removeItem: blocked, clear() {} }
    })
    try {
      const wrapper = await mountApp("/", 1440)
      expect(wrapper.get(".rail").classes()).not.toContain("collapsed")
      await wrapper.get(".rail-collapse").trigger("click")
      expect(wrapper.get(".rail").classes()).toContain("collapsed")
      wrapper.unmount()
    } finally {
      if (saved) Object.defineProperty(globalThis, "localStorage", saved)
      else delete globalThis.localStorage
    }
  })

  it("Ctrl+K ouvre la palette, Échap la ferme", async () => {
    const wrapper = await mountApp("/")
    keydown({ key: "k", ctrlKey: true })
    await nextTick()
    expect(document.querySelector(".palette")).not.toBeNull()
    keydown({ key: "Escape" })
    await nextTick()
    expect(document.querySelector(".palette")).toBeNull()
    wrapper.unmount()
  })

  it("« / » ouvre la palette, sauf pendant une saisie", async () => {
    const wrapper = await mountApp("/")
    const field = document.createElement("input")
    document.body.appendChild(field)
    keydown({ key: "/" }, field)
    await nextTick()
    expect(document.querySelector(".palette")).toBeNull()
    keydown({ key: "/" })
    await nextTick()
    expect(document.querySelector(".palette")).not.toBeNull()
    wrapper.unmount()
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/App.spec.js`
Expected : FAIL (l'ancien `App.vue` n'a ni `.rail` ni palette).

- [ ] **Step 3 : réécrire `src/App.vue`**

```vue
<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session, setSession } from "./api.js"
import EmailVerifyNotice from "./components/EmailVerifyNotice.vue"
import TraceursNotice from "./components/TraceursNotice.vue"
import { useBreakpoint } from "./composables/useBreakpoint.js"
import { useOnline } from "./composables/useOnline.js"
import AccountSheet from "./shell/AccountSheet.vue"
import AppFooter from "./shell/AppFooter.vue"
import AppRail from "./shell/AppRail.vue"
import AppTabbar from "./shell/AppTabbar.vue"
import AppTopbar from "./shell/AppTopbar.vue"
import { activeSection } from "./shell/navigation.js"
import { clearPageCrumb } from "./shell/pageCrumb.js"
import SearchPalette from "./shell/SearchPalette.vue"
import RiftTabs from "./ui/RiftTabs.vue"

const router = useRouter()
const route = useRoute()
const breakpoint = useBreakpoint()
const mobile = computed(() => breakpoint.value === "mobile")
const section = computed(() => activeSection(route.path))

/* Rail replié : choix mémorisé s'il existe, sinon replié sur tablette seulement.
   Stockage indisponible (navigation privée) : le choix vit le temps de la session. */
const RAIL_KEY = "riftarium_rail_collapsed"
function readRailPref() {
  try {
    const value = localStorage.getItem(RAIL_KEY)
    return value === null ? null : value === "1"
  } catch {
    return null
  }
}
const railPref = ref(readRailPref())
const railCollapsed = computed(() => railPref.value ?? breakpoint.value === "tablet")
function toggleRail() {
  railPref.value = !railCollapsed.value
  try {
    localStorage.setItem(RAIL_KEY, railPref.value ? "1" : "0")
  } catch {
    /* stockage bloqué : le choix n'est pas persisté */
  }
}

const searchOpen = ref(false)
const accountOpen = ref(false)

watch(
  () => route.fullPath,
  () => {
    searchOpen.value = false
    accountOpen.value = false
  }
)
watch(
  () => route.path,
  () => clearPageCrumb()
)

function isEditable(element) {
  return Boolean(element && (element.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(element.tagName)))
}

/* Ctrl/⌘ K partout ; « / » seulement hors d'un champ (sinon on ne pourrait plus le taper). */
function onKeydown(event) {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    event.preventDefault()
    searchOpen.value = !searchOpen.value
    return
  }
  if (event.key === "/" && !searchOpen.value && !isEditable(event.target)) {
    event.preventDefault()
    searchOpen.value = true
  }
}

/* Page dont le code n'est pas en cache et qu'on ouvre sans réseau (router.onError) :
   le bandeau s'efface au retour du réseau ou à la navigation suivante. */
const online = useOnline()
const offlinePage = ref(false)
function onOfflinePage() {
  offlinePage.value = true
}
watch([online, () => route.path], () => {
  offlinePage.value = false
})

/* Session expirée (401 renvoyé par l'API) : direction la connexion, en gardant la page en cours. */
function onSessionExpired() {
  if (route.path === "/connexion") return
  router.push({ path: "/connexion", query: { suite: route.fullPath } })
}

onMounted(async () => {
  window.addEventListener("riftarium:session-expired", onSessionExpired)
  window.addEventListener("riftarium:offline-page", onOfflinePage)
  window.addEventListener("keydown", onKeydown)
  if (!session.token) return
  try {
    const me = await api("/api/auth/me")
    /* Déconnexion (ou 401) survenue pendant l'appel : ne pas ressusciter la session. */
    if (!session.token) return
    setSession("1", me.handle, me.avatar_url)
    session.emailVerified = me.email_verified ?? null
    session.isAdmin = me.is_admin ?? false
  } catch {
    /* 401 déjà géré par api() */
  }
})

onBeforeUnmount(() => {
  window.removeEventListener("riftarium:session-expired", onSessionExpired)
  window.removeEventListener("riftarium:offline-page", onOfflinePage)
  window.removeEventListener("keydown", onKeydown)
})
</script>

<template>
  <a class="skip-link" href="#contenu">Aller au contenu</a>
  <div class="shell" :class="{ 'shell--mobile': mobile, 'shell--collapsed': !mobile && railCollapsed }">
    <AppRail v-if="!mobile" :collapsed="railCollapsed" @toggle="toggleRail" />
    <div class="shell-main">
      <AppTopbar :mobile="mobile" @search="searchOpen = true" @account="accountOpen = true" />
      <RiftTabs v-if="mobile && section?.children" :items="section.children" :label="section.label" />
      <EmailVerifyNotice />
      <div v-if="offlinePage" class="verify-notice" role="status">
        <p>Hors ligne : cette page n'est pas disponible sans connexion. Les règles restent consultables.</p>
      </div>
      <main id="contenu" class="shell-content">
        <RouterView v-slot="{ Component, route: viewRoute }">
          <div class="page" :key="viewRoute.path">
            <component :is="Component" />
          </div>
        </RouterView>
      </main>
      <AppFooter />
    </div>
    <AppTabbar v-if="mobile" />
  </div>
  <SearchPalette v-if="searchOpen" @close="searchOpen = false" />
  <AccountSheet v-if="accountOpen" @close="accountOpen = false" />
  <TraceursNotice />
</template>

<style scoped>
.skip-link {
  position: absolute;
  left: var(--space-2);
  top: -60px;
  z-index: var(--z-overlay);
  padding: var(--space-2) var(--space-3);
  background: var(--blood);
  color: #fff;
}
.skip-link:focus {
  top: var(--space-2);
}
.shell-main {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 100dvh;
  margin-left: var(--rail-w);
}
.shell--collapsed .shell-main {
  margin-left: var(--rail-w-collapsed);
}
.shell--mobile .shell-main {
  margin-left: 0;
  padding-bottom: calc(var(--tabbar-h) + env(safe-area-inset-bottom));
}
.shell-content {
  flex: 1;
}
</style>
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/App.spec.js`
Expected : PASS (6 tests).

- [ ] **Step 5 : supprimer les styles de l'ancienne coquille dans `main.css`**

Ces classes n'existent plus que dans l'ancien `App.vue`. Vérifier d'abord qu'aucune autre vue ne les utilise :

Run : `grep -rnE 'class="[^"]*\b(top|top-in|brand|brand-name|burger|nav|nav-close|nav-scrim|nav-profile|nav-admin|account|account-btn|account-menu|account-name|beta-mark|prism|footer-[a-z]+|foot-head)\b' src --include=*.vue`
Expected : rien. Si une vue utilise l'une de ces classes, garder sa règle et la noter dans le compte rendu.

Puis supprimer de `src/assets/main.css` **toutes** les règles (au niveau racine **et** dans les blocs `@media`) dont le sélecteur commence par :
- `.prism`, `.top`, `.top-in`, `.brand`, `.nav` (règles `.nav`, `.nav a`, `.nav-profile`, `.nav-close`, `.nav-scrim`, `.nav.open`…), `.account`, `.beta-mark`, `.burger` ;
- `footer`, `.footer-`, `.footer-grid` ;
- `.page-enter`, `.page-leave` ;
- `.scrim-` et `.account-` (transitions du tiroir et du menu).

Un bloc `@media` vidé par ces suppressions est supprimé aussi.

Run : `grep -nE "^\s*(\.prism|\.top\b|\.top-in|\.brand|\.nav\b|\.nav[ .:-]|\.account|\.beta-mark|\.burger|footer|\.footer|\.page-(enter|leave)|\.scrim-)" src/assets/main.css`
Expected : rien.

- [ ] **Step 6 : rhabiller le bandeau `.verify-notice`**

Remplacer la règle `.verify-notice { … }` de `main.css` (environ ligne 2875 avant suppressions) par :

```css
.verify-notice {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
  margin: var(--space-3) var(--space-5) 0;
  padding: var(--space-3) var(--space-4);
  background: var(--bg-raised);
  border-left: 3px solid var(--blood);
  font-size: 14px;
}
```

Les règles `.verify-notice p`, `.verify-notice .error` et `.verify-notice .btn` restent inchangées.

- [ ] **Step 7 : vérifier la suite, le lint, le format et le build**

Run : `npx vitest run && npx eslint . && npx prettier --check src index.html && npm run build`
Expected : tout passe. En cas d'écart de format, lancer `npx prettier --write src` puis revérifier.

- [ ] **Step 8 : contrôle visuel dans le navigateur**

Avec la stack dev (`docker compose -f compose.yaml -f compose.dev.yaml up -d` depuis `riftarium/`, HMR sur `http://localhost:8888`), ouvrir l'accueil, `/cartes`, `/regles/officielles` et `/collection` à 1 440 px, 900 px et 390 px. Vérifier :
- la coquille (rail, rubrique active, menu du compte, onglets du bas, feuille du compte, palette Ctrl K) ;
- que les pages encore anciennes s'affichent sans débordement horizontal à côté du rail.

Noter dans le compte rendu les pages dont un héros pleine largeur (`100vw`) déborde sous le rail. On les corrige ici seulement si c'est une règle CSS d'une ligne (`100vw` → `100%`) ; sinon elles relèvent de la PR de la page.

- [ ] **Step 9 : commit**

```bash
git add -A src
git commit -m "Web : nouvelle coquille (rail, barre haute, onglets mobiles, recherche, pied de page)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14 : retrait du scanner web, PWA rhabillée, documentation

**Files :**
- Delete : `src/views/ScanView.vue`, `src/views/ScanView.spec.js`, `src/composables/useCardScanner.js`, `src/composables/useCardScanner.spec.js`, `src/scanOcr.js`, `src/scanOcr.spec.js`, `src/scanHash.js`, `src/scanHash.spec.js`, `src/scanCapture.js`, `src/scanCapture.spec.js`
- Modify : `package.json` / `package-lock.json`, `vite.config.js`, `src/router.js`, `src/router.spec.js`, `src/views/HomeView.vue`, `src/views/HomeView.spec.js`, `src/views/CardsView.vue`, `src/views/CollectionView.vue`, `src/components/Icon.vue`, `src/assets/main.css`, `public/sw.js`, `src/sw.spec.js`, `public/site.webmanifest`, `index.html`, `nginx.conf`, `security-headers.conf`
- Create : `apps/web/README.md`
- Modify : `WORKFLOW.md`, `CLAUDE.md`, `.cursor/rules/riftarium.mdc`, `riftarium/README.md`, `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md`

**Interfaces :**
- Consumes : rien de nouveau.
- Produces : un site sans `/scan`, sans `/ocr/*` ni tesseract.js ; une CSP sans `'wasm-unsafe-eval'` ; une `Permissions-Policy` avec `camera=()`.

- [ ] **Step 1 : adapter les tests au retrait (en échec)**

- `src/router.spec.js` : retirer l'entrée `"/scan": "scan",` de la table de `sectionOf`, et ajouter dans le même `describe` :

```js
  it("le scanner web n'existe plus : /scan tombe sur la page introuvable", () => {
    expect(router.resolve("/scan").matched[0].path).toBe("/:pathMatch(.*)*")
  })
```

  (Si `router.spec.js` n'importe pas encore `router`, ajouter `import { router } from "./router.js"` en tête.)

- `src/views/HomeView.spec.js` : retirer `{ path: "/scan", component: { template: "<div />" } },` des routes de test et `"/scan"` de la liste `for (const to of […])`.

- `src/sw.spec.js` : remplacer le test « cache-first : la réponse 200 est servie puis mémorisée… » (qui utilise `/ocr/7.0.0/worker.min.js`) par :

```js
  it("cache-first : la réponse 200 est servie puis mémorisée, le cache court-circuite le réseau", async () => {
    const sw = loadSw({ fetchImpl: vi.fn(async () => fakeResponse("bundle")) })
    await handleFetch(sw, fakeRequest("/assets/RulesView-abc.js"))
    expect(sw.cache.put).toHaveBeenCalled()

    const again = await handleFetch(sw, fakeRequest("/assets/RulesView-abc.js"))
    expect(again.body).toBe("bundle")
    expect(sw.fetchImpl).toHaveBeenCalledTimes(1) // le second passage ne va plus au réseau
  })

  it("ne traite plus /ocr/ : le moteur du scanner web a été retiré", () => {
    const sw = loadSw({ fetchImpl: vi.fn() })
    expect(handleFetch(sw, fakeRequest("/ocr/7.0.0/worker.min.js"))).toBeUndefined()
  })
```

Run : `npx vitest run src/router.spec.js src/sw.spec.js`
Expected : FAIL (la route `/scan` existe encore ; `/ocr/` est encore servi en cache-first).

- [ ] **Step 2 : supprimer le code et les dépendances du scanner**

```bash
git rm -q src/views/ScanView.vue src/views/ScanView.spec.js src/composables/useCardScanner.js src/composables/useCardScanner.spec.js \
  src/scanOcr.js src/scanOcr.spec.js src/scanHash.js src/scanHash.spec.js src/scanCapture.js src/scanCapture.spec.js
npm uninstall tesseract.js tesseract.js-core @tesseract.js-data/eng
```

- [ ] **Step 3 : nettoyer `vite.config.js`**

- supprimer tout le bloc qui commence au commentaire `// Moteur OCR du scanner (tesseract.js)` et se termine à la fin de la constante `copyOcrAssets` (`readOcrVersion`, `ocrVersion`, `ocrBase`, `ocrCoreVariants`, `ocrFiles`, `ocrSourcePath`, `ocrContentType`, `ocrMiddleware`, `serveOcrAssets`, `copyOcrAssets`) ;
- dans le commentaire d'`OFFLINE_ROUTES`, « la cartothèque, les decks, le scan et les statistiques » devient « la cartothèque, les decks et les statistiques » ;
- `export default defineConfig(({ command }) => ({` devient `export default defineConfig({` (et la parenthèse fermante finale `}))` devient `})`) ;
- `plugins: [vue(), serveRulesData, serveOcrAssets, copyOcrAssets, injectSwPrecache],` devient `plugins: [vue(), serveRulesData, injectSwPrecache],` ;
- supprimer les deux lignes de commentaire `// __OCR_BASE__ …` et la ligne `define: command === "build" ? … : {},`.

Run : `grep -n -i "ocr\|tesseract\|command" vite.config.js`
Expected : rien.

- [ ] **Step 4 : retirer la route et les liens**

- `src/router.js` : supprimer l'objet de route `/scan` (le commentaire « Accessible sans compte : le scan identifie la carte… » compris) et la ligne `if (path.startsWith("/scan")) return "scan"` de `sectionOf`.
- `src/views/HomeView.vue` :
  - supprimer `{ to: "/scan", label: "Scanner une carte" },` ;
  - dans le texte de la salle « collection », supprimer la phrase « Pour trier un classeur, le scanner lit le code de la carte et l'ajoute pour vous. ».
- `src/views/CardsView.vue` : supprimer le `RouterLink` `class="btn btn-ghost scan-entry" to="/scan"` (lignes 92 à 95 actuelles, icône et libellé « Scanner » compris).
- `src/views/CollectionView.vue` :
  - supprimer le `RouterLink` `scan-entry` vers `/scan` (lignes 600 à 607 environ) et le `RouterLink` « Scanner une carte » (ligne 698 environ) ;
  - remplacer « Ouvrez une fiche carte ou scannez vos cartes pour remplir les pochettes. » par « Ouvrez une fiche carte pour remplir les pochettes. » ;
  - remplacer « Notez vos exemplaires depuis une fiche carte, ou scannez vos cartes pour les ajouter d'un geste. » par « Notez vos exemplaires depuis une fiche carte. ».
- `src/components/Icon.vue` : supprimer le groupe `<!-- appareil photo (scanner de cartes) -->` (`name === 'camera'`). Si le groupe suivant commençait par `v-else-if`, vérifier que le premier groupe restant après `chevron` reste en `v-else-if`.
- `src/assets/main.css` : supprimer les règles `.scan-entry` et toutes celles qui commencent par `.scan` (vue du scanner), y compris dans les `@media`.

Run : `grep -rn -i "/scan\|scanner\|scanOcr\|camera" src --include=*.vue --include=*.js --include=*.css | grep -v "AdminView.vue"`
Expected : rien (le libellé `scan: "Scan"` d'`AdminView.vue` reste, pour l'historique de fréquentation).

- [ ] **Step 5 : PWA**

- `public/sw.js` :
  - `const VERSION = 3` devient `const VERSION = 4`, pour purger les caches `/ocr/` déjà stockés ;
  - dans le commentaire d'en-tête, supprimer la puce `- /ocr/* : cache-first — moteur OCR du scanner…` et la phrase « Aussi quand tesseract.js change de version — … du poids mort dans le quota du navigateur. » ;
  - dans le commentaire d'`ASSETS`, « la cartothèque, les decks, le scan et les statistiques » devient « la cartothèque, les decks et les statistiques » ;
  - dans le gestionnaire `fetch`, le commentaire `/* /ocr/* : … */` est supprimé et `if (url.pathname.startsWith("/assets/") || url.pathname.startsWith("/ocr/")) {` devient `if (url.pathname.startsWith("/assets/")) {`.
- `public/site.webmanifest` : `"background_color"` et `"theme_color"` passent à `"#0d0d0f"`, et l'entrée de raccourci « Scanner une carte » est supprimée.
- `index.html` : `<meta name="theme-color" content="#0a1428" />` devient `<meta name="theme-color" content="#0d0d0f" />`.

- [ ] **Step 6 : nginx (CSP et caméra)**

```bash
sed -i -e "s/ 'wasm-unsafe-eval'//g" -e 's/camera=(self)/camera=()/g' nginx.conf security-headers.conf
```

Puis supprimer, dans `nginx.conf`, le bloc `location /ocr/ { … }` et les trois lignes de commentaire qui le précèdent (« # Moteur OCR du scanner… »).

Run : `grep -n "wasm\|camera=(self)\|/ocr" nginx.conf security-headers.conf`
Expected : rien.

- [ ] **Step 7 : vérifier tests et build**

Run : `npx vitest run && npm run build && ls dist | grep -c ocr`
Expected : tests PASS, build OK, `0`.

- [ ] **Step 8 : documentation**

`apps/web/README.md` (nouveau) :

```markdown
# Riftarium — site web (Vue 3)

Site Vue 3 + Vite servi par nginx (proxy `/api`). Commandes : voir `WORKFLOW.md` §5
(`npm run check` avant de pousser).

## Charte « Forge noxienne »

Spec complète : `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md`.
Cette charte est aussi la référence du futur réalignement de l'app Flutter.

### Règles d'usage

- **Pas de style de composant dans une vue.** Une vue ne contient que sa mise en
  page (grilles, espacements) dans son `<style scoped>`. Boutons, champs, onglets,
  modales, feuilles et texte de jeu viennent de `src/ui/`.
- **Seuls trois fichiers sont globaux** : `src/styles/tokens.css` (toutes les
  couleurs, polices, espacements et dimensions), `fonts.css` et `base.css` (reset,
  liens, focus, glyphes `.rb-glyph` et pastilles `.rb-kw`). `src/assets/main.css`
  est l'ancienne feuille, en cours de démantèlement : n'y ajoutez rien.
- **Visuels de jeu officiels obligatoires** : énergie, puissance, runes et
  épuisement en glyphes Riot, mots-clés en pastilles colorées par famille, via
  `RiftText` (`tag="p"` pour une carte, `rules` pour le texte des règles). Jamais
  de « 5 énergie » en texte.
- **Couleurs** : `--blood` pour l'action principale, `--blood-text` pour un accent
  dans du texte courant, `--blood-bright` seulement pour les grands titres et les
  graphismes, `--bronze` pour les filets, `--bronze-light` pour les intertitres et
  les prix, `--ink` / `--ink-muted` pour le texte. Le contraste des tokens de texte
  est vérifié par `src/styles/tokens.spec.js`.
- **Typographie** : Cinzel (`--font-display`) pour les titres et les chiffres-clés,
  Barlow Condensed en capitales espacées (`--font-label`) pour les étiquettes, la
  navigation et les boutons, Barlow (`--font-body`) pour le texte.
- **Habillage Forgé** : angles coupés (`--cut`), boutons principaux biseautés,
  filets de bronze, liseré rouge. Pas d'arrondi marqué hors illustrations de cartes.
- **Effets ciblés seulement** : reflet foil au survol des cartes rares et showcase,
  entrée du splash, défilement lent du mur de cartes, éclat rouge à l'ajout d'une
  carte, transitions de 150 à 200 ms. Tout est coupé par `prefers-reduced-motion`.

### Composants `src/ui/`

| Composant | Usage |
| --- | --- |
| `RiftButton` | `variant` primary / secondary / ghost, `size` sm / md, `to` ou `href` |
| `RiftField` | champ avec label (masquable), `search`, `error` ; attributs transmis à l'`<input>` |
| `RiftTabs` | onglets de sous-rubriques (`items: [{ label, to }]`) |
| `RiftModal` | modale accessible (`title`, `wide`, `@close`) |
| `RiftSheet` | feuille du bas sur téléphone (`title`, `@close`) |
| `RiftText` / `RiftGlyph` | texte de jeu enrichi |
| `useDialog` | pile de dialogues, piège à focus, Échap, verrou de défilement |

### Coquille `src/shell/`

`navigation.js` est la table unique des rubriques : rail (`AppRail`), onglets
mobiles (`AppTabbar`), sous-onglets, fil d'Ariane (`AppTopbar`) et groupe « Pages »
de la recherche (`SearchPalette`, logique dans `src/search/search.js`). Une page peut
fournir le dernier maillon du fil d'Ariane avec `setPageCrumb(nom)`
(`src/shell/pageCrumb.js`).
```

`WORKFLOW.md` :
- §3, règle 5, remplacée par :

```markdown
5. **Ne pas retirer** le service worker (`public/sw.js`) ni le manifest
   (`site.webmanifest`) tant que l'application n'est pas en store (§8, phase 9).
   Le scanner web (tesseract.js, `/scan`, `/ocr/*`) a été retiré avec la refonte
   « Forge noxienne » (octobre 2026) : le scan est réservé à l'application mobile.
```

- §1, première puce : « premier chargement lent à cause du moteur OCR tesseract.js de 15 Mo » devient « premier chargement lent à cause du moteur OCR tesseract.js de 15 Mo, retiré depuis ».
- §6, puce **Scan** : « Le web identifie par empreinte dHash côté client + lecture OCR du code collector, contre l'index `GET /api/cards/hashes`. » devient « Le scanner web a été retiré (octobre 2026) ; l'index `GET /api/cards/hashes` reste servi pour le mobile. ».
- §7, ajouter cette puce après la puce **Rendu** :

```markdown
- **Charte à venir** : le site est passé à la charte « Forge noxienne » (noir, rouge
  sang, bronze ; Cinzel + Barlow ; rail latéral). `lib/app/design/` devra la reprendre
  dans un chantier dédié ; référence : `apps/web/README.md` et la spec
  `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md`.
```

- §8, phase 9 : « Décider du retrait du service worker, du manifest PWA et du scanner web (15 Mo d'OCR). » devient « Décider du retrait du service worker et du manifest PWA (le scanner web est déjà retiré). ».

`CLAUDE.md` et `.cursor/rules/riftarium.mdc` : « Le scanner web, le service worker et le manifest PWA restent en place tant que l'application mobile n'est pas publiée. Ne pas les retirer. » devient « Le service worker et le manifest PWA restent en place tant que l'application mobile n'est pas publiée. Ne pas les retirer. Le scanner web a été retiré (le scan est réservé au mobile). » (dans `CLAUDE.md`, garder la mise en forme de la puce existante sur deux lignes).

`riftarium/README.md`, ligne 216 : « La PWA et le scan web restent en place tant qu'elle n'est pas publiée. » devient « La PWA reste en place tant qu'elle n'est pas publiée ; le scan web a été retiré. ».

Spec `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` :
- §3.2, ajouter après la ligne `--blood-bright` du tableau :

```markdown
| `--blood-text` | `#e0605a` | accent dans du texte courant (≥ 5,3:1) ; `--blood-bright` est réservé aux grands titres et graphismes |
```

- §5, PR 1, première puce : « `src/styles/`, `src/ui/` (tous les composants du §3.3) » devient « `src/styles/`, et les composants de `src/ui/` utilisés par la coquille (`RiftButton`, `RiftField`, `RiftTabs`, `RiftModal`, `RiftSheet`, `RiftText`, `RiftGlyph`) ; `RiftPanel`, `RiftChip`, `RiftEmpty` et `RiftSkeleton` arrivent en PR 2, `RiftStat` et `CardTile` en PR 3, avec leur premier usage ».

- [ ] **Step 9 : vérification complète**

Run : `npm run check`
Expected : lint, format, tests et build passent.

- [ ] **Step 10 : commits (deux sujets)**

```bash
git add -A src public index.html vite.config.js package.json package-lock.json nginx.conf security-headers.conf
git commit -m "Web : retrait du scanner web (tesseract.js, /scan, /ocr), CSP sans wasm, PWA aux couleurs de la Forge

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
cd ../../..
git add WORKFLOW.md CLAUDE.md .cursor/rules/riftarium.mdc riftarium/README.md riftarium/apps/web/README.md docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md
git commit -m "Docs : charte Forge noxienne, retrait du scanner web consigné

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
cd riftarium/apps/web
```

---

### Task 15 : vérification finale et validation par le mainteneur

**Files :** aucun (vérification).

- [ ] **Step 1 : vérifications de la CI en local**

Run : `npm run check` (depuis `riftarium/apps/web`), puis, depuis `riftarium/` : `docker compose -f compose.yaml config --quiet && python scripts/check_compose_security.py`
Expected : tout passe. Le second contrôle est lancé parce que `nginx.conf` et `security-headers.conf` ont changé. Python n'est pas installé sur le Windows du mainteneur (ni `python` ni `py`, pas de venv dans `apps/api`) : lancer le script dans un conteneur, `docker run --rm -v "$PWD:/w" -w /w python:3.14-slim python scripts/check_compose_security.py` (à adapter si le script exige le binaire `docker` ; dans ce cas, le signaler au mainteneur et s'en remettre au job `compose-security` de la CI).

- [ ] **Step 2 : stack dev à jour**

Les dépendances npm ont changé (retrait de tesseract.js) : `docker restart riftarium-web`, puis vérifier que `http://localhost:8888` répond.

- [ ] **Step 3 : contrôle visuel de l'agent**

À 1 440 px, 900 px et 390 px :
- accueil, `/cartes`, une fiche carte, `/collection`, `/decks`, `/regles`, `/regles/officielles`, `/connexion` et une URL inconnue ;
- palette Ctrl K (recherche « ahri », « réaction », « wishlist ») ;
- menu du compte et feuille mobile ;
- rail replié et déplié.

Noter tout défaut.

- [ ] **Step 4 : remettre au mainteneur la liste de validation**

Transmettre la liste ci-dessous et **attendre son accord explicite avant tout push** :
- **Coquille bureau** (`localhost:8888`, fenêtre large) : rail, rubrique active et sous-pages, repli du rail (le rail reste replié au rechargement), fil d'Ariane, menu du compte (connecté, admin), bouton Connexion (visiteur).
- **Recherche** : Ctrl K et `/`, résultats cartes, decks, règles et pages, navigation au clavier, Échap ; `/` tapé dans la recherche de la cartothèque n'ouvre pas la palette.
- **Téléphone** (outils de développement, 390 px) : onglets du bas, sous-onglets (Règles, Decks, Collection), feuille de l'avatar (Jouer, compte, déconnexion), palette en plein écran.
- **Tablette** (900 px) : rail replié par défaut.
- **Pages existantes** : palette Forge appliquée (noir, rouge, bronze, Cinzel / Barlow), modales (deck builder → cartes manquantes, édition de lot en collection), texte de carte avec glyphes et pastilles, règles avec abréviations converties.
- **Scanner retiré** : plus de lien Scanner, `/scan` mène à la page introuvable.
- **Défauts connus** relevés aux étapes 13.8 et 15.3, qui relèvent des PR de pages.

- [ ] **Step 5 : après accord seulement**

```bash
git push -u origin feat/refonte-socle
gh pr create --title "Web : refonte Forge noxienne — socle et coquille (PR 1/8)" --body "$(cat <<'EOF'
Première PR de la refonte « Forge noxienne » (spec : docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md).

- Socle : tokens, polices Barlow, base ; anciennes variables redirigées (les pages non refaites prennent la palette).
- Composants src/ui/ : RiftButton, RiftField, RiftTabs, RiftModal (remplace ModalDialog), RiftSheet, RiftText (remplace CardText et RuleText).
- Coquille : rail latéral, barre haute avec fil d'Ariane, onglets mobiles, feuille du compte, recherche universelle Ctrl K, pied de page sobre.
- Scanner web retiré (tesseract.js, /scan, /ocr) ; CSP sans wasm-unsafe-eval ; caméra désactivée ; service worker v4.
- Documentation : README web (charte), WORKFLOW.md, CLAUDE.md.

Validé en local par le mainteneur.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
