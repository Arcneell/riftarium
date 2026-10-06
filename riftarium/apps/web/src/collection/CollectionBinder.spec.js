import { flushPromises, mount } from "@vue/test-utils"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CollectionBinder from "./CollectionBinder.vue"
import { api } from "../api.js"
import { makeRouter } from "../test/makeRouter.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function fakeCard(index, ownedQty) {
  return {
    id: `card-${index}`,
    riftbound_id: `ogn-00${index}-298`,
    name: `Carte ${index}`,
    image_url: `https://cdn.example/${index}.png`,
    domains: ["Fury"],
    type: "Unit",
    rarity: "Epic",
    price_eur: 2.5,
    owned_qty: ownedQty
  }
}

const PROGRESS = {
  sets: [
    { set_id: "OGN", name: "Origins", total: 298, owned: 149, missing: 149, missing_cost_eur: 42.5 },
    { set_id: "SFD", name: "Spirit Forged", total: 100, owned: 100, missing: 0, missing_cost_eur: null }
  ],
  overall: { total: 398, owned: 249, missing: 149, missing_cost_eur: 42.5 }
}

async function mountBinder(progress = PROGRESS) {
  const router = await makeRouter("/collection")
  const wrapper = mount(CollectionBinder, {
    props: { progress, active: true },
    global: { plugins: [router], components: { Icon: { template: "<i />" } } },
    attachTo: document.body
  })
  await flushPromises()
  await flushPromises()
  return wrapper
}

