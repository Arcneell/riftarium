import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import ShellBandeau from "./ShellBandeau.vue"

describe("ShellBandeau", () => {
  it("information par défaut : texte, sans zone d'actions", () => {
    const wrapper = mount(ShellBandeau, { slots: { default: "<p>Hors ligne</p>" }, attrs: { role: "status" } })
    const root = wrapper.get(".bandeau-cadre")
    expect(root.classes()).toContain("bandeau-cadre--info")
    expect(root.attributes("role")).toBe("status")
    expect(wrapper.get(".bandeau-texte").text()).toBe("Hors ligne")
    expect(wrapper.find(".bandeau-actions").exists()).toBe(false)
  })

  it("action requise : filet sang et zone d'actions", () => {
    const wrapper = mount(ShellBandeau, {
      props: { tone: "action" },
      slots: { default: "<p>À faire</p>", actions: "<button type='button'>Agir</button>" }
    })
    expect(wrapper.get(".bandeau-cadre").classes()).toContain("bandeau-cadre--action")
    expect(wrapper.get(".bandeau-actions button").text()).toBe("Agir")
  })
})
