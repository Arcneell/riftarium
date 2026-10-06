# Refonte Forge noxienne — PR 3 : cartothèque et fiche carte — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** refaire la cartothèque (`/cartes`) et la fiche carte (`/cartes/:id`) dans le style Forgé.
- **Liste** : filtres en panneau latéral (une feuille sur téléphone), filtres actifs en puces au-dessus de la grille, nouvelle vignette de carte.
- **Fiche** : la carte, avec dessous et sans vide les variantes, le prix et les actions collection et wishlist ; à côté, les stats avec glyphes officiels et le texte de jeu dans un panneau Forgé.

**Architecture :**
- **Nouveaux composants de base** dans `src/ui/` : `RiftChip`, `RiftEmpty`, `RiftStat`, `CardTile`.
- **Composants propres aux cartes** dans `src/cards/` :
  - `CardFilters` : le contenu du panneau de filtres ;
  - `ActiveFilters` : les puces des filtres actifs ;
  - `CardCollectionPanel` : les lots et la wishlist, extraits de la fiche.
- **Logique conservée** : la synchronisation des filtres avec l'URL (`useQuerySyncedFilters`), la mesure de grille (`useGridMeasure`) et toute la logique métier de la fiche (séquence anti-course, SEO, lots, wishlist).
- **Pages encore anciennes** (collection, decks, wishlist) : elles gardent leurs composants actuels (`components/CardTile.vue`, `FilterSelect.vue`) jusqu'à leur propre PR.

**Tech Stack :** Vue 3.5, vue-router 5, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§3.3, §3.4, §5 PR 3)

## Global Constraints

- **Branche** : `feat/refonte-cartes` depuis `origin/refonte/forge`. La PR vise `refonte/forge`, jamais `main`. Aucun push sans validation locale du mainteneur.
- **Langue** : français pour les commentaires, l'interface et les commits. Identifiants en anglais.
- **Commits** : `Web : …`, terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Commandes** : npm depuis `riftarium/apps/web`. `npm run check` est vert avant tout push.
- **Tokens** (`src/styles/tokens.css`) :
  - fonds `--bg`, `--bg-raised`, `--bg-sunken`, `--line` ;
  - sang `--blood`, `--blood-bright` (grands titres et graphismes seulement), `--blood-text` ;
  - bronze `--bronze`, `--bronze-light` ;
  - texte `--ink`, `--ink-muted` ;
  - domaines `--fury`, `--calm`, `--mind`, `--body`, `--chaos`, `--order` et leurs variantes `*-text` ;
  - polices `--font-display`, `--font-label`, `--font-body` ;
  - espacements `--space-1` à `--space-7`, forme `--cut` et `--radius-card`, durées `--t-fast` et `--t-base`.
