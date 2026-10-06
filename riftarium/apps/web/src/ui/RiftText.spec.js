import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftText from "./RiftText.vue"

describe("RiftText", () => {
  it("rend les shortcodes avec les glyphes officiels plutôt qu'en texte brut", () => {
    const wrapper = mount(RiftText, { props: { text: "Pay :rb_energy_3: :rb_rune_order: :rb_might:." } })
    expect(wrapper.text()).not.toContain(":rb_energy_3:")
    expect(wrapper.text()).not.toContain(":rb_might:")

    const might = wrapper.get(".rb-glyph.ink")
    expect(might.attributes("aria-label")).toBe("Puissance")
    expect(might.attributes("style")).toContain("riot-glyphs/rb/latest/might.svg")

    expect(wrapper.get("img.rb-glyph.energy").attributes("src")).toContain("energy_3.svg")
    expect(wrapper.get("img.rb-glyph.rune").attributes("alt")).toBe("Rune d'Ordre")
    wrapper.unmount()
  })

  it("colore les mots-clés selon leur famille et marque la flèche", () => {
    const wrapper = mount(RiftText, { props: { text: "[Reaction] then [Assault 2] and [Level 3][&gt;] go." } })
    const badges = wrapper.findAll(".rb-kw")
    expect(badges.map((badge) => badge.text())).toEqual(["Reaction", "Assault 2", "Level 3"])
    expect(badges[0].classes()).toContain("timing")
    expect(badges[1].classes()).toContain("combat")
    expect(badges[2].classes()).toEqual(expect.arrayContaining(["state", "arrow"]))
    expect(wrapper.text()).not.toContain("&gt;")
    wrapper.unmount()
  })

  it("rend la balise demandée avec la classe rift-text", () => {
    const wrapper = mount(RiftText, { props: { text: "Bonjour", tag: "p" } })
    expect(wrapper.element.tagName).toBe("P")
    expect(wrapper.classes()).toContain("rift-text")
    wrapper.unmount()
  })

  it("en mode règles, met le gras en <b> et convertit les abréviations", () => {
    const wrapper = mount(RiftText, { props: { text: "**Important** : payez [R].", rules: true } })
    expect(wrapper.get("b").text()).toBe("Important")
    expect(wrapper.get("img.rb-glyph.rune").attributes("alt")).toBe("Rune de Fureur")
    wrapper.unmount()
  })
})
