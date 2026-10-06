import { mount, RouterLinkStub } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import HomeSplash from "./HomeSplash.vue"

const ART = "https://cmsassets.rgpub.io/sanity/images/x.jpg?w=1920"
const mountSplash = (props = {}) =>
  mount(HomeSplash, { props: { art: ART, ...props }, global: { stubs: { RouterLink: RouterLinkStub } } })

describe("HomeSplash", () => {
  afterEach(() => {
    document.head.querySelectorAll("link[rel=preload]").forEach((link) => link.remove())
  })

  it("titre, deux actions et crédit Riot", () => {
    const wrapper = mountSplash()
    expect(wrapper.get("h1").text()).toContain("Domine le Rift")
    expect(wrapper.findAllComponents(RouterLinkStub).map((l) => l.props("to"))).toEqual(["/cartes", "/regles"])
    expect(wrapper.text()).toContain("© Riot Games")
    expect(wrapper.get(".splash").attributes("style")).toContain(ART)
  })

  it("n'affiche les chiffres que s'ils sont connus", async () => {
    const wrapper = mountSplash()
    expect(wrapper.find(".splash-stats").exists()).toBe(false)
    await wrapper.setProps({ cardCount: 1024, setCount: 3 })
    const statsText = wrapper.get(".splash-stats").text()
    expect(statsText).toContain("cartes")
    expect(statsText).toMatch(/1\s024/)
  })

  it("précharge l'illustration le temps de sa présence", () => {
    const wrapper = mountSplash()
    const link = document.head.querySelector("link[rel=preload][as=image]")
    expect(link.getAttribute("href")).toBe(ART)
    wrapper.unmount()
    expect(document.head.querySelector("link[rel=preload][as=image]")).toBeNull()
  })
})
