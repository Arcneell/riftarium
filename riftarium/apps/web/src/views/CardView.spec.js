import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CardView from "./CardView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function sample(extras = {}) {
  return {
    id: "ogn-037-298",
    riftbound_id: "ogn-037-298",
    name: "Immortal Phoenix",
    set_id: "OGN",
    type: "Unit",
    rarity: "Epic",
    domains: ["Fury"],
    energy: 3,
    might: 3,
    power: 1,
    text: "[Assault 2] (+2 :rb_might: while I'm an attacker.)",
    flavour: "Rise.",
    artist: "Kudos Productions",
    orientation: "portrait",
    image_url: "https://cdn.example/phoenix.png",
    variants: [],
    ...extras
  }
}

async function mountView(id, card) {
  api.mockResolvedValue(card)
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/cartes", component: { template: "<div />" } },
      { path: "/cartes/:id", component: CardView },
      { path: "/connexion", component: { template: "<div />" } }
    ]
  })
  router.push(`/cartes/${id}`)
  await router.isReady()
  const wrapper = mount(CardView, {
    global: { plugins: [router], directives: { tilt: {} } }
  })
  await flushPromises()
  return wrapper
}

describe("CardView", () => {
  beforeEach(() => {
    api.mockReset()
  })

  it("affiche une unité en deux colonnes, avec l'image entière", async () => {
    const wrapper = await mountView("ogn-037-298", sample())
    expect(wrapper.get(".card-sheet").classes()).not.toContain("landscape")
    expect(wrapper.get("img.full").attributes("src")).toContain("w=720")
    expect(wrapper.get("h1").text()).toBe("Immortal Phoenix")
    expect(wrapper.text()).toContain("Unité")
    expect(wrapper.text()).toContain("Fureur")
    expect(wrapper.get("img.rb-glyph.energy").attributes("src")).toContain("energy_3.svg")
    expect(wrapper.get("img.rb-glyph.rune").attributes("src")).toContain("rune_fury.svg")
    expect(wrapper.findAll("img.rb-glyph.rune")).toHaveLength(1)
    wrapper.unmount()
  })

  it("passe en mise en page terrain pour une carte paysage", async () => {
    const wrapper = await mountView(
      "ogn-275-298",
      sample({
        id: "ogn-275-298",
        riftbound_id: "ogn-275-298",
        name: "Altar to Unity",
        type: "Battlefield",
        orientation: "landscape",
        energy: null,
        might: null,
        power: null,
        domains: ["Colorless"]
      })
    )
    expect(wrapper.get(".card-sheet").classes()).toContain("landscape")
    expect(wrapper.get(".card-art").classes()).toContain("landscape")
    expect(wrapper.get("img.full").attributes("src")).toContain("w=1100")
    expect(wrapper.text()).toContain("Terrain")
    expect(wrapper.text()).toContain("Champ de bataille")
    expect(wrapper.find(".stat-row .stat").exists()).toBe(false)
    wrapper.unmount()
  })
})
