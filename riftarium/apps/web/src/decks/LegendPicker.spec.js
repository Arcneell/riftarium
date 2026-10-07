import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import LegendPicker from "./LegendPicker.vue"

const LEGENDS = [
  { id: "ogn-1", name: "Élise la Prêtresse", image_url: "https://cdn.test/elise.png", deck_count: 3 },
  { id: "ogn-2", name: "Jinx", image_url: "https://cdn.test/jinx.png", deck_count: 5 },
  { id: "ogn-3", name: "Jax", image_url: "https://cdn.test/jax.png", deck_count: 2 }
]

let wrapper
function mountPicker(modelValue = [], attachTo) {
  wrapper = mount(LegendPicker, {
    props: { legends: LEGENDS, modelValue },
    attachTo,
    global: { stubs: { Icon: true } }
  })
  return wrapper
}
afterEach(() => wrapper?.unmount())

const input = () => wrapper.get('input[role="combobox"]')
const options = () => wrapper.findAll('[role="option"]')

describe("LegendPicker", () => {
  it("le focus ouvre la liste, aria-expanded passe à true", async () => {
    mountPicker()
    expect(input().attributes("aria-expanded")).toBe("false")
    await input().trigger("focus")
    expect(input().attributes("aria-expanded")).toBe("true")
    expect(input().attributes("aria-controls")).toBe(wrapper.get('[role="listbox"]').attributes("id"))
    expect(wrapper.get('[role="listbox"]').attributes("aria-multiselectable")).toBe("true")
    expect(options()).toHaveLength(3)
  })

  it("la recherche filtre sans tenir compte des accents ni de la casse", async () => {
    mountPicker()
    await input().setValue("ELISE")
    expect(options().map((o) => o.text())).toEqual([expect.stringContaining("Élise la Prêtresse")])
    await input().setValue("pretresse")
    expect(options()).toHaveLength(1)
    await input().setValue("j")
    expect(options()).toHaveLength(2)
  })

  it("un clic sur une option émet la sélection ajoutée, un second la retire", async () => {
    mountPicker()
    await input().trigger("focus")
    await options()[1].trigger("click")
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual([["ogn-2"]])
    await wrapper.setProps({ modelValue: ["ogn-2"] })
    expect(options()[1].attributes("aria-selected")).toBe("true")
    expect(options()[1].text()).toContain("✓")
    await options()[1].trigger("click")
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual([[]])
    expect(input().attributes("aria-expanded")).toBe("true")
  })

  it("↓ ↓ puis Entrée sélectionne la deuxième option visible, et aria-activedescendant la suit", async () => {
    mountPicker()
    await input().trigger("focus")
    await input().trigger("keydown", { key: "ArrowDown" })
    await input().trigger("keydown", { key: "ArrowDown" })
    expect(input().attributes("aria-activedescendant")).toBe(options()[1].attributes("id"))
    await input().trigger("keydown", { key: "Enter" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual([["ogn-2"]])
    await input().trigger("keydown", { key: "End" })
    expect(input().attributes("aria-activedescendant")).toBe(options()[2].attributes("id"))
    await input().trigger("keydown", { key: "ArrowDown" })
    expect(input().attributes("aria-activedescendant")).toBe(options()[2].attributes("id"))
    await input().trigger("keydown", { key: "Home" })
    expect(input().attributes("aria-activedescendant")).toBe(options()[0].attributes("id"))
  })

  it("Échap ferme la liste, puis vide la recherche", async () => {
    mountPicker()
    await input().setValue("jin")
    expect(input().attributes("aria-expanded")).toBe("true")
    await input().trigger("keydown", { key: "Escape" })
    expect(input().attributes("aria-expanded")).toBe("false")
    expect(input().element.value).toBe("jin")
    await input().trigger("keydown", { key: "Escape" })
    expect(input().element.value).toBe("")
  })

  it("Tab ferme la liste", async () => {
    mountPicker()
    await input().trigger("focus")
    await input().trigger("keydown", { key: "Tab" })
    expect(input().attributes("aria-expanded")).toBe("false")
  })

  it("clic en dehors : la liste se ferme", async () => {
    mountPicker()
    await input().trigger("focus")
    expect(input().attributes("aria-expanded")).toBe("true")
    document.body.dispatchEvent(new Event("pointerdown", { bubbles: true }))
    await wrapper.vm.$nextTick()
    expect(input().attributes("aria-expanded")).toBe("false")
  })

  it("les légendes choisies apparaissent en puces supprimables, et un clic les retire", async () => {
    mountPicker(["ogn-1", "ogn-3"])
    const chips = wrapper.findAll("button.rift-chip")
    expect(chips.map((c) => c.text())).toEqual(["Élise la Prêtresse✕", "Jax✕"])
    await chips[0].trigger("click")
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual([["ogn-3"]])
  })

  it("aucun résultat : le message s'affiche", async () => {
    mountPicker()
    await input().setValue("zzz")
    expect(options()).toHaveLength(0)
    expect(wrapper.get('[role="status"]').text()).toBe("Aucune légende ne correspond")
  })

  it("Échap ne remonte pas au document tant qu'il sert à fermer ou vider, mais remonte à vide", async () => {
    mountPicker([], document.body)
    const seen = []
    const spy = (event) => seen.push(event.key)
    document.addEventListener("keydown", spy)
    try {
      await input().setValue("jin")
      const first = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true })
      input().element.dispatchEvent(first)
      await wrapper.vm.$nextTick()
      expect(first.defaultPrevented).toBe(true)
      input().element.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }))
      await wrapper.vm.$nextTick()
      expect(input().element.value).toBe("")
      expect(seen).toEqual([])
      input().element.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }))
      expect(seen).toEqual(["Escape"])
    } finally {
      document.removeEventListener("keydown", spy)
    }
  })

  it("une légende choisie absente de la liste reste une puce supprimable (identifiant en repli)", async () => {
    mountPicker(["perime-9"])
    const chips = wrapper.findAll("button.rift-chip")
    expect(chips.map((c) => c.text())).toEqual(["perime-9✕"])
    await chips[0].trigger("click")
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual([[]])
  })
})
