import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftChip from "./RiftChip.vue"

describe("RiftChip", () => {
  it("bascule : aria-pressed et événement toggle", async () => {
    const wrapper = mount(RiftChip, { props: { label: "Fureur", selected: true } })
    const button = wrapper.get("button.rift-chip")
    expect(button.attributes("aria-pressed")).toBe("true")
    await button.trigger("click")
    expect(wrapper.emitted("toggle")).toHaveLength(1)
  })

  it("retirable : libellé accessible, croix et événement remove", async () => {
    const wrapper = mount(RiftChip, { props: { label: "Origins", removable: true } })
    const button = wrapper.get("button")
    expect(button.attributes("aria-pressed")).toBeUndefined()
    expect(button.attributes("aria-label")).toBe("Retirer le filtre Origins")
    expect(button.text()).toContain("✕")
    await button.trigger("click")
    expect(wrapper.emitted("remove")).toHaveLength(1)
  })

  it("affiche le glyphe officiel et pose la couleur", () => {
    const wrapper = mount(RiftChip, {
      props: { label: "Fureur", glyph: "https://x/rune_fury.svg", glyphKind: "rune", color: "var(--fury)" }
    })
    expect(wrapper.get("img.rb-glyph.rune").attributes("src")).toBe("https://x/rune_fury.svg")
    expect(wrapper.attributes("style")).toContain("--chip-color: var(--fury)")
  })
})
