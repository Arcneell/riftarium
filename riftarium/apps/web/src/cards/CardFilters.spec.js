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
    const legends = mountFilters()
      .findAll("legend")
      .map((l) => l.text())
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

  it("hide-search retire le champ de recherche et garde les facettes", () => {
    const wrapper = mount(CardFilters, {
      props: { state: empty(), sets: SETS, hideSearch: true },
      global: { components: { Icon } }
    })
    expect(wrapper.find("input").exists()).toBe(false)
    expect(wrapper.findAll("fieldset")).toHaveLength(5)
  })
})
