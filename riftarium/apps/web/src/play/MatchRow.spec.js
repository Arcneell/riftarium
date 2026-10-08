import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import MatchRow from "./MatchRow.vue"

const item = {
  match_id: 31,
  mode: "match",
  status: "confirmed",
  played_at: "2026-08-12T19:30:00Z",
  opponent: { handle: "nova", avatar_url: "https://cdn.example/nova.png" },
  my_legend: { id: "leg-1", name: "Jinx", image_url: "https://cdn.example/jinx.png" },
  opponent_legend: { id: "leg-2", name: "Viktor", image_url: "https://cdn.example/viktor.png" },
  my_deck: { id: 7, name: "Fureur de Noxus", format: "tournament" },
  opponent_deck: { id: 9, name: "Contrôle Ordre", format: "free" },
  my_score: 3,
  opponent_score: 8,
  my_rounds: 1,
  opponent_rounds: 2,
  outcome: "loss"
}

async function mountRow(overrides = {}, props = {}) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: "/:pathMatch(.*)*", component: { template: "<div />" } }]
  })
  router.push("/")
  await router.isReady()
  return mount(MatchRow, {
    props: { item: { ...item, ...overrides }, ...props },
    global: { plugins: [router] }
  })
}

describe("MatchRow", () => {
  it("affiche issue, adversaire, légendes, decks, score et format", async () => {
    const row = (await mountRow()).get(".partie-row")
    expect(row.get(".partie-issue").text()).toBe("Défaite")
    expect(row.get(".partie-issue").classes()).toContain("partie-issue-loss")
    expect(row.get(".partie-score b").text()).toBe("3 – 8")
    /* Format « match » : les manches gagnées s'affichent sous le score. */
    expect(row.text()).toContain("manches 1 – 2")
    expect(row.get(".partie-who a").attributes("href")).toBe("/u/nova")
    expect(row.text()).toContain("Jinx")
    expect(row.text()).toContain("Viktor")
    expect(row.get(".partie-meta").text()).toContain("Match")
    expect(row.get("time").attributes("datetime")).toBe("2026-08-12T19:30:00Z")
    /* Vignettes de légende rondes de 32 px (CDN réduit à 64 px). */
    const thumbs = row.findAll("img.partie-thumb")
    expect(thumbs).toHaveLength(2)
    expect(thumbs[0].attributes("width")).toBe("32")
    expect(thumbs[0].attributes("src")).toContain("w=64")
    /* Seul mon deck est cliquable : celui de l'adversaire n'est pas forcément public. */
    const links = row.findAll(".partie-deck a")
    expect(links).toHaveLength(1)
    expect(links[0].attributes("href")).toBe("/decks/7")
    expect(row.text()).toContain("Contrôle Ordre")
  })

  it("n'affiche pas les manches pour un duel", async () => {
    const wrapper = await mountRow({ mode: "duel" })
    expect(wrapper.text()).not.toContain("manches")
    expect(wrapper.get(".partie-meta").text()).toContain("Duel")
  })

  it("victoire : pastille « Victoire » aux couleurs du jeu", async () => {
    const wrapper = await mountRow({ outcome: "win" })
    expect(wrapper.get(".partie-issue").text()).toBe("Victoire")
    expect(wrapper.get(".partie-issue").classes()).toContain("partie-issue-win")
    expect(wrapper.get(".partie-issue .rift-chip").attributes("style")).toContain("var(--bronze-light)")
  })

  it("issue contestée, adversaire supprimé, pseudo long (classe d'ellipse)", async () => {
    const longHandle = "un_pseudo_vraiment_beaucoup_trop_long_pour_la_ligne"
    const disputed = await mountRow({ outcome: "disputed", opponent: null })
    expect(disputed.get(".partie-issue").text()).toBe("Contesté")
    expect(disputed.get(".partie-issue").classes()).toContain("partie-issue-disputed")
    expect(disputed.get(".partie-issue .rift-chip").attributes("style")).toContain("var(--ink-muted)")
    expect(disputed.text()).toContain("Compte supprimé")
    expect(disputed.find(".partie-who a").exists()).toBe(false)

    const long = await mountRow({ opponent: { handle: longHandle, avatar_url: "" } })
    const pseudo = long.get(".partie-pseudo")
    expect(pseudo.classes()).toContain("partie-ellipse")
    expect(pseudo.text()).toBe(longHandle)
    /* Le pseudo entier reste lisible au survol malgré l'ellipse. */
    expect(pseudo.attributes("title")).toBe(longHandle)
  })

  it("côté gauche : « Moi » sur mon historique, le pseudo du joueur sur son profil", async () => {
    expect((await mountRow()).get(".partie-side-me").text()).toContain("Moi")
    const profile = await mountRow({}, { self: { handle: "kai", avatar_url: "" } })
    expect(profile.get(".partie-side-me").text()).toContain("kai")
    expect(profile.get(".partie-side-me").text()).not.toContain("Moi")
  })

  it("sans légende ni deck : mentions explicites, pas de vignette cassée", async () => {
    const wrapper = await mountRow({ my_legend: null, opponent_legend: null, my_deck: null, opponent_deck: null })
    expect(wrapper.findAll("img.partie-thumb")).toHaveLength(0)
    expect(wrapper.text()).toContain("Sans légende")
    expect(wrapper.text()).toContain("Sans deck")
  })
})
