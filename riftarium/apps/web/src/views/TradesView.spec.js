import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import TradesView from "./TradesView.vue"
import Icon from "../components/Icon.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const PHOENIX = { id: "ogn-037-298", name: "Immortal Phoenix", image_url: "", domains: ["Fury"] }
const AHRI = { id: "ogn-119-298", name: "Ahri, Inquisitive", image_url: "", domains: ["Mind"] }

const ME_OFF = { handle: "moi", trade_enabled: false, trade_zone: null, trade_contact: null, notify_trades: true }
const ME_ON = { ...ME_OFF, trade_enabled: true, trade_zone: "sud", trade_contact: "Discord : moi" }

const OFFER = {
  offer_id: 7,
  owner: { handle: "bob", avatar_url: null, zone: "sud" },
  condition: "NM",
  lang: "FR",
  qty: 2,
  mutual: true,
  pending_request_id: null
}

const REQUEST_IN = {
  id: 11,
  box: "in",
  status: "pending",
  card: PHOENIX,
  condition: "NM",
  lang: "EN",
  message: "Je te propose un Lee Sin",
  other: { handle: "carl", avatar_url: null, zone: "nord" },
  contact: null,
  created_at: "2026-10-08T10:00:00Z"
}
const REQUEST_OUT = {
  ...REQUEST_IN,
  id: 12,
  box: "out",
  status: "accepted",
  card: AHRI,
  message: "",
  other: { handle: "bob", avatar_url: null, zone: "sud" },
  contact: "Discord : bob"
}

function setupApi({ me = ME_ON } = {}) {
  api.mockImplementation((path, options = {}) => {
    if (path === "/api/auth/me" && options.method === "PATCH") return Promise.resolve({ ...ME_ON, ...options.body })
    if (path === "/api/auth/me") return Promise.resolve(me)
    if (path.startsWith("/api/trades/matches/wanted"))
      return Promise.resolve({
        items: [{ card: PHOENIX, wanted_qty: 1, offers: [OFFER] }],
        total: 1,
        page: 1,
        size: 24
      })
    if (path.startsWith("/api/trades/matches/offered"))
      return Promise.resolve({
        items: [{ user: { handle: "dina", avatar_url: null, zone: "est" }, cards: [AHRI] }],
        total: 1,
        page: 1,
        size: 24
      })
    if (path === "/api/trades/offers")
      return Promise.resolve([
        { id: 3, entry_id: 30, card: AHRI, condition: "NM", lang: "EN", qty: 1, entry_qty: 2, created_at: null }
      ])
    if (path.startsWith("/api/trades/offers/")) return Promise.resolve(null)
    if (path.startsWith("/api/trades/requests?box=in")) return Promise.resolve({ items: [REQUEST_IN], total: 1 })
    if (path.startsWith("/api/trades/requests?box=out")) return Promise.resolve({ items: [REQUEST_OUT], total: 1 })
    if (path === "/api/trades/requests/summary") return Promise.resolve({ incoming_pending: 1 })
    if (path === "/api/trades/requests" && options.method === "POST")
      return Promise.resolve({ ...REQUEST_OUT, id: 99, status: "pending", contact: null })
    if (path.match(/^\/api\/trades\/requests\/\d+\/accept$/))
      return Promise.resolve({ ...REQUEST_IN, status: "accepted", contact: "Discord : carl" })
    return Promise.resolve(null)
  })
}

const lastCall = (fragment) => [...api.mock.calls].reverse().find(([path]) => String(path).includes(fragment))
const buttonWith = (scope, label) => scope.findAll("button").find((button) => button.text().includes(label))

