import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftSegments from "./RiftSegments.vue"

const items = [
  { value: "cartes", label: "Cartes" },
  { value: "deck", label: "Deck", badge: 12 },
  { value: "analyse", label: "Analyse" }
]
const mountSegments = (modelValue = "deck") =>
  mount(RiftSegments, { props: { modelValue, items, label: "Atelier", idBase: "atelier" }, attachTo: document.body })

describe("RiftSegments", () => {
  it("rend un tablist avec aria-selected et aria-controls", () => {
    const wrapper = mountSegments()
    expect(wrapper.get("[role=tablist]").attributes("aria-label")).toBe("Atelier")
    const tabs = wrapper.findAll("[role=tab]")
    expect(tabs.map((t) => t.attributes("id"))).toEqual([
      "atelier-tab-cartes",
      "atelier-tab-deck",
      "atelier-tab-analyse"
    ])
    expect(tabs.map((t) => t.attributes("aria-controls"))).toEqual([
      "atelier-panel-cartes",
      "atelier-panel-deck",
      "atelier-panel-analyse"
    ])
    expect(tabs.map((t) => t.attributes("aria-selected"))).toEqual(["false", "true", "false"])
    expect(tabs.map((t) => t.attributes("tabindex"))).toEqual(["-1", "0", "-1"])
    expect(tabs[0].attributes("type")).toBe("button")
    wrapper.unmount()
  })

  it("clic : émet update:modelValue", async () => {
    const wrapper = mountSegments()
    await wrapper.findAll("[role=tab]")[2].trigger("click")
    expect(wrapper.emitted("update:modelValue")).toEqual([["analyse"]])
    wrapper.unmount()
  })

  it("flèches, Home et End : déplacent la sélection et le focus, en bouclant", async () => {
    const wrapper = mountSegments()
    const tabs = wrapper.findAll("[role=tab]")
    await tabs[1].trigger("keydown", { key: "ArrowRight" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["analyse"])
    expect(document.activeElement).toBe(tabs[2].element)
    await tabs[2].trigger("keydown", { key: "ArrowRight" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["cartes"])
    expect(document.activeElement).toBe(tabs[0].element)
    await tabs[0].trigger("keydown", { key: "ArrowLeft" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["analyse"])
    await tabs[1].trigger("keydown", { key: "ArrowLeft" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["cartes"])
    await tabs[1].trigger("keydown", { key: "End" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["analyse"])
    expect(document.activeElement).toBe(tabs[2].element)
    await tabs[1].trigger("keydown", { key: "Home" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["cartes"])
    expect(document.activeElement).toBe(tabs[0].element)
    wrapper.unmount()
  })

  it("ignore les flèches avec Ctrl", () => {
    const wrapper = mountSegments()
    const tab = wrapper.findAll("[role=tab]")[1]
    for (const mod of ["altKey", "ctrlKey", "metaKey"]) {
      const event = new KeyboardEvent("keydown", { key: "ArrowRight", [mod]: true, bubbles: true, cancelable: true })
      tab.element.dispatchEvent(event)
      expect(event.defaultPrevented).toBe(false)
    }
    expect(wrapper.emitted("update:modelValue")).toBeUndefined()
    wrapper.unmount()
  })

  it("affiche le badge", () => {
    const wrapper = mountSegments()
    const tabs = wrapper.findAll("[role=tab]")
    expect(tabs[1].find(".rift-segments-badge").text()).toBe("12")
    expect(tabs[0].find(".rift-segments-badge").exists()).toBe(false)
    wrapper.unmount()
  })
})
