import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import { makeRouter } from "../test/makeRouter.js"
import RiftTabs from "./RiftTabs.vue"

const ITEMS = [
  { label: "Apprendre", to: "/regles/debutant" },
  { label: "Plateau animé", to: "/regles/debutant/plateau" },
  { label: "Texte officiel", to: "/regles/officielles" }
]

describe("RiftTabs", () => {
  it("marque l'onglet du plus long préfixe comme page courante", async () => {
    const router = await makeRouter("/regles/debutant/plateau")
    const wrapper = mount(RiftTabs, { props: { items: ITEMS, label: "Règles" }, global: { plugins: [router] } })
    expect(wrapper.get("nav").attributes("aria-label")).toBe("Règles")
    const current = wrapper.findAll("a").filter((a) => a.attributes("aria-current") === "page")
    expect(current.map((a) => a.text())).toEqual(["Plateau animé"])
  })

  it("garde l'onglet parent actif sur une page fille sans onglet propre", async () => {
    const router = await makeRouter("/regles/debutant/victoire")
    const wrapper = mount(RiftTabs, { props: { items: ITEMS, label: "Règles" }, global: { plugins: [router] } })
    expect(wrapper.get("a.active").text()).toBe("Apprendre")
  })
})
