import { flushPromises, mount, RouterLinkStub } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it, vi } from "vitest"

vi.mock("./homeData.js", async (importOriginal) => ({ ...(await importOriginal()), loadMemberSummary: vi.fn() }))
const { loadMemberSummary } = await import("./homeData.js")
const { session } = await import("../api.js")
const { default: HomeBlocks } = await import("./HomeBlocks.vue")

/* Démontés après chaque test : un composant resté monté réagirait aux connexions des tests suivants. */
const mounted = []
const mountBlocks = () => {
  const wrapper = mount(HomeBlocks, { global: { stubs: { RouterLink: RouterLinkStub } } })
  mounted.push(wrapper)
  return wrapper
}
const titles = (wrapper) => wrapper.findAll(".rift-panel-title").map((t) => t.text())
const links = (wrapper) => wrapper.findAllComponents(RouterLinkStub).map((l) => l.props("to"))

describe("HomeBlocks", () => {
  afterEach(() => {
    mounted.splice(0).forEach((wrapper) => wrapper.unmount())
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

  it.each([
    [0, "Deck vide : ajoutez vos premières cartes"],
    [undefined, "Deck vide : ajoutez vos premières cartes"],
    [1, "1 carte"],
    [38, "38 cartes"]
  ])("dernier deck à %s carte(s) : %s", async (count, expected) => {
    session.token = "1"
    loadMemberSummary.mockResolvedValue({
      collection: null,
      deck: { id: 9, name: "Lee Sin Tempo", card_count: count },
      match: null
    })
    const wrapper = mountBlocks()
    await flushPromises()
    const text = wrapper.text()
    expect(text).toContain(expected)
    if (count === 1) expect(text).not.toContain("1 cartes")
    expect(text).not.toMatch(/undefined|NaN/)
  })

  it("connexion après montage : charge et affiche le résumé", async () => {
    loadMemberSummary.mockResolvedValue({
      collection: { owned: 5, total: 10, percent: 50 },
      deck: null,
      match: null
    })
    const wrapper = mountBlocks()
    await flushPromises()
    expect(loadMemberSummary).not.toHaveBeenCalled()
    session.token = "1"
    await flushPromises()
    expect(loadMemberSummary).toHaveBeenCalledTimes(1)
    expect(wrapper.text()).toContain("50 %")
    expect(wrapper.text()).toContain("5 / 10")
  })
})
