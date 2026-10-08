# Refonte Forge noxienne — PR 2 : accueil — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** remplacer l'accueil actuel (éventail de trois cartes, rivière, salles) par l'accueil Forge noxienne : un splash cinématique, un mur de cartes du dernier set et trois blocs Forgés, génériques pour un visiteur et personnels pour un membre connecté.

**Architecture :** la logique de données de l'accueil est isolée dans des fonctions pures (`src/home/homeData.js`). Trois composants de section (`HomeSplash`, `CardWall`, `HomeBlocks`) sont composés par `HomeView.vue`. Deux nouveaux composants de base, `RiftPanel` et `RiftSkeleton`, rejoignent `src/ui/`. Aucun changement d'API : les données viennent de `/api/sets`, `/api/cards`, `/api/collection/sets`, `/api/decks/mine` et `/api/play/history`.

**Tech Stack :** Vue 3.5 (`<script setup>`), vue-router 5, Vite 8, Vitest 4 + @vue/test-utils + jsdom, Prettier (sans point-virgule, guillemets doubles, 120 colonnes).

**Spec :** `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§2, §3, §3.4, §5 PR 2)

## Global Constraints

- **Branche** : `feat/refonte-accueil` depuis `origin/refonte/forge`. La PR vise `refonte/forge`, jamais `main` (WORKFLOW.md §9). Aucun push sans validation locale du mainteneur.
- **Langue** : commentaires, textes d'interface, commits et documentation en français. Identifiants en anglais.
- **Commits** : préfixe `Web : …`, terminés par la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Commandes** : toutes les commandes npm se lancent depuis `riftarium/apps/web`. `npm run check` doit être vert avant chaque push.
- **Tokens disponibles** (`src/styles/tokens.css`) :
  - fonds `--bg`, `--bg-raised`, `--bg-sunken`, `--line` ;
  - sang `--blood`, `--blood-bright` (grands titres et graphismes seulement), `--blood-text` (accent du texte courant) ;
  - bronze `--bronze`, `--bronze-light` ;
  - texte `--ink`, `--ink-muted` ;
  - polices `--font-display` (Cinzel), `--font-label` (Barlow Condensed), `--font-body` (Barlow) ;
  - espacements `--space-1` à `--space-7`, forme `--cut`, `--radius-card`, ombre `--shadow-deep`, durées `--t-fast` / `--t-base`.
- **Composants existants** : `RiftButton` (`variant` primary / secondary / ghost, `size` sm / md, `to` / `href`). `Icon` est global : l'enregistrer dans les tests avec `global: { components: { Icon } }`.
- **Styles** : chaque nouveau composant a son `<style scoped>`. Rien n'est ajouté à `src/assets/main.css`. Cette PR en supprime la tranche de l'accueil.
- **Effets** (spec §3.4) : seulement l'entrée du splash et le défilement lent du mur. Les deux sont coupés par `prefers-reduced-motion` : le mur devient statique. Pas de `v-tilt` ni de `v-reveal` dans les nouveaux composants.
- **Images** : toujours redimensionnées par le CDN (`cardThumb(url, w)` de `src/api.js`, `bannerUrl` de `src/banners.js`). Le mur charge ses vignettes en `loading="lazy"`.
- **Crédit Riot** : tout visuel officiel plein cadre porte la mention « Visuel officiel Riftbound — © Riot Games ».
- **Écart à la spec (§5 PR 2)** : `RiftChip` et `RiftEmpty` n'ont pas d'usage sur l'accueil et sont reportés à la PR 3 avec leur premier consommateur. La spec est mise à jour en tâche 6.

## Review Focus

- **Membre sans données** (aucun deck, aucune carte, aucun match) : chaque bloc personnel affiche une invitation à agir, jamais une valeur vide, « 0 / 0 » ou « undefined ». Testé en tâche 2 et en tâche 5.
- **Une API en échec pour un membre** (par exemple `/api/play/history` en 500) : les deux autres blocs s'affichent quand même. Le bloc en échec retombe sur sa version visiteur. Testé en tâche 2 et en tâche 5.
- **Aucun set ou aucune carte renvoyés** (base vide en dev, API hors ligne) : le mur ne s'affiche pas, et l'accueil reste lisible. Testé en tâche 4.
- **Déconnexion pendant que l'accueil est ouvert** : les blocs repassent en version visiteur sans recharger la page. Testé en tâche 5.
- **Réduction des animations** : le mur ne défile pas et le splash n'a pas d'animation d'entrée. Testé en tâche 4 (classe `static` du mur).

---

## Carte des fichiers

| Fichier | Rôle |
| --- | --- |
| `src/ui/RiftPanel.vue` (+ spec) | bloc Forgé : angles coupés, filet de bronze, intertitre Cinzel suivi d'un filet dégradé (slot `title`, prop `title`) |
| `src/ui/RiftSkeleton.vue` (+ spec) | squelette de chargement (lignes ou bloc) |
| `src/home/homeData.js` (+ spec) | fonctions pures : choix du splash, dernier set, cartes du mur, résumé du membre |
| `src/home/HomeSplash.vue` (+ spec) | splash cinématique |
| `src/home/CardWall.vue` (+ spec) | mur de cartes du dernier set |
| `src/home/HomeBlocks.vue` (+ spec) | trois blocs Forgés, visiteur ou membre |
| `src/views/HomeView.vue` (+ spec réécrite) | composition des trois sections |
| supprimés | `src/components/CardRiver.vue`, `src/components/CardRiver.spec.js` |
| `src/assets/main.css` | suppression des règles propres à l'ancien accueil |
| spec | §5 PR 2 mise à jour (RiftChip et RiftEmpty reportés) |

---

### Task 1 : `RiftPanel` et `RiftSkeleton`

**Files :**
- Create : `src/ui/RiftPanel.vue`, `src/ui/RiftPanel.spec.js`, `src/ui/RiftSkeleton.vue`, `src/ui/RiftSkeleton.spec.js`

**Interfaces :**
- Produces : `<RiftPanel :title? tag="section" :accent?>`, avec un slot `title` (qui remplace la prop) et un slot par défaut. Racine `<component :is="tag" class="rift-panel">`. Si un titre est donné (par la prop ou le slot), un `<h2 class="rift-panel-title">` est rendu, et la racine reçoit `aria-labelledby` vers ce titre. `accent` est une couleur CSS optionnelle (par défaut `var(--blood)`) posée en variable `--panel-accent` pour le liseré supérieur.
- Produces : `<RiftSkeleton :lines="3" :block?="false" />`. Avec `block`, un rectangle plein d'une hauteur de 120 px ; sinon, `lines` lignes de texte dont la dernière fait 60 % de large. `aria-hidden="true"` sur la racine.

- [ ] **Step 1 : écrire les tests**

`src/ui/RiftPanel.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftPanel from "./RiftPanel.vue"