describe("CollectionBinder", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation(() =>
      Promise.resolve({ total: 298, page: 1, size: 18, items: [fakeCard(1, 3), fakeCard(9, 0)] })
    )
  })

  it("classeur par défaut : ouvre le premier set incomplet, pochettes pleines et fantômes", async () => {
    const wrapper = await mountBinder()

    const tabs = wrapper.findAll(".classeur-tab")
    expect(tabs).toHaveLength(2)
    expect(tabs[0].text()).toContain("Origins")
    expect(tabs[0].text()).toContain("50 %")
    expect(tabs[0].attributes("aria-pressed")).toBe("true")
    expect(tabs[1].text()).toContain("✓")

    expect(wrapper.get("h2").text()).toBe("Origins")
    expect(wrapper.get(".classeur-sub").text()).toContain("149/298")
    expect(wrapper.get(".classeur-sub").text()).toContain("il manque 149 carte(s) (~42,50")

    expect(
      api.mock.calls.some(([path]) => String(path).includes("set_id=OGN") && String(path).includes("size=18"))
    ).toBe(true)

    expect(wrapper.findAll(".classeur-pocket")).toHaveLength(18)
    expect(wrapper.get(".classeur-pocket .classeur-qty").text()).toBe("×3")

    const ghost = wrapper.get(".classeur-pocket.ghost")
    expect(ghost.attributes("href")).toBe("/cartes/card-9")
    expect(ghost.attributes("title")).toBe("Carte manquante : Carte 9")
    expect(ghost.get("img").attributes("alt")).toBe("Carte manquante : Carte 9")
    expect(ghost.get(".classeur-num").text()).toBe("OGN-009-298")
    expect(ghost.get(".classeur-price").text()).toContain("2,50")
    wrapper.unmount()
  })

  it("collection vide : RiftEmpty avec lien vers /cartes, pas de double page", async () => {
    const wrapper = await mountBinder({
      sets: [{ set_id: "OGN", name: "Origins", total: 298, owned: 0, missing: 298, missing_cost_eur: 99 }],
      overall: { total: 298, owned: 0, missing: 298, missing_cost_eur: 99 }
    })
    expect(wrapper.get(".rift-empty").text()).toContain("Votre classeur attend ses premières cartes")
    expect(wrapper.get(".rift-empty a").attributes("href")).toBe("/cartes")
    expect(wrapper.find(".classeur-pocket").exists()).toBe(false)
    expect(wrapper.find(".classeur-spread").exists()).toBe(false)
    expect(api).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("sets : boutons aria-pressed dans un groupe, sans rôle tablist ni tab", async () => {
    const wrapper = await mountBinder()
    const group = wrapper.get('[role="group"][aria-label="Sets du classeur"]')
    expect(wrapper.find("[role=tablist]").exists()).toBe(false)
    expect(wrapper.find("[role=tab]").exists()).toBe(false)
    expect(group.findAll("button")).toHaveLength(2)
    wrapper.unmount()
  })

  it("set complet : ✓ lisible par un lecteur d'écran, aria-pressed au clic", async () => {
    const wrapper = await mountBinder()
    const done = wrapper.findAll(".classeur-tab")[1]
    expect(done.text()).toContain("✓")
    expect(done.text()).not.toContain("%")
    expect(done.get(".sr-only").text()).toContain("set complet")
    expect(done.attributes("aria-pressed")).toBe("false")
    await done.trigger("click")
    await flushPromises()
    expect(wrapper.findAll(".classeur-tab")[1].attributes("aria-pressed")).toBe("true")
    expect(wrapper.findAll(".classeur-tab")[0].attributes("aria-pressed")).toBe("false")
    wrapper.unmount()
  })

  it("le compteur X / Y est annoncé poliment", async () => {
    const wrapper = await mountBinder()
    expect(wrapper.get(".classeur-count").attributes("aria-live")).toBe("polite")
    wrapper.unmount()
  })

  it("progression indisponible : message d'erreur à la place du squelette sans fin", async () => {
    const router = await makeRouter("/collection")
    const wrapper = mount(CollectionBinder, {
      props: { progress: null, progressError: "Serveur indisponible", active: true },
      global: { plugins: [router], components: { Icon: { template: "<i />" } } }
    })
    await flushPromises()
    expect(wrapper.get("[role=alert]").text()).toContain("Serveur indisponible")
    expect(wrapper.find(".shimmer").exists()).toBe(false)
    wrapper.unmount()
  })

  it("navigation désactivée aux bornes", async () => {
    const wrapper = await mountBinder()
    const prev = wrapper.get('[aria-label="Double page précédente"]')
    const next = wrapper.get('[aria-label="Double page suivante"]')
    expect(prev.attributes("disabled")).toBeDefined()
    expect(next.attributes("disabled")).toBeUndefined()
    await next.trigger("click")
    await flushPromises()
    expect(wrapper.get('[aria-label="Double page précédente"]').attributes("disabled")).toBeUndefined()
    wrapper.unmount()
  })

  it("flèches bloquées quand une modale est ouverte (nav-locked)", async () => {
    const wrapper = await mountBinder()
    api.mockClear()
    document.body.classList.add("nav-locked")
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight" }))
    await flushPromises()
    expect(api).not.toHaveBeenCalled()
    expect(wrapper.get(".classeur-count").text()).toBe("1 / 17")
    document.body.classList.remove("nav-locked")
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight" }))
    await flushPromises()
    expect(api).toHaveBeenCalled()
    wrapper.unmount()
  })

  it("flèches : un bouton de set focalisé n'a pas de flèches natives, la double page tourne", async () => {
    const wrapper = await mountBinder()
    api.mockClear()
    wrapper
      .findAll(".classeur-tab")[0]
      .element.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true }))
    await flushPromises()
    expect(api.mock.calls.some(([path]) => String(path).includes("page=2"))).toBe(true)
    wrapper.unmount()
  })

  it("version : invalide la double page et la recharge quand le classeur est actif", async () => {
    const wrapper = await mountBinder()
    api.mockClear()
    await wrapper.setProps({ version: 1 })
    await flushPromises()
    expect(api.mock.calls.filter(([path]) => String(path).startsWith("/api/cards?"))).toHaveLength(1)
    wrapper.unmount()
  })

  it("version : classeur inactif, le rechargement attend la prochaine activation", async () => {
    const wrapper = await mountBinder()
    await wrapper.setProps({ active: false })
    api.mockClear()
    await wrapper.setProps({ version: 1 })
    await flushPromises()
    expect(api).not.toHaveBeenCalled()
    await wrapper.setProps({ active: true })
    await flushPromises()
    expect(api.mock.calls.filter(([path]) => String(path).startsWith("/api/cards?"))).toHaveLength(1)
    wrapper.unmount()
  })

  it("une seule page : pas de navigation", async () => {
    api.mockImplementation(() => Promise.resolve({ total: 5, page: 1, size: 18, items: [fakeCard(1, 1)] }))
    const wrapper = await mountBinder()
    expect(wrapper.find(".classeur-nav").exists()).toBe(false)
    wrapper.unmount()
  })
})
