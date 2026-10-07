import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RulesHeader from "./RulesHeader.vue"

describe("RulesHeader", () => {
  it("fil d'Ariane avec aria-current et h1", () => {
    const wrapper = mount(RulesHeader, {
      props: {
        title: "Aide avancée",
        kicker: "Règles",
        crumbs: [{ label: "Règles", to: "/regles" }, { label: "Aide avancée" }]
      },
      slots: { default: "<p class='meta'>Méta</p>" },
      global: { stubs: { RouterLink: { props: ["to"], template: "<a :href='to'><slot /></a>" } } }
    })
    const nav = wrapper.get("nav")
    expect(nav.attributes("aria-label")).toBe("Fil d'Ariane")
    expect(nav.findAll("a")).toHaveLength(1)
    const current = nav.get("[aria-current='page']")
    expect(current.text()).toBe("Aide avancée")
    expect(current.element.tagName).not.toBe("A")
    expect(wrapper.get("h1.regles-title").text()).toBe("Aide avancée")
    expect(wrapper.get(".regles-kicker").text()).toBe("Règles")
    expect(wrapper.get(".meta").text()).toBe("Méta")
  })
})
