import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import { defineComponent, h } from "vue"
import Logo from "./Logo.vue"

/* Sceau de forge (charte « Forge noxienne ») : octogone aux angles coupés, carte
   fendue par la faille rouge. Rendu deux fois par page (rail et pied) : chaque
   instance doit garder ses propres dégradés. */
describe("Logo", () => {
  it("dessine le sceau de forge : octogone, carte et faille", () => {
    const wrapper = mount(Logo)
    const seal = wrapper.get("polygon[data-part=sceau]")
    expect(seal.attributes("points").trim().split(/\s+/)).toHaveLength(8)
    expect(wrapper.find("[data-part=carte]").exists()).toBe(true)
    expect(wrapper.find("[data-part=faille]").exists()).toBe(true)
    /* Plus rien de l'ancienne charte « nuit de Piltover » (disque bleu nuit). */
    expect(wrapper.html()).not.toContain("#0e1c34")
  })

  it("donne à chaque instance ses propres dégradés, bien référencés", () => {
    const Twice = defineComponent({ render: () => h("div", [h(Logo), h(Logo)]) })
    const wrapper = mount(Twice)
    const ids = wrapper.findAll("defs [id]").map((gradient) => gradient.attributes("id"))
    expect(new Set(ids).size).toBe(ids.length)
    for (const svg of wrapper.findAll("svg")) {
      const own = svg.findAll("defs [id]").map((gradient) => gradient.attributes("id"))
      const used = [...svg.html().matchAll(/url\(#([^)]+)\)/g)].map((match) => match[1])
      expect(used.length).toBeGreaterThan(0)
      for (const id of used) expect(own).toContain(id)
    }
  })
})
