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
