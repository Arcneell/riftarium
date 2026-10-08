import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftPanel from "./RiftPanel.vue"

describe("RiftPanel", () => {
  it("rend une section titrée, reliée à son titre", () => {
    const wrapper = mount(RiftPanel, { props: { title: "Ma collection" }, slots: { default: "<p>contenu</p>" } })
    const root = wrapper.get(".rift-panel")
    expect(root.element.tagName).toBe("SECTION")
    const title = wrapper.get("h2.rift-panel-title")
    expect(title.text()).toBe("Ma collection")
    expect(root.attributes("aria-labelledby")).toBe(title.attributes("id"))
    expect(wrapper.text()).toContain("contenu")
  })

  it("accepte un titre riche par slot et une autre balise", () => {
    const wrapper = mount(RiftPanel, { props: { tag: "article" }, slots: { title: "<em>Decks</em>" } })
    expect(wrapper.element.tagName).toBe("ARTICLE")
    expect(wrapper.get("h2.rift-panel-title em").text()).toBe("Decks")
  })

  it("sans titre : pas de h2 ni d'aria-labelledby", () => {
    const wrapper = mount(RiftPanel, { slots: { default: "x" } })
    expect(wrapper.find("h2").exists()).toBe(false)
    expect(wrapper.attributes("aria-labelledby")).toBeUndefined()
  })

  it("pose la couleur d'accent en variable CSS", () => {
    const wrapper = mount(RiftPanel, { props: { accent: "var(--mind)" } })
    expect(wrapper.attributes("style")).toContain("--panel-accent: var(--mind)")
  })
})
