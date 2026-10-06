import { mount, RouterLinkStub } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import HomeSplash from "./HomeSplash.vue"

const ART = "https://cmsassets.rgpub.io/sanity/images/x.jpg?w=1920"
const mountSplash = (props = {}) =>
  mount(HomeSplash, { props: { art: ART, ...props }, global: { stubs: { RouterLink: RouterLinkStub } } })

describe("HomeSplash", () => {
  it("titre, deux actions et crédit Riot", () => {
    const wrapper = mountSplash()
    expect(wrapper.get("h1").text()).toContain("Domine le Rift")
    expect(wrapper.findAllComponents(RouterLinkStub).map((l) => l.props("to"))).toEqual(["/cartes", "/regles"])
    expect(wrapper.text()).toContain("© Riot Games")
  })

  it("n'affiche les chiffres que s'ils sont connus", async () => {
    const wrapper = mountSplash()
    expect(wrapper.find(".splash-stats").exists()).toBe(false)
    await wrapper.setProps({ cardCount: 1024, setCount: 3 })
    const statsText = wrapper.get(".splash-stats").text()
    expect(statsText).toContain("cartes")
    expect(statsText).toMatch(/1\s024/)
  })

  it("l'illustration est une vraie image prioritaire (LCP)", () => {
    const img = mountSplash().get("img.splash-art")
    expect(img.attributes("src")).toBe(ART)
    expect(img.attributes("fetchpriority")).toBe("high")
    expect(img.attributes("alt")).toBe("")
    expect(document.head.querySelector("link[rel=preload]")).toBeNull()
  })
})