async function mountView(path = "/echanges") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/echanges", component: TradesView },
      { path: "/u/:handle", component: { template: "<div />" } },
      { path: "/cartes/:id", component: { template: "<div />" } },
      { path: "/collection", component: { template: "<div />" } },
      { path: "/profil", component: { template: "<div />" } }
    ]
  })
  router.push(path)
  await router.isReady()
  const wrapper = mount(TradesView, {
    global: { plugins: [router], components: { Icon } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("TradesView", () => {
  beforeEach(() => {
    session.token = "1"
    session.handle = "moi"
    api.mockReset()
    setupApi()
    document.body.innerHTML = ""
  })

  it("explique le principe et active les échanges depuis la page", async () => {
    setupApi({ me: ME_OFF })
    const { wrapper } = await mountView()
    expect(wrapper.text()).toContain("La Réunion")
    expect(wrapper.find(".echanges-segments").exists()).toBe(false)

    await wrapper
      .findAll(".rift-choice button, [role=radio]")
      .find((el) => el.text() === "Sud")
      .trigger("click")
    await wrapper.get("input[type=text]").setValue("Discord : moi")
    await buttonWith(wrapper, "Activer les échanges").trigger("click")
    await flushPromises()

    expect(lastCall("/api/auth/me")[1]).toEqual({
      method: "PATCH",
      body: { trade_enabled: true, trade_zone: "sud", trade_contact: "Discord : moi" }
    })
    expect(wrapper.find(".echanges-segments").exists()).toBe(true)
  })

  it("montre les correspondances et envoie une demande avec un message", async () => {
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith(expect.stringContaining("/api/trades/matches/wanted"))
    const offerLine = wrapper.get(".offre")
    expect(offerLine.text()).toContain("bob")
    expect(offerLine.text()).toContain("Sud")
    expect(offerLine.text()).toContain("Échange possible")
    expect(wrapper.text()).toContain("dina")

    await buttonWith(offerLine, "Je suis intéressé").trigger("click")
    await flushPromises()
    const dialog = document.body.querySelector("[role=dialog]")
    expect(dialog.textContent).toContain("Immortal Phoenix")
    const textarea = dialog.querySelector("textarea")
    textarea.value = "Salut !"
    textarea.dispatchEvent(new Event("input"))
    ;[...dialog.querySelectorAll("button")].find((b) => b.textContent.includes("Envoyer")).click()
    await flushPromises()

    expect(lastCall("/api/trades/requests")[1]).toEqual({ method: "POST", body: { offer_id: 7, message: "Salut !" } })
    expect(wrapper.get(".offre").text()).toContain("Demande envoyée")
  })

  it("règle la quantité proposée d'une offre", async () => {
    const { wrapper } = await mountView("/echanges?onglet=offres")
    expect(wrapper.text()).toContain("Ahri, Inquisitive")
    await wrapper.get(".offres-liste [aria-label^='Ajouter un exemplaire']").trigger("click")
    await flushPromises()
    expect(lastCall("/api/trades/offers/30")[1]).toEqual({ method: "PUT", body: { qty: 2 } })
  })

  it("liste les demandes, accepte et ne montre le contact qu'après accord", async () => {
    const { wrapper } = await mountView("/echanges?onglet=demandes")
    const incoming = wrapper.get(".demande")
    expect(incoming.text()).toContain("carl")
    expect(incoming.text()).toContain("Je te propose un Lee Sin")
    expect(incoming.text()).not.toContain("Discord")

    await buttonWith(incoming, "Accepter").trigger("click")
    await flushPromises()
    expect(lastCall("/requests/11/accept")[1]).toEqual({ method: "POST" })
    expect(wrapper.get(".demande").text()).toContain("Discord : carl")

    await buttonWith(wrapper, "Envoyées").trigger("click")
    await flushPromises()
    const sentOne = wrapper.get(".demande")
    expect(sentOne.text()).toContain("Discord : bob")
    expect(buttonWith(sentOne, "Marquer comme fait")).toBeTruthy()
  })

  it("met en évidence la demande ouverte depuis un e-mail", async () => {
    const { wrapper } = await mountView("/echanges?onglet=demandes&id=11")
    expect(wrapper.get(".demande").classes()).toContain("ciblee")
  })
})