describe("RiftPanel", () => {
  it("rend une section titrée, reliée à son titre", () => {
    const wrapper = mount(RiftPanel, { props: { title: "Ma collection" }, slots: { default: "<p>contenu</p>" } })
    const root = wrapper.get(".rift-panel")
    expect(root.element.tagName).toBe("SECTION")
    const title = wrapper.get("h2.rift-panel-title")
    expect(title.text()).toBe("Ma collection")
    expect(root.attributes("aria-labelledby")).toBe(title.attributes("id"))
    expect(wrapper.text()).toContain("contenu")
  })

  it("accepte un titre riche par slot et une autre balise", () => {
    const wrapper = mount(RiftPanel, { props: { tag: "article" }, slots: { title: "<em>Decks</em>" } })
    expect(wrapper.element.tagName).toBe("ARTICLE")
    expect(wrapper.get("h2.rift-panel-title em").text()).toBe("Decks")
  })

  it("sans titre : pas de h2 ni d'aria-labelledby", () => {
    const wrapper = mount(RiftPanel, { slots: { default: "x" } })
    expect(wrapper.find("h2").exists()).toBe(false)
    expect(wrapper.attributes("aria-labelledby")).toBeUndefined()
  })

  it("pose la couleur d'accent en variable CSS", () => {
    const wrapper = mount(RiftPanel, { props: { accent: "var(--mind)" } })
    expect(wrapper.attributes("style")).toContain("--panel-accent: var(--mind)")
  })
})
```

`src/ui/RiftSkeleton.spec.js` :

```js
import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftSkeleton from "./RiftSkeleton.vue"

