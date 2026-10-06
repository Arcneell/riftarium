import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftStat from "./RiftStat.vue"

describe("RiftStat", () => {
  it("glyphe image, valeur et étiquette", () => {
    const wrapper = mount(RiftStat, {
      props: { label: "Énergie", glyph: "https://x/energy_5.svg", glyphKind: "energy" }
    })
    expect(wrapper.get("img.rb-glyph.energy").attributes("alt")).toBe("Énergie")
    expect(wrapper.get(".rift-stat-label").text()).toBe("Énergie")
  })

  it("glyphe teinté (puissance) et valeur", () => {
    const wrapper = mount(RiftStat, {
      props: { label: "Puissance", glyph: "https://x/might.svg", ink: true, value: 4 }
    })
    const glyph = wrapper.get("span.rb-glyph.ink")
    expect(glyph.attributes("style")).toContain("might.svg")
    expect(wrapper.get(".rift-stat-value").text()).toBe("4")
  })

  it("glyphe teinté masqué aux lecteurs d'écran quand une valeur est affichée", () => {
    const wrapper = mount(RiftStat, {
      props: { label: "Puissance", glyph: "https://x/might.svg", ink: true, value: 4 }
    })
    const glyph = wrapper.get("span.rb-glyph.ink")
    expect(glyph.attributes("aria-hidden")).toBe("true")
    expect(glyph.attributes("role")).toBeUndefined()
    expect(glyph.attributes("aria-label")).toBeUndefined()
  })

  it("glyphe teinté sans valeur : reste un role=img nommé", () => {
    const wrapper = mount(RiftStat, { props: { label: "Puissance", glyph: "https://x/might.svg", ink: true } })
    const glyph = wrapper.get("span.rb-glyph.ink")
    expect(glyph.attributes("role")).toBe("img")
    expect(glyph.attributes("aria-label")).toBe("Puissance")
  })

  it("glyphAlt personnalisé pour l'image, repli sur l'étiquette", () => {
    const wrapper = mount(RiftStat, {
      props: { label: "Énergie", glyph: "https://x/energy_5.svg", glyphAlt: "5 énergie" }
    })
    expect(wrapper.get("img.rb-glyph").attributes("alt")).toBe("5 énergie")
  })

  it("slot pour un contenu riche", () => {
    const wrapper = mount(RiftStat, { props: { label: "Pouvoir" }, slots: { default: "<i class='runes'>RR</i>" } })
    expect(wrapper.find(".runes").exists()).toBe(true)
  })
})
