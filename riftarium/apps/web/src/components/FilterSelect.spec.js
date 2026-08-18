import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import FilterSelect from "./FilterSelect.vue"

const OPTIONS = [
  { value: "Fury", label: "Fureur", color: "#cf4437" },
  { value: "Calm", label: "Calme", color: "#178f7f" }
]

function mountSelect(modelValue = []) {
  return mount(FilterSelect, {
    props: { label: "Domaines", options: OPTIONS, modelValue },
    attachTo: document.body
  })
}

describe("FilterSelect", () => {
  it("garde la liste repliée et n'affiche les options qu'à l'ouverture", async () => {
    const wrapper = mountSelect()
    expect(wrapper.find(".fsel-pop").exists()).toBe(false)

    await wrapper.get(".fsel-btn").trigger("click")
    expect(wrapper.findAll(".fsel-opt")).toHaveLength(2)

    await wrapper.get(".fsel-btn").trigger("click")
    expect(wrapper.find(".fsel-pop").exists()).toBe(false)
    wrapper.unmount()
  })

  it("émet la sélection cumulée et affiche le compteur", async () => {
    const wrapper = mountSelect(["Fury"])
    expect(wrapper.get(".fsel-count").text()).toBe("1")
    expect(wrapper.get(".fsel-btn").classes()).toContain("active")

    await wrapper.get(".fsel-btn").trigger("click")
    await wrapper.findAll(".fsel-opt")[1].trigger("click")
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual([["Fury", "Calm"]])

    await wrapper.get(".fsel-clear").trigger("click")
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual([[]])
    wrapper.unmount()
  })

  it("affiche un glyphe d'énergie à côté du libellé", async () => {
    const wrapper = mount(FilterSelect, {
      props: {
        label: "Coût",
        options: [{ value: "3", label: "3", glyph: "https://example/energy_3.svg", glyphKind: "energy" }],
        modelValue: []
      },
      attachTo: document.body
    })
    await wrapper.get(".fsel-btn").trigger("click")
    const glyph = wrapper.get(".fsel-opt img.rb-glyph.energy")
    expect(glyph.attributes("src")).toBe("https://example/energy_3.svg")
    expect(wrapper.find(".fsel-tick").exists()).toBe(false)
    wrapper.unmount()
  })

  it("montre les runes officielles à la place des pastilles de couleur", async () => {
    const wrapper = mount(FilterSelect, {
      props: {
        label: "Domaines",
        options: [
          { value: "Fury", label: "Fureur", glyph: "https://example/rune_fury.svg", glyphKind: "rune" },
          { value: "Calm", label: "Calme", glyph: "https://example/rune_calm.svg", glyphKind: "rune" }
        ],
        modelValue: ["Fury"]
      },
      attachTo: document.body
    })
    expect(wrapper.get(".fsel-glyphs img.rb-glyph.rune").attributes("src")).toContain("rune_fury.svg")
    expect(wrapper.find(".fsel-count").exists()).toBe(false)

    await wrapper.get(".fsel-btn").trigger("click")
    const options = wrapper.findAll(".fsel-opt")
    expect(options[0].find(".fsel-tick").exists()).toBe(false)
    expect(options[0].get("img.rb-glyph.rune").attributes("src")).toContain("rune_fury.svg")
    expect(options[1].get("img.rb-glyph.rune").attributes("src")).toContain("rune_calm.svg")
    wrapper.unmount()
  })

  it("se referme au clic extérieur et sur Échap", async () => {
    const wrapper = mountSelect()
    await wrapper.get(".fsel-btn").trigger("click")
    document.dispatchEvent(new window.MouseEvent("pointerdown", { bubbles: true }))
    await wrapper.vm.$nextTick()
    expect(wrapper.find(".fsel-pop").exists()).toBe(false)

    await wrapper.get(".fsel-btn").trigger("click")
    document.dispatchEvent(new window.KeyboardEvent("keydown", { key: "Escape" }))
    await wrapper.vm.$nextTick()
    expect(wrapper.find(".fsel-pop").exists()).toBe(false)
    wrapper.unmount()
  })

  it("filtre les options par saisie quand le sélecteur est searchable", async () => {
    const wrapper = mount(FilterSelect, {
      props: {
        label: "Légendes",
        searchable: true,
        options: [
          { value: "a", label: "Ahri" },
          { value: "j", label: "Jinx" }
        ],
        modelValue: []
      },
      attachTo: document.body
    })
    await wrapper.get(".fsel-btn").trigger("click")
    expect(wrapper.findAll(".fsel-opt")).toHaveLength(2)
    const search = wrapper.get(".fsel-search")
    await search.setValue("jinx")
    expect(wrapper.findAll(".fsel-opt")).toHaveLength(1)
    expect(wrapper.get(".fsel-opt").text()).toBe("Jinx")
    wrapper.unmount()
  })
})
