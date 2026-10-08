import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftChip from "./RiftChip.vue"
import source from "./RiftChip.vue?raw"
import fs from "node:fs"
import path from "node:path"

const consoleCss = fs.readFileSync(path.resolve("src/admin/console.css"), "utf8")

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

  it("statique : un span sans aria-pressed, sans événement", async () => {
    const wrapper = mount(RiftChip, { props: { label: "Fureur · 3", static: true } })
    expect(wrapper.element.tagName).toBe("SPAN")
    expect(wrapper.classes()).toContain("rift-chip")
    expect(wrapper.attributes("aria-pressed")).toBeUndefined()
    expect(wrapper.attributes("tabindex")).toBeUndefined()
    await wrapper.trigger("click")
    expect(wrapper.emitted("toggle")).toBeUndefined()
  })

  it("tactile : la puce bouton fait 44 px, la puce statique reste compacte", () => {
    expect(source).toMatch(/@media \(hover: none\)\s*\{\s*button\.rift-chip\s*\{\s*min-height: 44px;/)
    expect(source).not.toMatch(/span\.rift-chip/)
  })

  it("admin : compact sur bureau (classe doublée), 44 px sous hover: none", () => {
    expect(consoleCss).toMatch(/\.console-chips \.rift-chip\.rift-chip\s*\{\s*min-height: 24px/)
    expect(consoleCss).toMatch(
      /@media \(hover: none\)\s*\{\s*\.console-chips button\.rift-chip\.rift-chip\s*\{\s*min-height: 44px/
    )
  })
})
