import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import CollectionStats from "./CollectionStats.vue"

describe("CollectionStats", () => {
  it("affiche une statistique par entrée, avec son titre", () => {
    const wrapper = mount(CollectionStats, {
      props: {
        items: [
          { label: "Cartes", value: 6 },
          { label: "Complétion", value: "63 %", title: "149 cartes manquantes" }
        ]
      }
    })
    const stats = wrapper.findAll(".rift-stat")
    expect(stats).toHaveLength(2)
    expect(stats[0].text()).toContain("Cartes")
    expect(stats[0].text()).toContain("6")
    expect(stats[1].text()).toContain("63 %")
    expect(stats[1].attributes("title")).toBe("149 cartes manquantes")
  })

  it("affiche un tiret quand la valeur est nulle", () => {
    const wrapper = mount(CollectionStats, { props: { items: [{ label: "Valeur estimée", value: null }] } })
    expect(wrapper.get(".rift-stat").text()).toContain("—")
  })
})
