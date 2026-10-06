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