describe("RiftSkeleton", () => {
  it("rend le nombre de lignes demandé, masqué aux lecteurs d'écran", () => {
    const wrapper = mount(RiftSkeleton, { props: { lines: 4 } })
    expect(wrapper.attributes("aria-hidden")).toBe("true")
    expect(wrapper.findAll(".rift-skeleton-line")).toHaveLength(4)
  })

  it("en mode bloc, un seul rectangle", () => {
    const wrapper = mount(RiftSkeleton, { props: { block: true } })
    expect(wrapper.findAll(".rift-skeleton-line")).toHaveLength(0)
    expect(wrapper.find(".rift-skeleton-block").exists()).toBe(true)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/ui/RiftPanel.spec.js src/ui/RiftSkeleton.spec.js`
Expected : FAIL (modules introuvables).

- [ ] **Step 3 : écrire `src/ui/RiftPanel.vue`**

```vue
<script setup>
import { computed, useId, useSlots } from "vue"

/* Bloc de la Forge : plaque à angles coupés, filet de bronze, liseré d'accent en
   haut, intertitre Cinzel prolongé d'un filet qui s'efface. */
const props = defineProps({
  title: { type: String, default: "" },
  tag: { type: String, default: "section" },
  accent: { type: String, default: "" }
})
const slots = useSlots()
const titleId = `${useId()}-title`
const hasTitle = computed(() => Boolean(props.title || slots.title))
const style = computed(() => (props.accent ? { "--panel-accent": props.accent } : undefined))
</script>

<template>
  <component :is="tag" class="rift-panel" :style="style" :aria-labelledby="hasTitle ? titleId : undefined">
    <h2 v-if="hasTitle" :id="titleId" class="rift-panel-title">
      <slot name="title">{{ title }}</slot>
    </h2>
    <slot />
  </component>
</template>

<style scoped>
.rift-panel {
  --panel-accent: var(--blood);
  position: relative;
  padding: var(--space-5);
  background: var(--bg-raised);
  border-top: 2px solid var(--panel-accent);
  box-shadow: inset 0 0 0 1px var(--line);
  clip-path: polygon(
    var(--cut) 0,
    100% 0,
    100% calc(100% - var(--cut)),
    calc(100% - var(--cut)) 100%,
    0 100%,
    0 var(--cut)
  );
}
.rift-panel-title {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  margin: 0 0 var(--space-3);
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.rift-panel-title::after {
  content: "";
  flex: 1;
  height: 1px;
  background: linear-gradient(90deg, var(--bronze), transparent);
}
</style>
```

- [ ] **Step 4 : écrire `src/ui/RiftSkeleton.vue`**

```vue
<script setup>
/* Squelette de chargement : réserve la place du contenu à venir, sans texte lu. */
defineProps({
  lines: { type: Number, default: 3 },
  block: { type: Boolean, default: false }
})
</script>

<template>
  <div class="rift-skeleton" aria-hidden="true">
    <div v-if="block" class="rift-skeleton-block"></div>
    <template v-else>
      <div v-for="n in lines" :key="n" class="rift-skeleton-line" :class="{ last: n === lines }"></div>
    </template>
  </div>
</template>

<style scoped>
.rift-skeleton {
  display: grid;
  gap: var(--space-2);
}
.rift-skeleton-line,
.rift-skeleton-block {
  background: linear-gradient(90deg, var(--bg-sunken) 0%, #221a16 50%, var(--bg-sunken) 100%);
  background-size: 200% 100%;
  animation: rift-shimmer 1.4s linear infinite;
}
.rift-skeleton-line {
  height: 12px;
}
.rift-skeleton-line.last {
  width: 60%;
}
.rift-skeleton-block {
  height: 120px;
}
@keyframes rift-shimmer {
  to {
    background-position: -200% 0;
  }
}
</style>
```

- [ ] **Step 5 : vérifier le succès**

Run : `npx vitest run src/ui/RiftPanel.spec.js src/ui/RiftSkeleton.spec.js`
Expected : PASS (6 tests).

- [ ] **Step 6 : commit**

```bash
git add src/ui/RiftPanel.* src/ui/RiftSkeleton.*
git commit -m "Web : composants RiftPanel et RiftSkeleton

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 : données de l'accueil (`homeData.js`)

**Files :**
- Create : `src/home/homeData.js`, `src/home/homeData.spec.js`

**Interfaces :**
- Consumes : `api(path, { signal })` (`src/api.js`), `BANNERS` (`src/banners.js`).
- Produces :
  - `SPLASH_KEYS = ["home", "cards", "decks", "community"]` ;
  - `pickSplash(random = Math.random) → string` : une URL de `BANNERS` parmi `SPLASH_KEYS` ;
  - `latestSet(sets) → set | null` : le set au plus grand `published_on`, à égalité le dernier de la liste ; les sets sans date sont ignorés s'il en existe un daté ;
  - `wallCards(items, limit = 36) → card[]` : seulement les cartes avec `image_url` et non paysage, au plus `limit` ;
  - `completion(overall) → { owned, total, percent } | null` : `null` si `overall` est absent ou si `total` vaut 0 ; `percent` est arrondi à l'entier ;
  - `outcomeLabel(outcome) → string` : `"win"` → « Victoire », `"loss"` → « Défaite », `"draw"` → « Égalité », sinon « Partie » ;
  - `loadMemberSummary({ signal }) → Promise<{ collection, deck, match }>` : chaque champ vaut `null` s'il n'y a pas de donnée ou si son appel échoue. Les appels partent en parallèle (`Promise.allSettled`) : `GET /api/collection/sets` (`overall`), `GET /api/decks/mine` (premier élément, déjà trié par date de mise à jour décroissante), `GET /api/play/history?size=1` (premier élément).

- [ ] **Step 1 : vérifier les valeurs réelles de `outcome`**

Run : `grep -n "def _outcome" -A15 ../api/app/routers/play.py`
Si les valeurs renvoyées ne sont pas exactement `win`, `loss` et `draw`, adapter **les trois clés** de `OUTCOMES` (Step 3) et du test (Step 2) aux valeurs réelles, et le noter dans le rapport.

- [ ] **Step 2 : écrire le test**

`src/home/homeData.spec.js` :

```js
import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", () => ({ api: vi.fn() }))

const { api } = await import("../api.js")
const { BANNERS } = await import("../banners.js")
const { completion, latestSet, loadMemberSummary, outcomeLabel, pickSplash, SPLASH_KEYS, wallCards } = await import(
  "./homeData.js"
)

afterEach(() => vi.clearAllMocks())

describe("pickSplash", () => {
  it("choisit un visuel parmi les clés retenues", () => {
    expect(pickSplash(() => 0)).toBe(BANNERS[SPLASH_KEYS[0]])
    expect(pickSplash(() => 0.999)).toBe(BANNERS[SPLASH_KEYS[SPLASH_KEYS.length - 1]])
  })
})

describe("latestSet", () => {
  it("prend la date de publication la plus récente", () => {
    const sets = [
      { set_id: "ogn", published_on: "2025-10-31" },
      { set_id: "sfd", published_on: "2026-02-13" },
      { set_id: "x", published_on: null }
    ]
    expect(latestSet(sets).set_id).toBe("sfd")
  })
  it("renvoie null pour une liste vide ou absente", () => {
    expect(latestSet([])).toBeNull()
    expect(latestSet(undefined)).toBeNull()
  })
  it("sans aucune date, prend le dernier de la liste", () => {
    expect(latestSet([{ set_id: "a" }, { set_id: "b" }]).set_id).toBe("b")
  })
})

describe("wallCards", () => {
  it("écarte les cartes sans visuel et les cartes paysage, et plafonne", () => {
    const items = [
      { id: 1, image_url: "a" },
      { id: 2, image_url: null },
      { id: 3, image_url: "c", orientation: "landscape" },
      { id: 4, image_url: "d" }
    ]
    expect(wallCards(items).map((c) => c.id)).toEqual([1, 4])
    expect(wallCards(items, 1).map((c) => c.id)).toEqual([1])
    expect(wallCards(undefined)).toEqual([])
  })
})

describe("completion", () => {
  it("calcule le pourcentage arrondi", () => {
    expect(completion({ owned: 1, total: 3 })).toEqual({ owned: 1, total: 3, percent: 33 })
  })
  it("renvoie null sans total", () => {
    expect(completion({ owned: 0, total: 0 })).toBeNull()
    expect(completion(null)).toBeNull()
  })
})

describe("outcomeLabel", () => {
  it.each([
    ["win", "Victoire"],
    ["loss", "Défaite"],
    ["draw", "Égalité"],
    [null, "Partie"]
  ])("%s → %s", (outcome, label) => {
    expect(outcomeLabel(outcome)).toBe(label)
  })
})

describe("loadMemberSummary", () => {
  it("rassemble collection, dernier deck et dernier match", async () => {
    api.mockImplementation(async (path) => {
      if (path === "/api/collection/sets") return { sets: [], overall: { owned: 120, total: 300 } }
      if (path === "/api/decks/mine") return [{ id: 9, name: "Lee Sin Tempo" }, { id: 3, name: "Ancien" }]
      if (path === "/api/play/history?size=1") return { items: [{ match_id: 4, outcome: "win" }] }
      throw new Error(path)
    })
    const summary = await loadMemberSummary()
    expect(summary.collection).toEqual({ owned: 120, total: 300, percent: 40 })
    expect(summary.deck).toMatchObject({ id: 9, name: "Lee Sin Tempo" })
    expect(summary.match).toMatchObject({ match_id: 4 })
  })

  it("un appel en échec ou vide donne null sans masquer les autres", async () => {
    api.mockImplementation(async (path) => {
      if (path === "/api/collection/sets") return { sets: [], overall: { owned: 0, total: 0 } }
      if (path === "/api/decks/mine") return []
      throw new Error("500")
    })
    expect(await loadMemberSummary()).toEqual({ collection: null, deck: null, match: null })
  })

  it("transmet le signal d'annulation", async () => {
    api.mockResolvedValue({})
    const controller = new AbortController()
    await loadMemberSummary({ signal: controller.signal })
    for (const call of api.mock.calls) expect(call[1]).toEqual({ signal: controller.signal })
  })
})
```

- [ ] **Step 3 : vérifier l'échec**

Run : `npx vitest run src/home/homeData.spec.js`
Expected : FAIL (`./homeData.js` introuvable).

- [ ] **Step 4 : écrire `src/home/homeData.js`**

```js
import { api } from "../api.js"
import { BANNERS } from "../banners.js"

/* Données de l'accueil : fonctions pures autour des endpoints existants, testables
   sans composant. Aucun endpoint dédié à l'accueil. */

/* Illustrations assez cinématiques pour ouvrir le site (paysages larges, personnages). */
export const SPLASH_KEYS = ["home", "cards", "decks", "community"]

export function pickSplash(random = Math.random) {
  const index = Math.min(SPLASH_KEYS.length - 1, Math.floor(random() * SPLASH_KEYS.length))
  return BANNERS[SPLASH_KEYS[index]]
}

/* Set le plus récent par date de publication ; sans aucune date, le dernier de la liste
   (l'API les renvoie déjà dans l'ordre de publication). */
export function latestSet(sets) {
  if (!sets?.length) return null
  const dated = sets.filter((set) => set.published_on)
  if (!dated.length) return sets[sets.length - 1]
  return dated.reduce((best, set) => (set.published_on >= best.published_on ? set : best))
}

/* Cartes du mur : jamais de carte couchée (champs de bataille), elle casserait la grille. */
export function wallCards(items, limit = 36) {
  return (items ?? []).filter((card) => card.image_url && card.orientation !== "landscape").slice(0, limit)
}

export function completion(overall) {
  if (!overall?.total) return null
  return { owned: overall.owned, total: overall.total, percent: Math.round((overall.owned / overall.total) * 100) }
}

const OUTCOMES = { win: "Victoire", loss: "Défaite", draw: "Égalité" }

export function outcomeLabel(outcome) {
  return OUTCOMES[outcome] ?? "Partie"
}

/* Résumé d'un membre connecté. allSettled : un endpoint en panne n'efface pas les deux autres. */
export async function loadMemberSummary({ signal } = {}) {
  const [sets, decks, history] = await Promise.allSettled([
    api("/api/collection/sets", { signal }),
    api("/api/decks/mine", { signal }),
    api("/api/play/history?size=1", { signal })
  ])
  const value = (result) => (result.status === "fulfilled" ? result.value : null)
  return {
    collection: completion(value(sets)?.overall),
    deck: value(decks)?.[0] ?? null,
    match: value(history)?.items?.[0] ?? null
  }
}
```

- [ ] **Step 5 : vérifier le succès**

Run : `npx vitest run src/home/homeData.spec.js`
Expected : PASS.

- [ ] **Step 6 : commit**

```bash
git add src/home/homeData.js src/home/homeData.spec.js
git commit -m "Web : données de l'accueil (splash, dernier set, résumé du membre)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : `HomeSplash`

**Files :**
- Create : `src/home/HomeSplash.vue`, `src/home/HomeSplash.spec.js`

**Interfaces :**
- Consumes : `RiftButton`.
- Produces : `<HomeSplash :art="url" :card-count? :set-count? />`. Une `<section class="splash">` contient un `h1`, deux boutons (« Voir les cartes » vers `/cartes`, « Lire les règles » vers `/regles`), une ligne de chiffres seulement si les deux nombres sont connus, et le crédit Riot. Au montage, une balise `<link rel="preload" as="image" fetchpriority="high">` vers `art` est ajoutée dans `<head>`, puis retirée au démontage.

- [ ] **Step 1 : écrire le test**

`src/home/HomeSplash.spec.js` :

```js
import { mount, RouterLinkStub } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import HomeSplash from "./HomeSplash.vue"

const ART = "https://cmsassets.rgpub.io/sanity/images/x.jpg?w=1920"
const mountSplash = (props = {}) =>
  mount(HomeSplash, { props: { art: ART, ...props }, global: { stubs: { RouterLink: RouterLinkStub } } })

describe("HomeSplash", () => {
  afterEach(() => {
    document.head.querySelectorAll("link[rel=preload]").forEach((link) => link.remove())
  })

  it("titre, deux actions et crédit Riot", () => {
    const wrapper = mountSplash()
    expect(wrapper.get("h1").text()).toContain("Domine le Rift")
    expect(wrapper.findAllComponents(RouterLinkStub).map((l) => l.props("to"))).toEqual(["/cartes", "/regles"])
    expect(wrapper.text()).toContain("© Riot Games")
    expect(wrapper.get(".splash").attributes("style")).toContain(ART)
  })

  it("n'affiche les chiffres que s'ils sont connus", async () => {
    const wrapper = mountSplash()
    expect(wrapper.find(".splash-stats").exists()).toBe(false)
    await wrapper.setProps({ cardCount: 1024, setCount: 3 })
    expect(wrapper.get(".splash-stats").text()).toContain("1 024")
  })

  it("précharge l'illustration le temps de sa présence", () => {
    const wrapper = mountSplash()
    const link = document.head.querySelector("link[rel=preload][as=image]")
    expect(link.getAttribute("href")).toBe(ART)
    wrapper.unmount()
    expect(document.head.querySelector("link[rel=preload][as=image]")).toBeNull()
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/home/HomeSplash.spec.js`
Expected : FAIL.

- [ ] **Step 3 : écrire `src/home/HomeSplash.vue`**

```vue
<script setup>
import { computed, onBeforeUnmount, onMounted } from "vue"
import RiftButton from "../ui/RiftButton.vue"

/* Ouverture du site : une illustration officielle plein cadre, fondue dans le noir de
   la forge, le titre gravé dessus. */
const props = defineProps({
  art: { type: String, required: true },
  cardCount: { type: Number, default: null },
  setCount: { type: Number, default: null }
})

const style = computed(() => ({ "--splash": `url("${props.art}")` }))
const showStats = computed(() => props.cardCount !== null && props.setCount !== null)
const format = (n) => n.toLocaleString("fr-FR")

/* Un fond CSS n'est découvert qu'au premier rendu, trop tard pour le LCP : préchargement
   explicite, retiré au démontage pour ne pas laisser de balise orpheline. */
let preload = null
onMounted(() => {
  preload = document.createElement("link")
  preload.setAttribute("rel", "preload")
  preload.setAttribute("as", "image")
  preload.setAttribute("href", props.art)
  preload.setAttribute("fetchpriority", "high")
  document.head.appendChild(preload)
})
onBeforeUnmount(() => {
  preload?.remove()
  preload = null
})
</script>

<template>
  <section class="splash" :style="style">
    <div class="splash-copy">
      <p class="splash-kicker">Le compagnon Riftbound</p>
      <h1 class="splash-title">Forge ton <em>deck.</em><br />Domine le Rift.</h1>
      <p class="splash-lead">Cartes, collection, deck builder et règles officielles, en français.</p>
      <div class="splash-actions">
        <RiftButton to="/cartes">Voir les cartes</RiftButton>
        <RiftButton to="/regles" variant="secondary">Lire les règles</RiftButton>
      </div>
      <p v-if="showStats" class="splash-stats">
        <b>{{ format(cardCount) }}</b> cartes · <b>{{ format(setCount) }}</b> sets
      </p>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>
</template>

<style scoped>
.splash {
  position: relative;
  display: flex;
  align-items: flex-end;
  min-height: min(78dvh, 720px);
  padding: var(--space-7) var(--space-6);
  background:
    linear-gradient(90deg, var(--bg) 12%, rgba(13, 13, 15, 0.72) 48%, rgba(13, 13, 15, 0.1) 100%),
    linear-gradient(0deg, var(--bg) 0%, transparent 45%),
    var(--splash) center 30% / cover no-repeat;
  overflow: hidden;
}
.splash-copy {
  max-width: 560px;
  animation: splash-in 700ms ease-out both;
}
.splash-kicker {
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.splash-title {
  margin: var(--space-2) 0 var(--space-4);
  font-family: var(--font-display);
  font-size: clamp(36px, 6vw, 64px);
  font-weight: 900;
  line-height: 1.02;
  text-transform: uppercase;
}
.splash-title em {
  font-style: normal;
  color: var(--blood-bright);
}
.splash-lead {
  max-width: 440px;
  margin-bottom: var(--space-5);
  font-size: 17px;
  color: #cfc6b8;
}
.splash-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}
.splash-stats {
  margin-top: var(--space-5);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.splash-stats b {
  color: var(--bronze-light);
  font-family: var(--font-display);
  font-size: 18px;
}
.splash-credit {
  position: absolute;
  right: var(--space-4);
  bottom: var(--space-2);
  font-size: 11px;
  color: var(--ink-muted);
}
@keyframes splash-in {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
}
@media (max-width: 767px) {
  .splash {
    min-height: 70dvh;
    padding: var(--space-6) var(--space-4) var(--space-7);
    background:
      linear-gradient(0deg, var(--bg) 18%, rgba(13, 13, 15, 0.55) 70%, rgba(13, 13, 15, 0.3) 100%),
      var(--splash) center / cover no-repeat;
  }
}
</style>
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/home/HomeSplash.spec.js`
Expected : PASS (3 tests).

- [ ] **Step 5 : commit**

```bash
git add src/home/HomeSplash.*
git commit -m "Web : splash cinématique de l'accueil

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : `CardWall`

**Files :**
- Create : `src/home/CardWall.vue`, `src/home/CardWall.spec.js`

**Interfaces :**
- Consumes : `api`, `cardThumb` (`src/api.js`) ; `latestSet`, `wallCards` (tâche 2) ; `RiftButton`.
- Produces : `<CardWall />`. Au montage, appelle `GET /api/sets`, puis `GET /api/cards?set_id=<id>&sort=random&size=48` pour le dernier set. Rien n'est rendu tant que le mur n'a pas au moins 12 cartes (en chargement, en erreur ou si les données sont vides). Le mur est une `<section class="wall">` avec une mosaïque `aria-hidden`, et la liste rendue deux fois pour la boucle de défilement. Le titre mentionne le nom du set, et le bouton mène à `/cartes?set=<id>`. La classe `static` est posée si `prefers-reduced-motion: reduce`.

- [ ] **Step 1 : écrire le test**

`src/home/CardWall.spec.js` :

```js
import { flushPromises, mount, RouterLinkStub } from "@vue/test-utils"
import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", () => ({ api: vi.fn(), cardThumb: (url, w) => `${url}?w=${w}` }))
const { api } = await import("../api.js")
const { default: CardWall } = await import("./CardWall.vue")

const cards = (n) => Array.from({ length: n }, (_, i) => ({ id: `c${i}`, name: `C${i}`, image_url: `img${i}` }))
const SETS = [
  { set_id: "ogn", name: "Origins", published_on: "2025-10-31" },
  { set_id: "sfd", name: "Spiritforged", published_on: "2026-02-13" }
]

function mockApi(items) {
  api.mockImplementation(async (path) => {
    if (path === "/api/sets") return SETS
    if (path.startsWith("/api/cards")) return { items }
    throw new Error(path)
  })
}

const original = window.matchMedia
function reducedMotion(on) {
  window.matchMedia = (query) => ({
    matches: on && query.includes("prefers-reduced-motion"),
    addEventListener() {},
    removeEventListener() {}
  })
}

async function mountWall() {
  const wrapper = mount(CardWall, { global: { stubs: { RouterLink: RouterLinkStub } } })
  await flushPromises()
  return wrapper
}

describe("CardWall", () => {
  afterEach(() => {
    vi.clearAllMocks()
    window.matchMedia = original
  })

  it("montre le dernier set, en boucle, avec un lien vers ses cartes", async () => {
    reducedMotion(false)
    mockApi(cards(20))
    const wrapper = await mountWall()
    expect(api).toHaveBeenCalledWith("/api/cards?set_id=sfd&sort=random&size=48")
    expect(wrapper.text()).toContain("Spiritforged")
    expect(wrapper.getComponent(RouterLinkStub).props("to")).toBe("/cartes?set=sfd")
    expect(wrapper.findAll(".wall-track img")).toHaveLength(40)
    expect(wrapper.get(".wall-mosaic").attributes("aria-hidden")).toBe("true")
    expect(wrapper.get(".wall").classes()).not.toContain("static")
  })

  it("devient statique si l'utilisateur réduit les animations", async () => {
    reducedMotion(true)
    mockApi(cards(20))
    const wrapper = await mountWall()
    expect(wrapper.get(".wall").classes()).toContain("static")
  })

  it("ne s'affiche pas avec trop peu de cartes ou une API en panne", async () => {
    reducedMotion(false)
    mockApi(cards(5))
    expect((await mountWall()).find(".wall").exists()).toBe(false)
    api.mockRejectedValue(new Error("hors ligne"))
    expect((await mountWall()).find(".wall").exists()).toBe(false)
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/home/CardWall.spec.js`
Expected : FAIL.

- [ ] **Step 3 : écrire `src/home/CardWall.vue`**

```vue
<script setup>
import { onMounted, ref } from "vue"
import { api, cardThumb } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import { latestSet, wallCards } from "./homeData.js"

/* Mur de cartes : le dernier set en mosaïque inclinée qui défile lentement dans la
   pénombre. Décoratif (aria-hidden) ; le titre et le bouton portent le sens. */
const MIN_CARDS = 12

const set = ref(null)
const items = ref([])
const reduced =
  typeof window !== "undefined" && window.matchMedia
    ? window.matchMedia("(prefers-reduced-motion: reduce)").matches
    : false

onMounted(async () => {
  try {
    const latest = latestSet(await api("/api/sets"))
    if (!latest) return
    const page = await api(`/api/cards?set_id=${encodeURIComponent(latest.set_id)}&sort=random&size=48`)
    const picked = wallCards(page.items)
    if (picked.length < MIN_CARDS) return
    set.value = latest
    items.value = picked
  } catch {
    /* pas de mur plutôt qu'un trou : l'accueil reste lisible sans lui */
  }
})
</script>

<template>
  <section v-if="set" class="wall" :class="{ static: reduced }">
    <div class="wall-mosaic" aria-hidden="true">
      <div class="wall-track">
        <img
          v-for="(card, i) in [...items, ...items]"
          :key="`${card.id}-${i}`"
          :src="cardThumb(card.image_url, 200)"
          alt=""
          loading="lazy"
          decoding="async"
        />
      </div>
    </div>
    <div class="wall-veil"></div>
    <div class="wall-copy">
      <p class="wall-kicker">Dernier set · {{ set.name }}</p>
      <h2 class="wall-title">Tout le <em>Rift</em><br />sur une table.</h2>
      <RiftButton :to="`/cartes?set=${set.set_id}`">Explorer {{ set.name }}</RiftButton>
    </div>
  </section>
</template>

<style scoped>
.wall {
  position: relative;
  height: 460px;
  overflow: hidden;
  border-top: 1px solid var(--line);
  border-bottom: 1px solid var(--line);
}
.wall-mosaic {
  position: absolute;
  inset: -120px -80px;
  transform: rotate(-12deg);
  opacity: 0.5;
}
.wall-track {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: var(--space-3);
  animation: wall-scroll 120s linear infinite;
}
.wall-track img {
  width: 100%;
  aspect-ratio: 0.716;
  object-fit: cover;
  border-radius: 6px;
}
.wall.static .wall-track {
  animation: none;
}
.wall-veil {
  position: absolute;
  inset: 0;
  background: radial-gradient(520px 260px at 50% 55%, rgba(13, 13, 15, 0.94), rgba(13, 13, 15, 0.55) 70%, rgba(13, 13, 15, 0.25));
}
.wall-copy {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  padding: var(--space-4);
  text-align: center;
}
.wall-kicker {
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.22em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.wall-title {
  margin: var(--space-2) 0 var(--space-5);
  font-family: var(--font-display);
  font-size: clamp(30px, 5vw, 52px);
  font-weight: 900;
  line-height: 1.05;
  text-transform: uppercase;
}
.wall-title em {
  font-style: normal;
  color: var(--blood-bright);
}
@keyframes wall-scroll {
  to {
    transform: translateY(-50%);
  }
}
</style>
```

- [ ] **Step 4 : vérifier le succès**

Run : `npx vitest run src/home/CardWall.spec.js`
Expected : PASS (3 tests).

- [ ] **Step 5 : commit**

```bash
git add src/home/CardWall.*
git commit -m "Web : mur de cartes du dernier set sur l'accueil

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : `HomeBlocks`

**Files :**
- Create : `src/home/HomeBlocks.vue`, `src/home/HomeBlocks.spec.js`

**Interfaces :**
- Consumes : `session` (`src/api.js`) ; `loadMemberSummary`, `outcomeLabel` (tâche 2) ; `RiftPanel`, `RiftSkeleton` (tâche 1) ; `RiftButton`.
- Produces : `<HomeBlocks />`. Une grille `.blocks` de trois `RiftPanel` :
  - **Visiteur**, ou membre dont le chargement n'a rien donné pour un bloc :
    - « Decks » (accent `var(--fury)`) : texte + boutons « Construire un deck » (`/decks`) et « Decks de la communauté » (`/communaute`) ;
    - « Collection » (accent `var(--body)`) : texte + « Suivre ma collection » (`/collection`) ;
    - « Règles » (accent `var(--order)`) : texte + « Ouvrir les règles » (`/regles`).
  - **Membre** :
    - « Collection » : « `<percent>` % » en grand + « `<owned>` / `<total>` cartes » + « Voir ma collection » (`/collection`) ;
    - « Mon dernier deck » : nom du deck + « `<card_count>` cartes » + « Reprendre » (`/decks/<id>`) ;
    - « Dernier match » : `outcomeLabel(outcome)` en grand + « contre `<opponent.handle>` » s'il est connu + « Historique » (`/historique`).

    Un bloc dont la donnée vaut `null` affiche sa version visiteur. Pour le troisième bloc, sans match, c'est le bloc « Règles ».
  - **Pendant le chargement d'un membre**, chaque bloc montre un `RiftSkeleton` sous son titre.
  - **Changement de session** : la session est surveillée. Une déconnexion revient immédiatement aux blocs visiteur. Une connexion relance le chargement et annule le précédent (`AbortController`).

- [ ] **Step 1 : vérifier le champ joueur adverse**

Run : `grep -n "def _user_payload" -A8 ../api/app/routers/play.py`
Si le pseudo n'est pas dans `opponent.handle`, adapter le template (Step 4) et le test (Step 2) au vrai nom du champ, et le noter dans le rapport.

- [ ] **Step 2 : écrire le test**

`src/home/HomeBlocks.spec.js` :

```js
import { flushPromises, mount, RouterLinkStub } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("./homeData.js", async (importOriginal) => ({ ...(await importOriginal()), loadMemberSummary: vi.fn() }))
const { loadMemberSummary } = await import("./homeData.js")
const { session } = await import("../api.js")
const { default: HomeBlocks } = await import("./HomeBlocks.vue")

const mountBlocks = () => mount(HomeBlocks, { global: { stubs: { RouterLink: RouterLinkStub } } })
const titles = (wrapper) => wrapper.findAll(".rift-panel-title").map((t) => t.text())
const links = (wrapper) => wrapper.findAllComponents(RouterLinkStub).map((l) => l.props("to"))

describe("HomeBlocks", () => {
  afterEach(() => {
    vi.clearAllMocks()
    session.token = null
  })

  it("visiteur : Decks, Collection, Règles, sans appel réseau", () => {
    const wrapper = mountBlocks()
    expect(titles(wrapper)).toEqual(["Decks", "Collection", "Règles"])
    expect(links(wrapper)).toEqual(["/decks", "/communaute", "/collection", "/regles"])
    expect(loadMemberSummary).not.toHaveBeenCalled()
  })

  it("membre : squelettes puis données personnelles", async () => {
    session.token = "1"
    let resolve
    loadMemberSummary.mockReturnValue(new Promise((r) => (resolve = r)))
    const wrapper = mountBlocks()
    await nextTick()
    expect(wrapper.findAll(".rift-skeleton")).toHaveLength(3)
    resolve({
      collection: { owned: 120, total: 300, percent: 40 },
      deck: { id: 9, name: "Lee Sin Tempo", card_count: 38 },
      match: { match_id: 4, outcome: "win", opponent: { handle: "Kaelis" } }
    })
    await flushPromises()
    expect(titles(wrapper)).toEqual(["Collection", "Mon dernier deck", "Dernier match"])
    expect(wrapper.text()).toContain("40 %")
    expect(wrapper.text()).toContain("120 / 300")
    expect(wrapper.text()).toContain("Lee Sin Tempo")
    expect(wrapper.text()).toContain("Victoire")
    expect(wrapper.text()).toContain("Kaelis")
    expect(links(wrapper)).toEqual(["/collection", "/decks/9", "/historique"])
  })

  it("membre sans données : chaque bloc retombe sur sa version visiteur", async () => {
    session.token = "1"
    loadMemberSummary.mockResolvedValue({ collection: null, deck: null, match: null })
    const wrapper = mountBlocks()
    await flushPromises()
    expect(titles(wrapper)).toEqual(["Collection", "Decks", "Règles"])
    expect(wrapper.text()).not.toMatch(/undefined|NaN|0 \/ 0/)
  })

  it("déconnexion : retour immédiat aux blocs visiteur", async () => {
    session.token = "1"
    loadMemberSummary.mockResolvedValue({
      collection: { owned: 1, total: 2, percent: 50 },
      deck: null,
      match: null
    })
    const wrapper = mountBlocks()
    await flushPromises()
    session.token = null
    await nextTick()
    expect(titles(wrapper)).toEqual(["Decks", "Collection", "Règles"])
  })
})
```

- [ ] **Step 3 : vérifier l'échec**

Run : `npx vitest run src/home/HomeBlocks.spec.js`
Expected : FAIL.

- [ ] **Step 4 : écrire `src/home/HomeBlocks.vue`**

```vue
<script setup>
import { computed, onBeforeUnmount, ref, watch } from "vue"
import { session } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import { loadMemberSummary, outcomeLabel } from "./homeData.js"

/* Trois blocs Forgés. Visiteur : les trois piliers du site. Membre : sa collection,
   son dernier deck, son dernier match ; un bloc sans donnée garde sa version visiteur. */
const summary = ref(null)
const loading = ref(false)
let controller = null

async function load() {
  controller?.abort()
  summary.value = null
  if (!session.token) {
    loading.value = false
    return
  }
  const current = new AbortController()
  controller = current
  loading.value = true
  const result = await loadMemberSummary({ signal: current.signal })
  if (controller !== current) return
  summary.value = result
  loading.value = false
}

watch(() => session.token, load, { immediate: true })
onBeforeUnmount(() => {
  controller?.abort()
  controller = null
})

const member = computed(() => Boolean(session.token))
const collection = computed(() => summary.value?.collection ?? null)
const deck = computed(() => summary.value?.deck ?? null)
const match = computed(() => summary.value?.match ?? null)
</script>

<template>
  <div class="blocks">
    <!-- Bloc 1 : Collection (membre) ou Decks (visiteur) -->
    <RiftPanel v-if="member" title="Collection" accent="var(--body)">
      <RiftSkeleton v-if="loading" />
      <template v-else-if="collection">
        <p class="block-figure">{{ collection.percent }} %</p>
        <p class="block-text">{{ collection.owned }} / {{ collection.total }} cartes du jeu</p>
        <RiftButton to="/collection" size="sm">Voir ma collection</RiftButton>
      </template>
      <template v-else>
        <p class="block-text">Notez vos exemplaires et suivez la complétion de chaque set.</p>
        <RiftButton to="/collection" size="sm">Suivre ma collection</RiftButton>
      </template>
    </RiftPanel>
    <RiftPanel v-else title="Decks" accent="var(--fury)">
      <p class="block-text">Le deck builder vérifie les règles officielles à mesure que vous construisez.</p>
      <div class="block-actions">
        <RiftButton to="/decks" size="sm">Construire un deck</RiftButton>
        <RiftButton to="/communaute" size="sm" variant="secondary">Decks de la communauté</RiftButton>
      </div>
    </RiftPanel>

    <!-- Bloc 2 : dernier deck (membre) ou Collection (visiteur) -->
    <RiftPanel v-if="member && (loading || deck)" title="Mon dernier deck" accent="var(--fury)">
      <RiftSkeleton v-if="loading" />
      <template v-else>
        <p class="block-name">{{ deck.name }}</p>
        <p class="block-text">{{ deck.card_count }} cartes</p>
        <RiftButton :to="`/decks/${deck.id}`" size="sm">Reprendre</RiftButton>
      </template>
    </RiftPanel>
    <RiftPanel v-else-if="member" title="Decks" accent="var(--fury)">
      <p class="block-text">Construisez votre premier deck : les règles sont vérifiées en direct.</p>
      <RiftButton to="/decks" size="sm">Construire un deck</RiftButton>
    </RiftPanel>
    <RiftPanel v-else title="Collection" accent="var(--body)">
      <p class="block-text">Quantité, état, langue : votre inventaire et ce qu'il vous manque, set par set.</p>
      <RiftButton to="/collection" size="sm">Suivre ma collection</RiftButton>
    </RiftPanel>

    <!-- Bloc 3 : dernier match (membre) ou Règles -->
    <RiftPanel v-if="member && (loading || match)" title="Dernier match" accent="var(--mind)">
      <RiftSkeleton v-if="loading" />
      <template v-else>
        <p class="block-figure">{{ outcomeLabel(match.outcome) }}</p>
        <p v-if="match.opponent?.handle" class="block-text">contre {{ match.opponent.handle }}</p>
        <RiftButton to="/historique" size="sm">Historique</RiftButton>
      </template>
    </RiftPanel>
    <RiftPanel v-else title="Règles" accent="var(--order)">
      <p class="block-text">Guide en chapitres, aide avancée et texte officiel, consultables même hors ligne.</p>
      <RiftButton to="/regles" size="sm">Ouvrir les règles</RiftButton>
    </RiftPanel>
  </div>
</template>

<style scoped>
.blocks {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: var(--space-5);
  padding: var(--space-7) var(--space-6);
}
.block-figure {
  font-family: var(--font-display);
  font-size: 34px;
  font-weight: 900;
  line-height: 1;
  color: var(--ink);
}
.block-name {
  font-family: var(--font-display);
  font-size: 20px;
  font-weight: 700;
  color: var(--ink);
}
.block-text {
  margin: var(--space-2) 0 var(--space-4);
  color: var(--ink-muted);
}
.block-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
@media (max-width: 767px) {
  .blocks {
    padding: var(--space-6) var(--space-4);
  }
}
</style>
```

- [ ] **Step 5 : vérifier le succès**

Run : `npx vitest run src/home/HomeBlocks.spec.js`
Expected : PASS (4 tests).

- [ ] **Step 6 : commit**

```bash
git add src/home/HomeBlocks.*
git commit -m "Web : blocs Forgés de l'accueil (visiteur et membre)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : nouvel accueil, nettoyage et documentation

**Files :**
- Modify : `src/views/HomeView.vue` (réécrit), `src/views/HomeView.spec.js` (réécrit)
- Delete : `src/components/CardRiver.vue`, `src/components/CardRiver.spec.js`
- Modify : `src/assets/main.css` (règles de l'ancien accueil)
- Modify : `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md` (§5 PR 2)

**Interfaces :**
- Consumes : `HomeSplash`, `CardWall`, `HomeBlocks`, `pickSplash` ; `api` (`/api/sets` et `/api/cards?size=1` pour les chiffres du splash, comme l'ancien accueil).
- Produces : l'accueil.

- [ ] **Step 1 : réécrire le test de vue**

Remplacer tout le contenu de `src/views/HomeView.spec.js` par :

```js
import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("../api.js", async (importOriginal) => ({ ...(await importOriginal()), api: vi.fn() }))
const { api } = await import("../api.js")
const { default: HomeView } = await import("./HomeView.vue")

const stubs = { HomeSplash: { props: ["art", "cardCount", "setCount"], template: "<div class='splash-stub' />" } }

describe("HomeView", () => {
  afterEach(() => vi.clearAllMocks())

  it("compose le splash, le mur et les blocs", async () => {
    api.mockImplementation(async (path) => {
      if (path === "/api/sets") return [{ set_id: "ogn" }, { set_id: "sfd" }]
      if (path === "/api/cards?size=1") return { total: 1024, items: [] }
      return { items: [] }
    })
    const wrapper = mount(HomeView, { global: { stubs: { ...stubs, CardWall: true, HomeBlocks: true } } })
    await flushPromises()
    const splash = wrapper.findComponent(stubs.HomeSplash)
    expect(splash.props("art")).toMatch(/^https:\/\//)
    expect(splash.props("cardCount")).toBe(1024)
    expect(splash.props("setCount")).toBe(2)
    expect(wrapper.findComponent({ name: "CardWall" }).exists()).toBe(true)
    expect(wrapper.findComponent({ name: "HomeBlocks" }).exists()).toBe(true)
  })

  it("chiffres inconnus si l'API ne répond pas", async () => {
    api.mockRejectedValue(new Error("hors ligne"))
    const wrapper = mount(HomeView, { global: { stubs: { ...stubs, CardWall: true, HomeBlocks: true } } })
    await flushPromises()
    const splash = wrapper.findComponent(stubs.HomeSplash)
    expect(splash.props("cardCount")).toBeNull()
    expect(splash.props("setCount")).toBeNull()
  })
})
```

- [ ] **Step 2 : vérifier l'échec**

Run : `npx vitest run src/views/HomeView.spec.js`
Expected : FAIL (l'ancien accueil ne compose pas `HomeSplash`).

- [ ] **Step 3 : réécrire `src/views/HomeView.vue`**

```vue
<script setup>
import { onMounted, ref } from "vue"
import { api } from "../api.js"
import CardWall from "../home/CardWall.vue"
import HomeBlocks from "../home/HomeBlocks.vue"
import { pickSplash } from "../home/homeData.js"
import HomeSplash from "../home/HomeSplash.vue"

/* Accueil Forge noxienne : splash cinématique, mur de cartes du dernier set, blocs
   Forgés (visiteur ou membre). L'illustration change à chaque visite. */
const art = pickSplash()
const cardCount = ref(null)
const setCount = ref(null)

onMounted(async () => {
  try {
    const [sets, cards] = await Promise.all([api("/api/sets"), api("/api/cards?size=1")])
    setCount.value = sets.length
    cardCount.value = cards.total
  } catch {
    /* les chiffres restent masqués : le splash se suffit à lui-même */
  }
})
</script>

<template>
  <HomeSplash :art="art" :card-count="cardCount" :set-count="setCount" />
  <CardWall />
  <HomeBlocks />
</template>
```

- [ ] **Step 4 : supprimer la rivière**

```bash
git rm -q src/components/CardRiver.vue src/components/CardRiver.spec.js
grep -rn "CardRiver" src
```

Expected : le `grep` ne renvoie rien.

- [ ] **Step 5 : supprimer les styles de l'ancien accueil dans `main.css`**

Les classes suivantes n'étaient utilisées que par l'ancien `HomeView.vue` et `CardRiver.vue` (vérifié avant rédaction du plan) : `hero-splash`, `hero-full`, `hero-beam`, `hero-grid`, `hero-cta`, `hero-stats`, `hero-stat`, `hero-fan`, `fan-card`, `fan-foil`, `hero-cue`, `h1-accent`, `hall`, `hall-river`, `hall-head`, `hall-cta`, `hall-art`, `hall-grid`, `hall-copy`, `hall-plaque`, `made-by`, et les classes de la rivière (`river`, `river-*`).

Revérifier d'abord : `grep -rnoE 'class="[^"]*\b(hero-[a-z]+|fan-[a-z]+|hall(-[a-z]+)?|made-by|h1-accent|river(-[a-z]+)?)\b' src --include=*.vue`. Seuls des fichiers hors de cette liste peuvent répondre ; `hero-copy`, `golden-rule*` et `splash-credit` sont utilisés ailleurs et **restent**. Puis supprimer de `src/assets/main.css` toutes les règles (racine et `@media`) dont le sélecteur commence par l'une des classes de la liste, en gardant les autres sélecteurs d'une liste groupée. Un `@media` vidé est supprimé.

Run : `grep -nE "\.(hero-(splash|full|beam|grid|cta|stats?|fan|cue)|fan-(card|foil)|h1-accent|hall\b|hall-|made-by|river)" src/assets/main.css`
Expected : rien.

- [ ] **Step 6 : mettre à jour la spec**

Dans `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md`, à la fin de la section « PR 2 : accueil », ajouter la puce :

```markdown
- Composants livrés : `RiftPanel` et `RiftSkeleton` ; `RiftChip` et `RiftEmpty`, sans
  usage sur l'accueil, arrivent en PR 3 avec leur premier consommateur. La rivière de
  cartes (`CardRiver`) est remplacée par le mur.
```

Et dans la ligne PR 1 du §5 (« `RiftPanel`, `RiftChip`, `RiftEmpty` et `RiftSkeleton` arrivent en PR 2 »), remplacer par « `RiftPanel` et `RiftSkeleton` arrivent en PR 2, `RiftChip`, `RiftEmpty`, `RiftStat` et `CardTile` en PR 3 » (adapter la fin de phrase pour ne pas répéter `RiftStat` et `CardTile`).

- [ ] **Step 7 : vérification complète**

Run : `npm run check`
Expected : vert.

- [ ] **Step 8 : commits**

```bash
git add -A src
git commit -m "Web : nouvel accueil (splash, mur de cartes, blocs) et retrait de l'ancien

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
cd ../../..
git add docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md
git commit -m "Docs : spec — composants livrés en PR 2

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
cd riftarium/apps/web
```

---

### Task 7 : validation par le mainteneur (contrôleur)

- [ ] **Step 1** : `docker restart riftarium-web` si les dépendances ont changé (ce n'est pas prévu), puis vérifier que `http://localhost:8888` répond.
- [ ] **Step 2** : transmettre au mainteneur la liste suivante et attendre son accord avant tout push :
  - **Visiteur** (déconnecté) : le splash (illustration, titre, deux boutons, chiffres, crédit Riot), le mur du dernier set qui défile, le bouton vers les cartes de ce set, et les trois blocs Decks, Collection et Règles.
  - **Membre** (connecté au compte local) : les blocs Collection (pourcentage), Mon dernier deck et Dernier match, ou leurs versions d'invitation sans données ; puis la déconnexion depuis le rail, qui fait revenir les blocs visiteur.
  - **Téléphone** (390 px) : le splash, le mur et les blocs empilés.
  - **Réduction des animations** (réglage du système) : le mur ne bouge plus.
- [ ] **Step 3** : après accord seulement, `git push -u origin feat/refonte-accueil`, puis `gh pr create --base refonte/forge --head feat/refonte-accueil --title "Web : refonte Forge noxienne — accueil (PR 2/8)"`, avec un résumé, les vérifications et la ligne « 🤖 Generated with [Claude Code](https://claude.com/claude-code) ».
