import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import LegalView from "./LegalView.vue"
import { LEGAL_NAV, RIOT_DISCLAIMER_EN, RIOT_GENERAL_DISCLAIMER_EN } from "../legal.js"

const legalRoutes = [
  ...LEGAL_NAV.map((item) => ({
    path: item.path,
    component: LegalView,
    meta: { legal: item.key }
  })),
  { path: "/profil", component: { template: "<div />" } }
]

async function mountPage(path) {
  const router = createRouter({ history: createMemoryHistory(), routes: legalRoutes })
  router.push(path)
  await router.isReady()
  return mount(LegalView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } }
  })
}

describe("LegalView", () => {
  it("affiche le disclaimer Riot exigé sur les mentions légales", async () => {
    const wrapper = await mountPage("/mentions-legales")
    expect(wrapper.text()).toContain(RIOT_DISCLAIMER_EN)
    expect(wrapper.text()).toContain(RIOT_GENERAL_DISCLAIMER_EN)
    expect(wrapper.text()).toContain("bêta fermée")
    expect(wrapper.text()).toContain("Riftcodex")
    expect(wrapper.text()).toContain("OVH SAS")
    expect(wrapper.text()).toContain("contact@riftarium.re")
    expect(wrapper.find(".legal-nav").text()).toContain("CGU")
  })

  it("décrit le hash d'IP et l'export du compte dans la confidentialité", async () => {
    const wrapper = await mountPage("/confidentialite")
    expect(wrapper.text()).toContain("SHA-256")
    expect(wrapper.text()).toContain("15 ans")
    expect(wrapper.text()).toContain("CNIL")
    expect(wrapper.text()).toContain("OVH SAS")
  })

  it("qualifie le mode libre de format non officiel dans les CGU", async () => {
    const wrapper = await mountPage("/cgu")
    expect(wrapper.text()).toContain("format non officiel")
    expect(wrapper.text()).toContain(RIOT_DISCLAIMER_EN)
    expect(wrapper.text()).toContain(RIOT_GENERAL_DISCLAIMER_EN)
  })

  it("indique que les polices ne passent plus par Google Fonts", async () => {
    const wrapper = await mountPage("/cookies")
    expect(wrapper.text()).toContain("bandeau d'information")
    expect(wrapper.text()).toContain("pas par Google Fonts")
    expect(wrapper.text()).toContain("riftarium_session")
  })
})
