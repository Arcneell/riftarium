import { mount, RouterLinkStub } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftButton from "./RiftButton.vue"

const stubs = { RouterLink: RouterLinkStub }

describe("RiftButton", () => {
  it("rend un bouton type=button par défaut, en variante principale", () => {
    const wrapper = mount(RiftButton, { slots: { default: "Voir" }, global: { stubs } })
    const button = wrapper.get("button")
    expect(button.attributes("type")).toBe("button")
    expect(button.classes()).toEqual(expect.arrayContaining(["rift-btn", "rift-btn--primary", "rift-btn--md"]))
    expect(button.text()).toBe("Voir")
  })

  it("rend un lien du routeur quand `to` est fourni", () => {
    const wrapper = mount(RiftButton, { props: { to: "/cartes", variant: "secondary" }, global: { stubs } })
    const link = wrapper.getComponent(RouterLinkStub)
    expect(link.props("to")).toBe("/cartes")
    expect(link.classes()).toContain("rift-btn--secondary")
  })

  it("rend un lien externe quand `href` est fourni", () => {
    const wrapper = mount(RiftButton, { props: { href: "https://example.org" }, global: { stubs } })
    expect(wrapper.get("a").attributes("href")).toBe("https://example.org")
  })

  it("transmet disabled et type au bouton, et la taille sm", () => {
    const wrapper = mount(RiftButton, { props: { disabled: true, type: "submit", size: "sm" }, global: { stubs } })
    const button = wrapper.get("button")
    expect(button.attributes("disabled")).toBeDefined()
    expect(button.attributes("type")).toBe("submit")
    expect(button.classes()).toContain("rift-btn--sm")
  })

  it("émet le clic natif", async () => {
    const wrapper = mount(RiftButton, { global: { stubs } })
    await wrapper.get("button").trigger("click")
    expect(wrapper.emitted("click")).toHaveLength(1)
  })
})
