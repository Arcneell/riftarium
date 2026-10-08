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
    global: { plugins: [router], stubs: { Icon: true } }
  })
}

describe("LegalView", () => {
  it("affiche le disclaimer Riot exigé sur les mentions légales", async () => {
    const wrapper = await mountPage("/mentions-legales")
    expect(wrapper.text()).toContain(RIOT_DISCLAIMER_EN)
    expect(wrapper.text()).toContain(RIOT_GENERAL_DISCLAIMER_EN)
    expect(wrapper.text()).toContain("bêta fermée")
    expect(wrapper.text()).toContain("Riftcodex")
    expect(wrapper.text()).toContain("TCGplayer")
    expect(wrapper.text()).toContain("Banque centrale européenne")
    expect(wrapper.text()).toContain("OVH SAS")
    expect(wrapper.text()).toContain("contact@riftarium.re")
    expect(wrapper.find(".mentions-toc").text()).toContain("CGU")
  })

  it("décrit le hash d'IP et l'export du compte dans la confidentialité", async () => {
    const wrapper = await mountPage("/confidentialite")
    expect(wrapper.text()).toContain("SHA-256")
    expect(wrapper.text()).toContain("15 ans")
    expect(wrapper.text()).toContain("CNIL")
    expect(wrapper.text()).toContain("OVH SAS")
  })

  it("qualifie le deck illégal de format non officiel dans les CGU", async () => {
    const wrapper = await mountPage("/cgu")
    expect(wrapper.text()).toContain("format non officiel")
    expect(wrapper.text()).toContain("Illégal")
    expect(wrapper.text()).toContain(RIOT_DISCLAIMER_EN)
    expect(wrapper.text()).toContain(RIOT_GENERAL_DISCLAIMER_EN)
  })

  it("indique que les polices ne passent plus par Google Fonts", async () => {
    const wrapper = await mountPage("/cookies")
    expect(wrapper.text()).toContain("bandeau d'information")
    expect(wrapper.text()).toContain("pas par Google Fonts")
    expect(wrapper.text()).toContain("riftarium_session")
  })

  it("décrit le comptage de visites anonyme, agrégé et sans cookie", async () => {
    const wrapper = await mountPage("/cookies")
    expect(wrapper.text()).toContain("par jour et par rubrique")
    expect(wrapper.text()).toContain("sans aucune donnée personnelle ni cookie")
    expect(wrapper.text()).toContain("48 heures")
  })

  it("mentions : sommaire avec aria-current, ancres conservées", async () => {
    const wrapper = await mountPage("/mentions-legales")
    expect(wrapper.get("h1").text()).toBe("Mentions légales")
    expect(wrapper.find(".mentions-layout").exists()).toBe(true)
    expect(wrapper.text()).toContain("Mise à jour")
    const current = wrapper.get('.mentions-toc a[aria-current="page"]')
    expect(current.text()).toBe("Mentions légales")
    const anchors = wrapper.findAll('.mentions-toc a[href^="#"]')
    expect(anchors.map((a) => a.attributes("href"))).toEqual([
      "#editeur",
      "#hebergement",
      "#propriete-intellectuelle",
      "#code-source"
    ])
    for (const a of anchors) {
      const target = wrapper.find(a.attributes("href"))
      expect(target.exists()).toBe(true)
      expect(target.text()).toBe(a.text())
    }
    expect(wrapper.findAll(".mentions-quote").length).toBe(2)
  })

  it("chaque page légale expose un sommaire dont les ancres existent", async () => {
    for (const path of ["/confidentialite", "/cgu", "/cookies", "/signalement"]) {
      const wrapper = await mountPage(path)
      const anchors = wrapper.findAll('.mentions-toc a[href^="#"]')
      expect(anchors.length).toBeGreaterThan(1)
      expect(wrapper.findAll("h2").length).toBe(anchors.length)
      for (const a of anchors) expect(wrapper.find(a.attributes("href")).exists()).toBe(true)
      expect(wrapper.get('.mentions-toc a[aria-current="page"]').attributes("href")).toBe(path)
    }
  })

  it("sans ancre à l'arrivée, aucune entrée du sommaire n'est courante", async () => {
    const wrapper = await mountPage("/cgu")
    expect(wrapper.findAll('.mentions-toc a[href^="#"][aria-current]')).toHaveLength(0)
  })

  it("arrivée avec #droit : l'entrée correspondante est courante", async () => {
    const wrapper = await mountPage("/cgu#droit")
    const current = wrapper.findAll('.mentions-toc a[href^="#"][aria-current]')
    expect(current).toHaveLength(1)
    expect(current[0].attributes("href")).toBe("#droit")
    expect(current[0].attributes("aria-current")).toBe("location")
  })

  it("le clic sur une entrée la rend courante", async () => {
    const wrapper = await mountPage("/confidentialite")
    const links = wrapper.findAll('.mentions-toc a[href^="#"]')
    await links[2].trigger("click")
    const current = wrapper.findAll('.mentions-toc a[href^="#"][aria-current]')
    expect(current).toHaveLength(1)
    expect(current[0].attributes("href")).toBe(links[2].attributes("href"))
    await links[4].trigger("click")
    expect(wrapper.findAll('.mentions-toc a[href^="#"][aria-current]')[0].attributes("href")).toBe(
      links[4].attributes("href")
    )
  })

  it("sur toutes les pages légales, le libellé du sommaire est égal au texte du h2", async () => {
    for (const item of LEGAL_NAV) {
      const wrapper = await mountPage(item.path)
      const anchors = wrapper.findAll('.mentions-toc a[href^="#"]')
      expect(anchors.length).toBeGreaterThan(0)
      for (const a of anchors) {
        expect(wrapper.get(a.attributes("href")).text()).toBe(a.text())
      }
      wrapper.unmount()
    }
  })
})