- **Composants existants** :
  - `src/ui/` : `RiftButton`, `RiftField` (`search`, `hide-label`, attributs transmis à l'`<input>`), `RiftTabs`, `RiftModal`, `RiftSheet` (`title`, `@close`), `RiftText` (`tag`, `rules`), `RiftGlyph`, `RiftPanel` (`title`, `accent`, slot `title`), `RiftSkeleton` (`lines`, `block`) ;
  - `src/shell/pageCrumb.js` : `setPageCrumb(label)` ;
  - `useBreakpoint()` : `"mobile"`, `"tablet"` ou `"desktop"` ;
  - `Icon` est global : dans les tests, `global: { components: { Icon } }`.
- **Visuels de jeu officiels obligatoires** : énergie, puissance et runes en glyphes Riot (`glyphUrl` de `cardText.js`), texte de jeu via `RiftText`. Jamais de « 5 énergie » en texte.
- **Styles** : `<style scoped>` par composant. Rien n'est ajouté à `src/assets/main.css` ; cette PR supprime la tranche propre à la liste et à la fiche.
- **Effets** (spec §3.4) : seulement le reflet foil au survol des cartes rares et showcase (`isFoil`), et des transitions de 150 à 200 ms. Pas de `v-tilt` ni de `v-reveal` dans le nouveau code. `prefers-reduced-motion` coupe le reflet.
- **Comportements conservés** (couverts par les specs existantes, à migrer sans perte) :
  - liste : raretés dans l'ordre du jeu, runes officielles sur le filtre de domaine, taille de page qui suit la grille, état vide avec réinitialisation, filtres reflétés dans l'URL et dans la requête ;
  - fiche : mise en page portrait ou paysage, bloc prix (montant, foil, note, lien Cardmarket), rien de vide sans prix, wishlist absente pour un visiteur, bascule PUT/DELETE, ajout de lot (POST puis remise à 1), échec qui conserve la saisie, lots indisponibles sans masquer la fiche, aucune requête `/api/cards/undefined` à la sortie.

## Review Focus

- **URL partagée avec filtres** (`/cartes?set=sfd&domain=Fury`, notamment le lien du mur de l'accueil) : les puces actives et le panneau reflètent l'URL dès le chargement. Testé en tâche 4.
- **Téléphone** : les filtres sont dans une feuille ouverte par un bouton qui affiche le nombre de filtres actifs. Changer un filtre ne ferme pas la feuille ; « Voir les N cartes » la ferme. Testé en tâche 4.
- **Fiche sans stat** (sort sans puissance, rune, champ de bataille) : aucun `RiftStat` vide, aucun tiret orphelin. Testé en tâche 6.
- **Passage d'une variante à l'autre** : le fil d'Ariane suit le nom affiché, et les lots et la wishlist sont ceux de la variante courante. Testé en tâche 6.
- **Réseau lent sur la liste** : des squelettes à la place de la grille au premier chargement, puis la grille courante reste visible (atténuée) pendant les rechargements, sans clignotement. Testé en tâche 4.

---

## Carte des fichiers

| Fichier | Rôle |
| --- | --- |
| `src/ui/RiftChip.vue` (+ spec) | puce : bascule (`aria-pressed`) ou retirable (bouton ✕), glyphe et couleur optionnels |
| `src/ui/RiftEmpty.vue` (+ spec) | état vide : titre, texte, slot d'actions |
| `src/ui/RiftStat.vue` (+ spec) | stat de jeu : glyphe officiel, valeur Cinzel, étiquette |
| `src/ui/CardTile.vue` (+ spec) | vignette de carte Forgée (nouvelle ; l'ancienne reste dans `components/` pour les pages pas encore refaites) |
| `src/cards/CardFilters.vue` (+ spec) | contenu du panneau de filtres (recherche + facettes en puces) |
| `src/cards/ActiveFilters.vue` (+ spec) | puces retirables des filtres actifs + « Tout effacer » |
| `src/cards/CardCollectionPanel.vue` (+ spec) | lots possédés et wishlist d'une carte (extraits de CardView) |
| `src/views/CardsView.vue` (+ spec) | liste réécrite |
| `src/views/CardView.vue` (+ spec) | fiche réécrite |
| `src/assets/main.css` | suppression des règles propres à la liste et à la fiche |

---

### Task 1 : `RiftChip`, `RiftEmpty`, `RiftStat`

**Files :** Create `src/ui/RiftChip.vue`, `RiftEmpty.vue`, `RiftStat.vue` et leurs `.spec.js`.

**Interfaces :**
- `<RiftChip :label :selected? :removable? :glyph? :glyph-kind? :color? @toggle @remove />` :
  - rend un `<button type="button" class="rift-chip">` ;
  - **mode bascule** (par défaut) : `aria-pressed` reflète `selected`, et le clic émet `toggle` ;
  - **mode retirable** (`removable`) : l'étiquette est suivie de « ✕ », l'`aria-label` vaut « Retirer le filtre <label> », et le clic émet `remove` ;
  - `glyph` est une URL de glyphe Riot affichée avant l'étiquette (`<img class="rb-glyph" :class="glyphKind">`, `alt=""`) ;
  - `color` est une couleur CSS posée en `--chip-color` (bordure et texte quand la puce est sélectionnée).
- `<RiftEmpty :title :text? />` avec un slot par défaut pour les actions : `<div class="rift-empty" role="status">`, titre en `<p class="rift-empty-title">`.
- `<RiftStat :label :value? :glyph? :glyph-kind? :ink? />` :
  - `glyph` est l'URL du glyphe ; avec `ink`, il est rendu en masque (`span.rb-glyph.ink` avec `--glyph`), sinon en `<img class="rb-glyph" :class="glyphKind">` ;
  - `value` est optionnelle (l'énergie se lit sur le glyphe seul) ;
  - un slot par défaut remplace le glyphe pour un contenu riche (plusieurs runes) ;
  - racine `<div class="rift-stat">`, étiquette en `<span class="rift-stat-label">`.

- [ ] **Step 1 : écrire les tests**

`src/ui/RiftChip.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftChip from "./RiftChip.vue"

describe("RiftChip", () => {
  it("bascule : aria-pressed et événement toggle", async () => {
    const wrapper = mount(RiftChip, { props: { label: "Fureur", selected: true } })
    const button = wrapper.get("button.rift-chip")
    expect(button.attributes("aria-pressed")).toBe("true")
    await button.trigger("click")
    expect(wrapper.emitted("toggle")).toHaveLength(1)
  })

  it("retirable : libellé accessible, croix et événement remove", async () => {
    const wrapper = mount(RiftChip, { props: { label: "Origins", removable: true } })
    const button = wrapper.get("button")
    expect(button.attributes("aria-pressed")).toBeUndefined()
    expect(button.attributes("aria-label")).toBe("Retirer le filtre Origins")
    expect(button.text()).toContain("✕")
    await button.trigger("click")
    expect(wrapper.emitted("remove")).toHaveLength(1)
  })

  it("affiche le glyphe officiel et pose la couleur", () => {
    const wrapper = mount(RiftChip, {
      props: { label: "Fureur", glyph: "https://x/rune_fury.svg", glyphKind: "rune", color: "var(--fury)" }
    })
    expect(wrapper.get("img.rb-glyph.rune").attributes("src")).toBe("https://x/rune_fury.svg")
    expect(wrapper.attributes("style")).toContain("--chip-color: var(--fury)")
  })
})
```

`src/ui/RiftEmpty.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftEmpty from "./RiftEmpty.vue"

describe("RiftEmpty", () => {
  it("annonce l'état vide avec titre, texte et actions", () => {
    const wrapper = mount(RiftEmpty, {
      props: { title: "Aucune carte", text: "Essayez d'autres filtres." },
      slots: { default: "<button>Réinitialiser</button>" }
    })
    expect(wrapper.attributes("role")).toBe("status")
    expect(wrapper.get(".rift-empty-title").text()).toBe("Aucune carte")
    expect(wrapper.text()).toContain("Essayez d'autres filtres.")
    expect(wrapper.get("button").text()).toBe("Réinitialiser")
  })
})
```

`src/ui/RiftStat.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftStat from "./RiftStat.vue"

describe("RiftStat", () => {
  it("glyphe image, valeur et étiquette", () => {
    const wrapper = mount(RiftStat, { props: { label: "Énergie", glyph: "https://x/energy_5.svg", glyphKind: "energy" } })
    expect(wrapper.get("img.rb-glyph.energy").attributes("alt")).toBe("Énergie")
    expect(wrapper.get(".rift-stat-label").text()).toBe("Énergie")
  })

  it("glyphe teinté (puissance) et valeur", () => {
    const wrapper = mount(RiftStat, { props: { label: "Puissance", glyph: "https://x/might.svg", ink: true, value: 4 } })
    const glyph = wrapper.get("span.rb-glyph.ink")
    expect(glyph.attributes("style")).toContain("might.svg")
    expect(glyph.attributes("aria-label")).toBe("Puissance")
    expect(wrapper.get(".rift-stat-value").text()).toBe("4")
  })

  it("slot pour un contenu riche", () => {
    const wrapper = mount(RiftStat, { props: { label: "Pouvoir" }, slots: { default: "<i class='runes'>RR</i>" } })
    expect(wrapper.find(".runes").exists()).toBe(true)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/ui/RiftChip.spec.js src/ui/RiftEmpty.spec.js src/ui/RiftStat.spec.js`. Expected : FAIL.

- [ ] **Step 3 : écrire `src/ui/RiftChip.vue`**

```vue
<script setup>
import { computed } from "vue"

/* Puce de la Forge : filtre à bascule (aria-pressed) ou filtre actif retirable. */
const props = defineProps({
  label: { type: String, required: true },
  selected: { type: Boolean, default: false },
  removable: { type: Boolean, default: false },
  glyph: { type: String, default: "" },
  glyphKind: { type: String, default: "" },
  color: { type: String, default: "" }
})
const emit = defineEmits(["toggle", "remove"])

const style = computed(() => (props.color ? { "--chip-color": props.color } : undefined))
function onClick() {
  emit(props.removable ? "remove" : "toggle")
}
</script>

<template>
  <button
    type="button"
    class="rift-chip"
    :class="{ selected, removable }"
    :style="style"
    :aria-pressed="removable ? undefined : String(selected)"
    :aria-label="removable ? `Retirer le filtre ${label}` : undefined"
    @click="onClick"
  >
    <img v-if="glyph" class="rb-glyph" :class="glyphKind" :src="glyph" alt="" width="16" height="16" />
    <span>{{ label }}</span>
    <span v-if="removable" class="rift-chip-x" aria-hidden="true">✕</span>
  </button>
</template>

<style scoped>
.rift-chip {
  --chip-color: var(--bronze-light);
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  min-height: 32px;
  padding: 0 var(--space-3);
  border: 1px solid var(--line);
  background: var(--bg-sunken);
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  transition:
    border-color var(--t-fast),
    color var(--t-fast);
}
.rift-chip:hover {
  color: var(--ink);
  border-color: var(--bronze);
}
.rift-chip.selected,
.rift-chip.removable {
  color: var(--chip-color);
  border-color: var(--chip-color);
  background: color-mix(in srgb, var(--bg-sunken), var(--chip-color) 10%);
}
.rift-chip-x {
  margin-left: var(--space-1);
  font-size: 11px;
}
</style>
```

- [ ] **Step 4 : écrire `src/ui/RiftEmpty.vue`**

```vue
<script setup>
/* État vide : dire pourquoi il n'y a rien, et proposer la sortie. */
defineProps({
  title: { type: String, required: true },
  text: { type: String, default: "" }
})
</script>

<template>
  <div class="rift-empty" role="status">
    <p class="rift-empty-title">{{ title }}</p>
    <p v-if="text" class="rift-empty-text">{{ text }}</p>
    <div v-if="$slots.default" class="rift-empty-actions"><slot /></div>
  </div>
</template>

<style scoped>
.rift-empty {
  display: grid;
  justify-items: center;
  gap: var(--space-2);
  padding: var(--space-7) var(--space-4);
  text-align: center;
  border: 1px dashed var(--line);
}
.rift-empty-title {
  font-family: var(--font-display);
  font-size: 20px;
  font-weight: 700;
  color: var(--ink);
}
.rift-empty-text {
  max-width: 420px;
  color: var(--ink-muted);
}
.rift-empty-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--space-2);
  margin-top: var(--space-3);
}
</style>
```

- [ ] **Step 5 : écrire `src/ui/RiftStat.vue`**

```vue
<script setup>
/* Statistique de jeu : glyphe officiel Riot, valeur en Cinzel, étiquette en capitales. */
defineProps({
  label: { type: String, required: true },
  value: { type: [Number, String], default: null },
  glyph: { type: String, default: "" },
  glyphKind: { type: String, default: "" },
  ink: { type: Boolean, default: false }
})
</script>

<template>
  <div class="rift-stat">
    <span class="rift-stat-glyphs">
      <slot>
        <span
          v-if="glyph && ink"
          class="rb-glyph ink"
          :style="{ '--glyph': `url(${glyph})` }"
          role="img"
          :aria-label="label"
        ></span>
        <img v-else-if="glyph" class="rb-glyph" :class="glyphKind" :src="glyph" :alt="label" width="26" height="26" />
      </slot>
      <b v-if="value !== null && value !== ''" class="rift-stat-value">{{ value }}</b>
    </span>
    <span class="rift-stat-label">{{ label }}</span>
  </div>
</template>

<style scoped>
.rift-stat {
  display: grid;
  gap: var(--space-1);
  min-width: 88px;
  padding: var(--space-2) var(--space-3);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
  clip-path: polygon(8px 0, 100% 0, 100% calc(100% - 8px), calc(100% - 8px) 100%, 0 100%, 0 8px);
}
.rift-stat-glyphs {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  min-height: 28px;
  font-size: 24px;
}
.rift-stat-value {
  font-family: var(--font-display);
  font-size: 24px;
  font-weight: 900;
  color: var(--ink);
}
.rift-stat-label {
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
</style>
```

- [ ] **Step 6 : vérifier le succès**, puis **commit** `Web : composants RiftChip, RiftEmpty et RiftStat` (Run : les trois specs → PASS).

---

### Task 2 : `CardTile` (nouvelle vignette)

**Files :** Create `src/ui/CardTile.vue`, `src/ui/CardTile.spec.js`.

**Interfaces :**
- Consumes : `cardThumb`, `DOMAINS` (`src/api.js`), `isFoil`, `variantLabel` (`src/cardText.js`), `formatEur`, `PRICE_NOTE` (`src/prices.js`), `CardHoverPreview` (`src/components/CardHoverPreview.vue`, inchangé).
- Produces : `<CardTile :card :preview?="true" />`, composé ainsi :
  - un `RouterLink` vers `/cartes/<id>`, de classe `card-tile` (`.landscape` pour une carte paysage), qui contient :
    - l'illustration en `<img>`, `loading="lazy"`, `cardThumb(…, 320)` ;
    - le badge de variante (`.tile-badge`) s'il ne s'agit pas d'une « Normale » ;
    - la quantité possédée (`.tile-owned`, « ×N ») si `owned_qty > 0` ;
    - un calque `.tile-foil` si `isFoil(card)` ;
    - le nom (`.tile-name`) ;
    - une ligne méta (`.tile-meta`) : code en capitales et prix (`.tile-price`, `title=PRICE_NOTE`) s'il existe ;
  - le tout enveloppé dans `CardHoverPreview` (`disabled` si `!preview`).
- Le bord supérieur de la vignette prend la couleur du premier domaine (`--tile-accent`, `DOMAINS[d].color`, par défaut `var(--bronze)`).

- [ ] **Step 1 : écrire le test**

`src/ui/CardTile.spec.js` :

```js
import { mount, RouterLinkStub } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import CardTile from "./CardTile.vue"

const base = { id: "ogn-001", name: "Ahri", riftbound_id: "ogn-001-298", image_url: "https://cdn/x.png", domains: ["Mind"] }
const mountTile = (card, props = {}) =>
  mount(CardTile, { props: { card, ...props }, global: { stubs: { RouterLink: RouterLinkStub } } })

describe("CardTile", () => {
  it("mène à la fiche, avec nom, code et accent du domaine", () => {
    const wrapper = mountTile(base)
    expect(wrapper.getComponent(RouterLinkStub).props("to")).toBe("/cartes/ogn-001")
    expect(wrapper.get(".tile-name").text()).toBe("Ahri")
    expect(wrapper.get(".tile-meta").text()).toContain("OGN-001-298")
    expect(wrapper.get(".card-tile").attributes("style")).toContain("--tile-accent: var(--mind)")
    expect(wrapper.get("img").attributes("loading")).toBe("lazy")
  })

  it("foil, badge de variante, quantité et prix quand ils existent", () => {
    const wrapper = mountTile({ ...base, alternate_art: true, owned_qty: 2, price_eur: 12.4 })
    expect(wrapper.find(".tile-foil").exists()).toBe(true)
    expect(wrapper.get(".tile-badge").text()).toBe("Alt")
    expect(wrapper.get(".tile-owned").text()).toBe("×2")
    expect(wrapper.get(".tile-price").text()).toMatch(/12,40/)
  })

  it("rien de superflu pour une carte normale sans exemplaire ni prix", () => {
    const wrapper = mountTile(base)
    expect(wrapper.find(".tile-foil").exists()).toBe(false)
    expect(wrapper.find(".tile-badge").exists()).toBe(false)
    expect(wrapper.find(".tile-owned").exists()).toBe(false)
    expect(wrapper.find(".tile-price").exists()).toBe(false)
  })

  it("une carte paysage garde ses proportions", () => {
    expect(mountTile({ ...base, orientation: "landscape" }).get(".card-tile").classes()).toContain("landscape")
  })
})
```

- [ ] **Step 2 : vérifier l'échec**, puis **Step 3 : écrire `src/ui/CardTile.vue`**

```vue
<script setup>
import { computed } from "vue"
import { cardThumb, DOMAINS } from "../api.js"
import { isFoil, variantLabel } from "../cardText.js"
import CardHoverPreview from "../components/CardHoverPreview.vue"
import { formatEur, PRICE_NOTE } from "../prices.js"

/* Vignette Forgée : l'illustration d'abord, le reflet foil au survol des cartes
   rares, un filet de la couleur du domaine, le nom et le prix dessous. */
const props = defineProps({
  card: { type: Object, required: true },
  preview: { type: Boolean, default: true }
})
const foil = computed(() => isFoil(props.card))
const badge = computed(() => {
  const label = variantLabel(props.card)
  return label === "Normale" ? "" : label
})
const price = computed(() => formatEur(props.card.price_eur))
const style = computed(() => ({ "--tile-accent": DOMAINS[props.card.domains?.[0]]?.color || "var(--bronze)" }))
</script>

<template>
  <CardHoverPreview :card="card" :disabled="!preview">
    <RouterLink
      :to="`/cartes/${card.id}`"
      class="card-tile"
      :class="{ landscape: card.orientation === 'landscape' }"
      :style="style"
    >
      <span class="tile-art">
        <img
          :src="cardThumb(card.image_url, 320)"
          :alt="`Carte Riftbound : ${card.name}`"
          loading="lazy"
          decoding="async"
        />
        <span v-if="foil" class="tile-foil" aria-hidden="true"></span>
        <span v-if="badge" class="tile-badge">{{ badge }}</span>
        <span v-if="card.owned_qty" class="tile-owned">×{{ card.owned_qty }}</span>
      </span>
      <span class="tile-name">{{ card.name }}</span>
      <span class="tile-meta">
        <span>{{ (card.riftbound_id || "").toUpperCase() }}</span>
        <span v-if="price" class="tile-price" :title="PRICE_NOTE">{{ price }}</span>
      </span>
    </RouterLink>
  </CardHoverPreview>
</template>

<style scoped>
.card-tile {
  display: grid;
  gap: var(--space-1);
  padding: var(--space-2);
  background: var(--bg-raised);
  border-top: 2px solid var(--tile-accent);
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  transition: box-shadow var(--t-fast);
}
.card-tile:hover,
.card-tile:focus-visible {
  color: var(--ink);
  box-shadow: inset 0 0 0 1px var(--bronze);
}
.tile-art {
  position: relative;
  display: block;
  overflow: hidden;
  border-radius: var(--radius-card);
}
.tile-art img {
  width: 100%;
  aspect-ratio: 0.716;
  object-fit: cover;
}
.card-tile.landscape .tile-art img {
  aspect-ratio: 1.396;
}
.tile-foil {
  position: absolute;
  inset: 0;
  background: linear-gradient(115deg, transparent 30%, rgba(255, 236, 200, 0.35) 48%, transparent 66%);
  background-size: 250% 100%;
  background-position: 120% 0;
  mix-blend-mode: screen;
  opacity: 0;
  transition:
    opacity var(--t-base),
    background-position 900ms ease;
}
.card-tile:hover .tile-foil {
  opacity: 1;
  background-position: -60% 0;
}
.tile-badge,
.tile-owned {
  position: absolute;
  top: var(--space-1);
  padding: 1px 6px;
  background: rgba(13, 13, 15, 0.85);
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.tile-badge {
  left: var(--space-1);
  color: var(--bronze-light);
}
.tile-owned {
  right: var(--space-1);
  color: #fff;
  background: var(--blood);
}
.tile-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}
.tile-meta {
  display: flex;
  justify-content: space-between;
  gap: var(--space-2);
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.tile-price {
  color: var(--bronze-light);
}
@media (prefers-reduced-motion: reduce) {
  .tile-foil {
    display: none;
  }
}
</style>
```

- [ ] **Step 4 : vérifier le succès**, puis **commit** `Web : nouvelle vignette de carte Forgée (CardTile)`.

---

### Task 3 : `CardFilters` et `ActiveFilters`

**Files :** Create `src/cards/CardFilters.vue`, `src/cards/CardFilters.spec.js`, `src/cards/ActiveFilters.vue`, `src/cards/ActiveFilters.spec.js`.

**Interfaces :**
- **Facettes** (même ordre partout) : `domain` (« Domaines »), `type` (« Types »), `rarity` (« Raretés »), `energy` (« Coût »), `set_id` (« Sets »). Options :
  - `domainFilterOptions()` (avec glyphe de rune), `typeFilterOptions()`, `rarityFilterOptions()` et `energyFilterOptions()` (avec glyphe d'énergie), tous de `cardText.js` ;
  - les sets viennent de la prop `sets`, sous forme `{ value: set_id, label: name }`.
- `<CardFilters :state :sets @update="(key, values) => …" />` :
  - un `RiftField search` (label « Rechercher une carte », masqué, placeholder « Jinx, ogn-202, reaction… »), lié à `state.q` par l'événement `update("q", value)` ;
  - puis un `<fieldset>` par facette, avec une `<legend>` et une liste de `RiftChip` en bascule ;
  - basculer une option émet `update(key, toggleValue(state[key], value))` (`toggleValue` de `cardText.js`) ;
  - la couleur d'une puce de domaine vient de `DOMAINS[value].color`.
- `<ActiveFilters :state :sets @update @reset />` :
  - pour chaque valeur active des cinq facettes, un `RiftChip removable` avec le libellé lisible : nom du domaine, du type, de la rareté, « Coût 3 », nom du set (repli sur l'identifiant) ;
  - le retrait émet `update(key, state[key].filter((v) => v !== value))` ;
  - une recherche active ajoute la puce « « texte » », dont le retrait émet `update("q", "")` ;
  - au-delà d'un filtre actif, un `RiftButton variant="ghost" size="sm"` « Tout effacer » émet `reset` ;
  - rien n'est rendu sans filtre actif.

- [ ] **Step 1 : vérifier l'API de `toggleValue` et de `state`**

Run : `sed -n 245,260p src/cardText.js && sed -n 1,40p src/composables/useQuerySyncedFilters.js`.
Confirmer que `toggleValue(list, value)` renvoie une nouvelle liste, et que les clés du schéma sont `q`, `set_id`, `type`, `domain`, `rarity`, `energy`. Les valeurs de liste sont des tableaux de chaînes.

- [ ] **Step 2 : écrire les tests**

`src/cards/CardFilters.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import CardFilters from "./CardFilters.vue"

const empty = () => ({ q: "", set_id: [], type: [], domain: [], rarity: [], energy: [] })
const SETS = [{ value: "ogn", label: "Origins" }]
const mountFilters = (state = empty()) =>
  mount(CardFilters, { props: { state, sets: SETS }, global: { components: { Icon } } })

describe("CardFilters", () => {
  it("une légende par facette, dans l'ordre", () => {
    const legends = mountFilters().findAll("legend").map((l) => l.text())
    expect(legends).toEqual(["Domaines", "Types", "Raretés", "Coût", "Sets"])
  })

  it("raretés officielles dans l'ordre du jeu", () => {
    const fieldset = mountFilters().findAll("fieldset")[2]
    expect(fieldset.findAll("button").map((b) => b.text())).toEqual([
      "Commun",
      "Peu commun",
      "Rare",
      "Épique",
      "Showcase",
      "Promo"
    ])
  })

  it("runes officielles sur les domaines, énergies sur le coût", () => {
    const wrapper = mountFilters()
    expect(wrapper.findAll("fieldset")[0].findAll("img.rb-glyph.rune").length).toBe(6)
    expect(wrapper.findAll("fieldset")[3].findAll("img.rb-glyph.energy").length).toBe(8)
  })

  it("basculer une option émet la nouvelle liste ; l'état coché suit le state", async () => {
    const state = { ...empty(), domain: ["Fury"] }
    const wrapper = mountFilters(state)
    const fury = wrapper.findAll("fieldset")[0].findAll("button")[0]
    expect(fury.attributes("aria-pressed")).toBe("true")
    await wrapper.findAll("fieldset")[4].get("button").trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["set_id", ["ogn"]])
    await fury.trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["domain", []])
  })

  it("la recherche émet q", async () => {
    const wrapper = mountFilters()
    await wrapper.get("input").setValue("jinx")
    expect(wrapper.emitted("update").at(-1)).toEqual(["q", "jinx"])
  })
})
```

`src/cards/ActiveFilters.spec.js` :

```js
import { mount, RouterLinkStub } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import ActiveFilters from "./ActiveFilters.vue"

const SETS = [{ value: "sfd", label: "Spiritforged" }]
const state = (over = {}) => ({ q: "", set_id: [], type: [], domain: [], rarity: [], energy: [], ...over })
const mountActive = (s) =>
  mount(ActiveFilters, { props: { state: s, sets: SETS }, global: { stubs: { RouterLink: RouterLinkStub } } })

describe("ActiveFilters", () => {
  it("rien sans filtre actif", () => {
    expect(mountActive(state()).find(".active-filters").exists()).toBe(false)
  })

  it("libellés lisibles, y compris un set venu de l'URL", () => {
    const wrapper = mountActive(state({ set_id: ["sfd"], domain: ["Fury"], energy: ["3"], q: "ahri" }))
    const labels = wrapper.findAll("button.rift-chip").map((b) => b.text().replace("✕", "").trim())
    expect(labels).toEqual(["« ahri »", "Fureur", "Coût 3", "Spiritforged"])
  })

  it("retirer une puce émet la liste sans cette valeur ; « Tout effacer » émet reset", async () => {
    const wrapper = mountActive(state({ domain: ["Fury", "Calm"] }))
    await wrapper.findAll("button.rift-chip")[0].trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["domain", ["Calm"]])
    await wrapper.findAll("button").at(-1).trigger("click")
    expect(wrapper.emitted("reset")).toHaveLength(1)
  })
})
```

- [ ] **Step 3 : vérifier l'échec**, puis **Step 4 : écrire `src/cards/CardFilters.vue`**

```vue
<script setup>
import { computed } from "vue"
import { DOMAINS } from "../api.js"
import {
  domainFilterOptions,
  energyFilterOptions,
  rarityFilterOptions,
  toggleValue,
  typeFilterOptions
} from "../cardText.js"
import RiftChip from "../ui/RiftChip.vue"
import RiftField from "../ui/RiftField.vue"

/* Contenu du panneau de filtres de la cartothèque : la recherche, puis une facette par
   fieldset, options en puces à bascule. L'état vit dans useQuerySyncedFilters (URL). */
const props = defineProps({
  state: { type: Object, required: true },
  sets: { type: Array, default: () => [] }
})
const emit = defineEmits(["update"])

const facets = computed(() => [
  { key: "domain", label: "Domaines", options: domainFilterOptions() },
  { key: "type", label: "Types", options: typeFilterOptions() },
  { key: "rarity", label: "Raretés", options: rarityFilterOptions() },
  { key: "energy", label: "Coût", options: energyFilterOptions() },
  { key: "set_id", label: "Sets", options: props.sets }
])

function toggle(key, value) {
  emit("update", key, toggleValue(props.state[key], value))
}
</script>

<template>
  <div class="card-filters">
    <RiftField
      search
      hide-label
      label="Rechercher une carte"
      placeholder="Jinx, ogn-202, reaction…"
      :model-value="state.q"
      inputmode="search"
      enterkeyhint="search"
      autocapitalize="off"
      autocorrect="off"
      spellcheck="false"
      @update:model-value="emit('update', 'q', $event)"
    />
    <fieldset v-for="facet in facets" :key="facet.key" class="facet">
      <legend>{{ facet.label }}</legend>
      <div class="facet-options">
        <RiftChip
          v-for="option in facet.options"
          :key="option.value"
          :label="option.label"
          :glyph="option.glyph"
          :glyph-kind="option.glyphKind"
          :color="facet.key === 'domain' ? DOMAINS[option.value]?.color : ''"
          :selected="state[facet.key].includes(option.value)"
          @toggle="toggle(facet.key, option.value)"
        />
      </div>
    </fieldset>
  </div>
</template>

<style scoped>
.card-filters {
  display: grid;
  gap: var(--space-4);
}
.facet {
  border: none;
}
.facet legend {
  margin-bottom: var(--space-2);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.facet-options {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}
</style>
```

- [ ] **Step 5 : écrire `src/cards/ActiveFilters.vue`**

```vue
<script setup>
import { computed } from "vue"
import { DOMAINS, RARITIES, TYPES } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"

/* Filtres actifs au-dessus de la grille : on voit d'un coup d'œil pourquoi la liste
   est réduite, et on retire un filtre d'un clic. */
const props = defineProps({
  state: { type: Object, required: true },
  sets: { type: Array, default: () => [] }
})
const emit = defineEmits(["update", "reset"])

const ORDER = ["domain", "type", "rarity", "energy", "set_id"]

function labelOf(key, value) {
  if (key === "domain") return DOMAINS[value]?.label || value
  if (key === "type") return TYPES[value] || value
  if (key === "rarity") return RARITIES[value] || value
  if (key === "energy") return `Coût ${value === "7+" ? "7 et plus" : value}`
  return props.sets.find((set) => set.value === value)?.label || value
}

const chips = computed(() => {
  const list = []
  if (props.state.q?.trim()) list.push({ key: "q", value: props.state.q, label: `« ${props.state.q.trim()} »` })
  for (const key of ORDER) {
    for (const value of props.state[key] ?? []) list.push({ key, value, label: labelOf(key, value) })
  }
  return list
})

function remove(chip) {
  if (chip.key === "q") emit("update", "q", "")
  else emit("update", chip.key, props.state[chip.key].filter((value) => value !== chip.value))
}
</script>

<template>
  <div v-if="chips.length" class="active-filters" aria-label="Filtres actifs">
    <RiftChip
      v-for="chip in chips"
      :key="`${chip.key}:${chip.value}`"
      removable
      :label="chip.label"
      :color="chip.key === 'domain' ? DOMAINS[chip.value]?.color : ''"
      @remove="remove(chip)"
    />
    <RiftButton v-if="chips.length > 1" variant="ghost" size="sm" @click="emit('reset')">Tout effacer</RiftButton>
  </div>
</template>

<style scoped>
.active-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}
</style>
```

- [ ] **Step 6 : vérifier le succès**, puis **commit** `Web : filtres de la cartothèque (panneau et puces actives)`.

---

### Task 4 : nouvelle cartothèque (`CardsView`)

**Files :** Modify `src/views/CardsView.vue` (réécrit) et `src/views/CardsView.spec.js` (adapté).

**Interfaces :**
- Consumes : `useQuerySyncedFilters` (schéma inchangé), `useGridMeasure`, `useScrollMemory`, `cardsQuery`, `useBreakpoint`, `CardFilters`, `ActiveFilters`, `CardTile` (`src/ui/`), `RiftSheet`, `RiftButton`, `RiftEmpty`, `RiftSkeleton`.
- Produces : la page. La mise en page change selon le palier d'écran :
  - **Bureau** (`desktop`) :
    - à gauche, un panneau de filtres collant de 280 px (`<aside class="filters-panel" aria-label="Filtres">`) qui contient `CardFilters` ;
    - un bouton « Masquer les filtres » / « Filtres » le replie, et ce choix vit le temps de la session (pas de stockage).
  - **Tablette et téléphone** :
    - un `RiftButton variant="secondary"` « Filtres (N) » ouvre une `RiftSheet title="Filtres"` qui contient `CardFilters` ;
    - en pied de feuille, « Voir les N cartes » (N = `result.total`) ferme la feuille ;
    - changer un filtre ne ferme pas la feuille.
  - **En-tête** : `<h1>Cartes</h1>` et le compteur « N cartes » (`.cards-count`). Plus de `PageBanner`.
  - **Au-dessus de la grille** : `ActiveFilters`.
  - **Grille** `.cards-grid` (`ref="grid"`, `--tile-min`) de `CardTile`. Elle est atténuée (`.reloading`, `opacity: 0.55`) pendant un rechargement s'il y a déjà des résultats.
  - **Premier chargement** (`loading` sans résultat) : douze `RiftSkeleton block` à la place des tuiles.
  - **État vide** : `RiftEmpty` « Aucune carte ne correspond aux filtres », avec un bouton « Réinitialiser les filtres » si des filtres sont actifs.
  - **Pagination** : deux `RiftButton variant="ghost" size="sm"` (« ← Précédent », « Suivant → ») et « page X / Y ».
  - **Erreur** : `<p class="cards-error" role="alert">`.

- [ ] **Step 1 : adapter `src/views/CardsView.spec.js`**

Lire la spec actuelle et garder ses cas métier, en adaptant les sélecteurs.
- Les cas « filtres repliés plutôt que chips » et « illustration officielle » n'ont plus d'objet : les remplacer par les tests ci-dessous.
- « raretés », « runes », « taille de page », « aucun résultat », « filtres dans l'URL et dans la requête » : les conserver en ciblant `CardFilters` / `RiftEmpty` / `button.rift-chip`.

Ajouter :

```js
  it("une URL avec filtres (lien du mur de l'accueil) s'affiche en puces actives", async () => {
    // monter la vue sur /cartes?set=sfd&domain=Fury (même harnais de routeur et d'api que les autres cas)
    // puis attendre le chargement : les puces actives contiennent « Fureur » et le nom du set.
  })

  it("téléphone : bouton Filtres (N), feuille qui reste ouverte au changement, fermée par « Voir les N cartes »", async () => {
    // stub de matchMedia à 390 px comme dans App.spec.js ; ouvrir la feuille, cliquer une puce,
    // vérifier que .rift-sheet est toujours là, puis cliquer « Voir les … cartes » → feuille fermée.
  })

  it("premier chargement : squelettes ; rechargement : grille atténuée, pas vidée", async () => {
    // api lente (promesse non résolue) → 12 .rift-skeleton ; après résolution puis nouveau filtre
    // avec une promesse en attente → .cards-grid.reloading et les tuiles précédentes toujours présentes.
  })
```

Les commentaires ci-dessus décrivent le scénario. Écrire le code complet de ces trois tests en réutilisant le harnais existant du fichier (routeur mémoire, `vi.mock` de `../api.js`) ; si le harnais ne permet pas de monter sur une URL avec requête, utiliser `makeRouter("/cartes?set=sfd&domain=Fury")` de `src/test/makeRouter.js`.

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/views/CardsView.spec.js`
Expected : FAIL sur les nouveaux cas.

- [ ] **Step 3 : réécrire `src/views/CardsView.vue`**

```vue
<script setup>
import { computed, onMounted, ref, watch } from "vue"
import { api } from "../api.js"
import ActiveFilters from "../cards/ActiveFilters.vue"
import CardFilters from "../cards/CardFilters.vue"
import { cardsQuery } from "../cardText.js"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { useGridMeasure } from "../composables/useGridMeasure.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { useScrollMemory } from "../composables/useScrollMemory.js"
import CardTile from "../ui/CardTile.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

/* Cartothèque Forgée : filtres en panneau (feuille sur petit écran), filtres actifs en
   puces, grille de vignettes. L'état des filtres vit dans l'URL. */
const { restoreScroll } = useScrollMemory()
const breakpoint = useBreakpoint()
const desktop = computed(() => breakpoint.value === "desktop")

const grid = ref(null)
const { tileMin, size } = useGridMeasure(grid)
let firstLoad = true

const { state, result, loading, error, activeCount, pageCount, setFilter, reset, load, scheduleLoad } =
  useQuerySyncedFilters(
    {
      q: { kind: "text" },
      set_id: { kind: "list", param: "set" },
      type: { kind: "list" },
      domain: { kind: "list" },
      rarity: { kind: "list" },
      energy: { kind: "list" },
      page: { kind: "page" }
    },
    {
      fetcher: (filters) => api(`/api/cards?${cardsQuery(filters, size.value)}`),
      pageSize: size,
      onLoaded: () => {
        if (firstLoad) {
          firstLoad = false
          restoreScroll()
        }
      }
    }
  )

const sets = ref([])
const setOptions = computed(() => sets.value.map((item) => ({ value: item.set_id, label: item.name })))
const panelOpen = ref(true)
const sheetOpen = ref(false)

function update(key, value) {
  if (key === "q") state.q = value
  else setFilter(key, value)
}

watch(size, () => {
  if (state.page > pageCount.value) state.page = 1
  else scheduleLoad()
})

onMounted(async () => {
  load()
  try {
    sets.value = await api("/api/sets")
  } catch {
    /* filtre des sets indisponible : les autres facettes restent utilisables */
  }
})
</script>

<template>
  <section class="cards-page" :class="{ 'with-panel': desktop && panelOpen }">
    <header class="cards-head">
      <div>
        <h1>Cartes</h1>
        <p class="cards-count">{{ result.total }} carte{{ result.total > 1 ? "s" : "" }}</p>
      </div>
      <RiftButton v-if="desktop" variant="ghost" size="sm" @click="panelOpen = !panelOpen">
        {{ panelOpen ? "Masquer les filtres" : "Filtres" }}
      </RiftButton>
      <RiftButton v-else variant="secondary" size="sm" @click="sheetOpen = true">
        Filtres<template v-if="activeCount"> ({{ activeCount }})</template>
      </RiftButton>
    </header>

    <aside v-if="desktop && panelOpen" class="filters-panel" aria-label="Filtres">
      <CardFilters :state="state" :sets="setOptions" @update="update" />
    </aside>

    <div class="cards-main">
      <ActiveFilters :state="state" :sets="setOptions" @update="update" @reset="reset" />
      <p v-if="error" class="cards-error" role="alert">{{ error }}</p>

      <div v-if="loading && !result.items.length" class="cards-grid" :style="{ '--tile-min': `${tileMin}px` }">
        <RiftSkeleton v-for="n in 12" :key="n" block />
      </div>
      <div
        v-show="result.items.length"
        ref="grid"
        class="cards-grid"
        :class="{ reloading: loading }"
        :style="{ '--tile-min': `${tileMin}px` }"
      >
        <CardTile v-for="card in result.items" :key="card.id" :card="card" />
      </div>

      <RiftEmpty v-if="!loading && !error && !result.items.length" title="Aucune carte ne correspond aux filtres">
        <RiftButton v-if="activeCount" variant="secondary" size="sm" @click="reset">
          Réinitialiser les filtres
        </RiftButton>
      </RiftEmpty>

      <nav v-if="pageCount > 1" class="cards-pager" aria-label="Pagination">
        <RiftButton variant="ghost" size="sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</RiftButton>
        <span>page {{ state.page }} / {{ pageCount }}</span>
        <RiftButton variant="ghost" size="sm" :disabled="state.page >= pageCount" @click="state.page++">
          Suivant →
        </RiftButton>
      </nav>
    </div>
  </section>

  <RiftSheet v-if="sheetOpen && !desktop" title="Filtres" @close="sheetOpen = false">
    <CardFilters :state="state" :sets="setOptions" @update="update" />
    <div class="sheet-foot">
      <RiftButton block @click="sheetOpen = false">Voir les {{ result.total }} cartes</RiftButton>
    </div>
  </RiftSheet>
</template>

<style scoped>
.cards-page {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  grid-template-areas: "head" "main";
  gap: var(--space-5);
  padding: var(--space-6);
}
.cards-page.with-panel {
  grid-template-columns: 280px minmax(0, 1fr);
  grid-template-areas: "head head" "panel main";
}
.cards-head {
  grid-area: head;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: var(--space-4);
}
.cards-head h1 {
  margin: 0;
  font-size: clamp(28px, 4vw, 40px);
  text-transform: uppercase;
  background: none;
  color: var(--ink);
  animation: none;
}
.cards-count {
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.filters-panel {
  grid-area: panel;
  position: sticky;
  top: calc(var(--topbar-h) + var(--space-4));
  align-self: start;
  max-height: calc(100dvh - var(--topbar-h) - var(--space-6));
  overflow-y: auto;
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.cards-main {
  grid-area: main;
  display: grid;
  gap: var(--space-4);
  align-content: start;
}
.cards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(var(--tile-min, 180px), 1fr));
  gap: var(--space-4);
  transition: opacity var(--t-base);
}
.cards-grid.reloading {
  opacity: 0.55;
}
.cards-error {
  color: var(--blood-text);
}
.cards-pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  font-family: var(--font-label);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.sheet-foot {
  position: sticky;
  bottom: 0;
  margin-top: var(--space-4);
  padding-top: var(--space-3);
  background: var(--bg-raised);
}
@media (max-width: 767px) {
  .cards-page {
    padding: var(--space-4);
  }
}
</style>
```

Vérifier le comportement de `useQuerySyncedFilters` sur la saisie de `q` : soit `state.q` est surveillé avec un anti-rebond, soit il faut appeler `setFilter("q", value)`. Utiliser la voie que la composable prévoit (lire le fichier), et ajuster `update()` en conséquence.

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/views/CardsView.spec.js`. Expected : PASS.

- [ ] **Step 5 : commit** `Web : nouvelle cartothèque (panneau de filtres, puces actives, vignettes Forgées)`.

---

### Task 5 : `CardCollectionPanel`

**Files :** Create `src/cards/CardCollectionPanel.vue`, `src/cards/CardCollectionPanel.spec.js`.

**Interfaces :**
- Consumes : `api`, `session`, `CONDITIONS`, `LANGS` (`src/api.js`) ; `RiftButton`.
- Produces : `<CardCollectionPanel :card @change="(patch) => …" />`.
  - **Visiteur** : seulement « Connectez-vous pour suivre vos exemplaires et votre wishlist », avec un lien `/connexion`.
  - **Membre** :
    - le bouton wishlist (`aria-pressed`, PUT `{qty:1}` puis DELETE), qui émet `change({ wished_qty })` ;
    - la liste des lots (quantité, état, langue, Enregistrer, Retirer) et le formulaire d'ajout ;
    - à chaque réponse, émet `change({ owned_qty: total_qty })` et affiche le message (`.panel-saved`) ;
    - les erreurs s'affichent en `.panel-error` (`role="alert"`) sans vider la saisie.
  - **Chargement des lots** : via `GET /api/collection/<id>` quand `card.id` change ; un échec laisse la liste vide sans erreur visible. Garde anti-course : seul le dernier `card.id` écrit.
  - **Reprise de l'existant** : toute la logique vient de l'actuel `CardView.vue` (`validQty`, `mutate`, `addEntry`, `saveEntry`, `removeEntry`, `toggleWish`). La déplacer, sans la réécrire autrement que pour l'adapter aux props et événements.

- [ ] **Step 1 : déplacer les tests**

Déplacer de `CardView.spec.js` vers `src/cards/CardCollectionPanel.spec.js` les cas suivants, en montant directement `CardCollectionPanel` avec une carte factice :
- « visiteur non connecté : pas de bouton wishlist » ;
- « connecté : le cœur bascule l'ajout (PUT qty 1) puis le retrait (DELETE) » ;
- « ajoute un lot : POST puis remise à 1 » ;
- « ajout en échec : la saisie est conservée et l'erreur affichée » ;
- « les lots indisponibles ne masquent pas la fiche », réécrit en « un échec de chargement des lots laisse le panneau utilisable ».

Ajouter : « changer de carte recharge les lots de la nouvelle carte » (`setProps` vers une autre carte, le GET part avec le nouvel id, et une réponse tardive de l'ancien id est ignorée).

- [ ] **Step 2 : vérifier l'échec**, **Step 3 : écrire le composant** en reprenant la logique de `CardView.vue`.

Styles scoped :
- les champs : `background: var(--bg-sunken)`, `border: 1px solid var(--line)`, `min-height: 40px` ;
- les lignes de lot : grille sur quatre colonnes, empilée sous 480 px.

- [ ] **Step 4 : vérifier le succès**, puis **commit** `Web : panneau collection et wishlist de la fiche carte`.

---

### Task 6 : nouvelle fiche carte (`CardView`)

**Files :** Modify `src/views/CardView.vue` (réécrit) et `src/views/CardView.spec.js` (adapté).

**Interfaces :**
- Consumes : `CardCollectionPanel`, `RiftStat`, `RiftPanel`, `RiftText`, `RiftChip`, `setPageCrumb` ; `glyphUrl`, `powerRuneGlyphs`, `isFoil`, `variantLabel`, `DOMAIN_RUNE` (`cardText.js`) ; `formatEur`, `cardmarketUrl`, `usePricesMeta`, `PRICE_SOURCE_NOTE` (`prices.js`) ; `applySeo`.
- Produces : la fiche, en deux colonnes.
  - **Colonne gauche** (`.sheet-visual`) :
    - l'illustration avec son reflet foil au survol si `isFoil` ;
    - **directement dessous** : les variantes (`RiftChip` en bascule, `aria-pressed` sur la variante affichée, `router.replace`), le bloc prix (montant, foil, note, lien Cardmarket ; absent sans prix), puis `CardCollectionPanel` ;
    - le crédit (code, illustrateur, « © Riot Games »).
  - **Colonne droite** (`.sheet-copy`) :
    - le surtitre : glyphe de rune du premier domaine (`glyphUrl("rune_" + DOMAIN_RUNE[d])`), puis « Type · Domaine(s) » ;
    - `<h1>` du nom, en Cinzel (avec la neutralisation de la règle `h1` héritée : `background: none; color: var(--ink); animation: none`) ;
    - les `RiftStat`, chacun rendu seulement si sa donnée existe : Énergie (glyphe `energy_N`), Puissance (glyphe `might` en masque + valeur), Pouvoir (slot de runes `powerRuneGlyphs`) ;
    - un `RiftPanel title="Capacité"` contenant `<RiftText tag="p" class="card-text" :text>`, seulement si la carte a un texte ;
    - la citation d'ambiance ;
    - une liste `<dl class="sheet-meta">` : Set, Numéro, Rareté, Illustration (si connue).
  - **Carte paysage** : `.landscape`, l'illustration passe au-dessus et les deux colonnes s'empilent.
  - **Fil d'Ariane** : `setPageCrumb(card.name)` à chaque chargement.
  - **Lien retour** : il reste, selon l'historique (« ← Ma collection » ou « ← Cartothèque »).
  - **Logique conservée** : séquence anti-course, `applySeo`, pas d'appel pour un id indéfini.
  - Le panneau émet `change`, appliqué sur `card` (`owned_qty`, `wished_qty`).

- [ ] **Step 1 : adapter `src/views/CardView.spec.js`**

Garder les cas de mise en page (deux colonnes, paysage), de prix (avec et sans), et « navigation sortante sans `/api/cards/undefined` », en adaptant les sélecteurs. Les cas déplacés en tâche 5 sont retirés. Ajouter :
- « sort sans puissance ni pouvoir : seule la stat d'énergie est rendue » ;
- « champ de bataille sans énergie : aucun RiftStat » ;
- « le fil d'Ariane prend le nom de la carte, puis celui de la variante ouverte » : `pageCrumb.value` vaut le nom, puis, après un clic sur une puce de variante et le chargement, le nom de la variante ;
- « les variantes sont sous l'illustration et marquent la variante affichée » : `.sheet-visual` contient les puces, `aria-pressed="true"` sur la carte courante.

- [ ] **Step 2 : vérifier l'échec**, **Step 3 : réécrire `CardView.vue`**

Reprendre le `<script setup>` actuel moins la logique déplacée dans `CardCollectionPanel`, et ajouter :
- `setPageCrumb` ;
- le calcul de `runeGlyph` : `glyphUrl("rune_" + (DOMAIN_RUNE[card.domains?.[0]] || "rainbow"))` ;
- le gestionnaire `onCollectionChange(patch)`, qui fait `Object.assign(card.value, patch)`.

Pour le template et les styles scoped, suivre l'interface ci-dessus :
- colonnes `minmax(280px, 400px) minmax(0, 1fr)`, `gap: var(--space-6)` ;
- les deux colonnes s'empilent sous 900 px, ou en mode paysage ;
- reflet foil : même technique que `CardTile` (calque en dégradé, déclenché au survol, masqué sous reduced-motion).

- [ ] **Step 4 : vérifier le succès**, puis **commit** `Web : nouvelle fiche carte (variantes, prix et collection sous l'illustration)`.

---

### Task 7 : nettoyage et documentation

**Files :** Modify `src/assets/main.css` et la spec.

- [ ] **Step 1 : supprimer les règles de l'ancienne liste et de l'ancienne fiche**

Les classes suivantes, propres aux anciens `CardsView.vue` et `CardView.vue`, ne sont utilisées par aucune autre vue (vérifié pendant la rédaction du plan) :
- `card-sheet`, `sheet-visual`, `sheet-copy`, `sheet-tags`, `sheet-tag` ;
- `stat-glyphs` ;
- `price-block`, `price-line`, `price-foil`, `price-note`, `price-link` ;
- `wish-toggle`, `variant-switch`, `card-back`, `card-credit`, `rules-text`, `flavour` ;
- `sheet-collection`, `sheet-qty`, `sheet-entry`, `sheet-add`, `sheet-login`, `sheet-art`.

À l'inverse, `filter-board`, `filter-search`, `grid-cards`, `pager`, `stat-row`, `price-amount`, `t-meta`, `col-empty`, `card-tile`, `card-art`, `card-foil` et `card-hover` / `card-preview` sont **encore utilisées** ailleurs : elles **restent**.

Revérifier chaque classe par grep dans `src` (`.vue`) avant de supprimer ses règles (racine et `@media`), en gardant les autres sélecteurs des listes groupées.

Run : `grep -nE "\.(card-sheet|sheet-(visual|copy|tags?|collection|qty|entry|add|login|art)|stat-glyphs|price-(block|line|foil|note|link)|wish-toggle|variant-switch|card-back|card-credit|rules-text|flavour)\b" src/assets/main.css`. Expected : rien.

- [ ] **Step 2 : spec**

Dans le §5 PR 3, ajouter :
- composants livrés : `RiftChip`, `RiftEmpty`, `RiftStat`, `CardTile` (`src/ui/`), plus `CardFilters`, `ActiveFilters` et `CardCollectionPanel` (`src/cards/`) ;
- l'ancienne vignette (`components/CardTile.vue`) et `FilterSelect` restent pour les pages collection, wishlist et decks jusqu'à leurs PR.

- [ ] **Step 3** : `npm run check` vert, puis deux commits : `Web : retrait des styles de l'ancienne cartothèque` et `Docs : spec — composants livrés en PR 3`.

---

### Task 8 : validation par le mainteneur (contrôleur)

- [ ] Transmettre au mainteneur la liste suivante et attendre son accord :
  - **Liste**
    - Filtres en panneau (bureau) qui se replie, puis en feuille (téléphone).
    - Puces actives et « Tout effacer ».
    - Lien du mur de l'accueil, qui arrive filtré sur le set.
    - Recherche.
    - Vignettes : reflet foil au survol des cartes rares, quantité possédée, prix.
    - Squelettes et état vide.
  - **Fiche**
    - Une unité, un sort, un champ de bataille.
    - Glyphes d'énergie, de puissance et de runes.
    - Mots-clés en pastilles.
    - Variantes sous l'illustration.
    - Prix.
    - Lots et wishlist, connecté puis déconnecté.
    - Fil d'Ariane avec le nom de la carte.
- [ ] Après accord : push, puis PR vers `refonte/forge` avec la ligne « 🤖 Generated with [Claude Code](https://claude.com/claude-code) ».
