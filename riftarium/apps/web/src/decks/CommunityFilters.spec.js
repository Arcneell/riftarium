import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import CommunityFilters from "./CommunityFilters.vue"

const LEGENDS = [
  { id: "ogn-1", name: "Élise la Prêtresse", deck_count: 3 },
  { id: "ogn-2", name: "Jinx", deck_count: 5 }
]

function baseState(extra = {}) {
  return { q: "", legend: [], domain: [], format: [], sort: "likes", liked: false, buildable: false, ...extra }
}

function mountFilters(props = {}) {
  return mount(CommunityFilters, {
    props: { state: baseState(), legends: LEGENDS, signedIn: false, ...props },
    global: { stubs: { Icon: true } }
  })
}

const facet = (wrapper, legend) => wrapper.findAll("fieldset").find((node) => node.get("legend").text() === legend)

describe("CommunityFilters", () => {
  it("filtre local des légendes insensible aux accents", async () => {
    const wrapper = mountFilters()
    const names = () => facet(wrapper, "Légendes").findAll('[role="option"]')
    await facet(wrapper, "Légendes").get("input").trigger("focus")
    expect(names()).toHaveLength(2)
    await facet(wrapper, "Légendes").get("input").setValue("ELISE")
    expect(names()).toHaveLength(1)
    expect(names()[0].text()).toContain("Élise la Prêtresse")
    await facet(wrapper, "Légendes").get("input").setValue("pretresse")
    expect(names()).toHaveLength(1)
  })

  it("masque le fieldset des légendes quand aucune n'est chargée", () => {
    expect(facet(mountFilters({ legends: [] }), "Légendes")).toBeUndefined()
  })

  it("puce Constructibles absente pour un visiteur", () => {
    expect(mountFilters().text()).not.toContain("Constructibles avec ma collection")
    const signed = mountFilters({ signedIn: true })
    expect(signed.text()).toContain("Constructibles avec ma collection")
  })

  it("tri au radiogroup émet update('sort', …)", async () => {
    const wrapper = mountFilters()
    const radios = wrapper.get('[role="radiogroup"]').findAll('[role="radio"]')
    expect(radios.map((r) => r.text())).toEqual(["Plus aimés", "Plus vus", "Récents"])
    await radios[1].trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["sort", "views"])
  })

  it("bascule d'une légende et du format, puce Decks aimés émet liked", async () => {
    const wrapper = mountFilters({ state: baseState({ legend: ["ogn-1"] }) })
    await facet(wrapper, "Légendes").get("input").trigger("focus")
    const legends = facet(wrapper, "Légendes").findAll('[role="option"]')
    expect(legends[0].attributes("aria-selected")).toBe("true")
    await legends[0].trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["legend", []])
    await legends[1].trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["legend", ["ogn-1", "ogn-2"]])
    await facet(wrapper, "Format").findAll("button.rift-chip")[1].trigger("click")
    expect(wrapper.emitted("update").at(-1)).toEqual(["format", ["free"]])
    await facet(wrapper, "Mes favoris").get("button.rift-chip").trigger("click")
    expect(wrapper.emitted("liked")).toHaveLength(1)
  })
})
