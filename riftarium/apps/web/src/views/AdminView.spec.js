import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import AdminView from "./AdminView.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const statsFixture = {
  users: { total: 42, new_7d: 3, new_30d: 9, suspended: 1, verified: 40 },
  decks: { total: 18, public: 7, pending: 2, likes_total: 55, views_total: 640 },
  collection: { entries_total: 130, cards_total: 780 },
  cards: { total: 512, sets: 3 },
  visits: {
    today_hits: 24,
    hits_7d: 210,
    hits_30d: 900,
    uniques_today: 12,
    uniques_7d: 88,
    daily: [
      { day: "2026-08-18", hits: 30, uniques: 14 },
      { day: "2026-08-19", hits: 15, uniques: 8 }
    ],
    sections_7d: [
      { section: "cartes", hits: 120 },
      { section: "home", hits: 60 }
    ]
  },
  recent: {
    signups: [{ handle: "nova", created_at: "2026-08-18T10:00:00+00:00" }],
    decks: [
      {
        id: 5,
        name: "Contrôle Ordre",
        owner: "nova",
        moderation_status: "pending",
        created_at: "2026-08-18T11:00:00+00:00"
      }
    ]
  }
}

const usersFixture = {
  total: 2,
  page: 1,
  size: 20,
  items: [
    {
      id: 1,
      handle: "nyra",
      email: "nyra@example.org",
      created_at: "2026-01-15T10:00:00+00:00",
      email_verified: true,
      is_admin: false,
      suspended_until: null,
      suspension_reason: null,
      decks_count: 2,
      collection_count: 40
    },
    {
      id: 2,
      handle: "brume",
      email: "brume@example.org",
      created_at: "2026-03-02T10:00:00+00:00",
      email_verified: false,
      is_admin: false,
      suspended_until: "2026-08-25T10:00:00+00:00",
      suspension_reason: "Spam",
      decks_count: 0,
      collection_count: 0
    }
  ]
}

const decksFixture = {
  total: 1,
  page: 1,
  size: 20,
  items: [
    {
      id: 7,
      name: "Aggro Fureur",
      owner: "nyra",
      is_public: true,
      moderation_status: "pending",
      likes_count: 3,
      views_count: 12,
      updated_at: "2026-08-17T09:00:00+00:00"
    }
  ]
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/admin", component: AdminView },
      { path: "/decks/:id", component: { template: "<div />" } }
    ]
  })
  router.push("/admin")
  await router.isReady()
  const wrapper = mount(AdminView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

async function openTab(wrapper, index) {
  await wrapper.findAll(".admin-tabs .filter")[index].trigger("click")
  await flushPromises()
}

const modalEl = () => document.body.querySelector(".modal")

function setNativeValue(element, value, eventName) {
  element.value = value
  element.dispatchEvent(new Event(eventName, { bubbles: true }))
}

describe("AdminView", () => {
  beforeEach(() => {
    session.token = "1"
    session.handle = "admin"
    session.isAdmin = true
    api.mockReset()
    api.mockImplementation((path) => {
      if (path === "/api/admin/stats") return Promise.resolve(structuredClone(statsFixture))
      if (path.startsWith("/api/admin/users?")) return Promise.resolve(structuredClone(usersFixture))
      if (path.startsWith("/api/admin/decks?")) return Promise.resolve(structuredClone(decksFixture))
      return Promise.resolve(null)
    })
  })

  afterEach(() => {
    vi.useRealTimers()
    document.body.innerHTML = ""
  })

  it("affiche les statistiques, la fréquentation et les listes récentes", async () => {
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/admin/stats")
    expect(wrapper.text()).toContain("Utilisateurs")
    expect(wrapper.text()).toContain("42")
    expect(wrapper.text()).toContain("E-mails vérifiés")
    expect(wrapper.text()).toContain("Dernières inscriptions")
    expect(wrapper.text()).toContain("nova")
    expect(wrapper.text()).toContain("Contrôle Ordre")
    /* Statut de modération en badge sur les derniers decks. */
    expect(wrapper.find(".admin-badge.is-wait").text()).toBe("En attente")
    /* Fréquentation : chiffres + histogramme CSS + rubriques. */
    expect(wrapper.text()).toContain("Fréquentation")
    expect(wrapper.text()).toContain("210")
    expect(wrapper.findAll(".admin-histo-bar")).toHaveLength(2)
    expect(wrapper.findAll(".admin-histo-bar")[0].get("i").attributes("style")).toContain("height: 100%")
    expect(wrapper.get(".admin-sections").text()).toContain("Cartothèque")
    wrapper.unmount()
  })

  it("onglet Utilisateurs : liste, badges, et recherche débouncée avec q", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/users?") && path.includes("page_size=20"))).toBe(
      true
    )
    expect(wrapper.text()).toContain("nyra@example.org")
    expect(wrapper.text()).toContain("2 decks · 40 cartes")
    expect(wrapper.findAll(".admin-badge.is-ko")).toHaveLength(1)
    expect(wrapper.text()).toContain("Suspendu jusqu'au")

    api.mockClear()
    vi.useFakeTimers()
    await wrapper.get("input[type=search]").setValue("nyra")
    await vi.advanceTimersByTimeAsync(300)
    vi.useRealTimers()
    await flushPromises()
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/users?") && path.includes("q=nyra"))).toBe(true)
    wrapper.unmount()
  })

  it("suspension : la modale envoie hours et reason puis recharge la liste", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)

    const buttons = wrapper.findAll(".admin-row")[0].findAll("button")
    await buttons.find((button) => button.text() === "Suspendre").trigger("click")
    const modal = modalEl()
    expect(modal).not.toBeNull()

    setNativeValue(modal.querySelector("textarea"), "Propos injurieux", "input")
    setNativeValue(modal.querySelector("select"), "168", "change")
    api.mockClear()
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()

    expect(api).toHaveBeenCalledWith("/api/admin/users/1/suspend", {
      method: "POST",
      body: { hours: 168, reason: "Propos injurieux" }
    })
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/users?"))).toBe(true)
    expect(modalEl()).toBeNull()
    wrapper.unmount()
  })

  it("lève une suspension et affiche le detail d'erreur près de la ligne en cas d'échec", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)

    const rows = wrapper.findAll(".admin-row")
    const lift = rows[1].findAll("button").find((button) => button.text() === "Lever la suspension")
    expect(lift).toBeTruthy()
    api.mockImplementationOnce(() => Promise.reject(new Error("Suspension introuvable")))
    await lift.trigger("click")
    await flushPromises()
    expect(wrapper.get(".admin-row-error").text()).toBe("Suspension introuvable")

    await lift.trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/users/2/suspend", { method: "DELETE" })
    wrapper.unmount()
  })

  it("suppression d'un compte : exige le pseudo exact avant d'appeler l'API", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)

    const buttons = wrapper.findAll(".admin-row")[0].findAll("button")
    await buttons.find((button) => button.text() === "Supprimer").trigger("click")
    const modal = modalEl()
    expect(modal).not.toBeNull()
    expect(modal.textContent).toContain("nyra")

    api.mockClear()
    setNativeValue(modal.querySelector("input[type=text]"), "autre", "input")
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()
    expect(api).not.toHaveBeenCalled()
    expect(modal.textContent).toContain("Le pseudo saisi ne correspond pas.")

    setNativeValue(modal.querySelector("input[type=text]"), "nyra", "input")
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/users/1", { method: "DELETE" })
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/users?"))).toBe(true)
    wrapper.unmount()
  })

  it("onglet Decks : file « En attente » par défaut, approuver et rejeter", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 2)
    expect(
      api.mock.calls.some(([path]) => path.startsWith("/api/admin/decks?") && path.includes("status=pending"))
    ).toBe(true)
    const link = wrapper.get(".admin-deck-name")
    expect(link.text()).toBe("Aggro Fureur")
    expect(link.attributes("href")).toBe("/decks/7")

    api.mockClear()
    const row = wrapper.findAll(".admin-row")[0]
    await row
      .findAll("button")
      .find((button) => button.text() === "Approuver")
      .trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/decks/7/moderation", { method: "POST", body: { status: "approved" } })
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/decks?"))).toBe(true)

    api.mockClear()
    await wrapper
      .findAll(".admin-row")[0]
      .findAll("button")
      .find((button) => button.text() === "Rejeter")
      .trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/decks/7/moderation", { method: "POST", body: { status: "rejected" } })
    wrapper.unmount()
  })

  it("suppression d'un deck : passe par une modale de confirmation puis recharge", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 2)

    api.mockClear()
    await wrapper
      .findAll(".admin-row")[0]
      .findAll("button")
      .find((button) => button.text() === "Supprimer")
      .trigger("click")
    const modal = modalEl()
    expect(modal).not.toBeNull()
    expect(api).not.toHaveBeenCalled()

    const confirm = [...modal.querySelectorAll("button")].find((button) => button.textContent.trim() === "Supprimer")
    confirm.click()
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/decks/7", { method: "DELETE" })
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/decks?"))).toBe(true)
    expect(modalEl()).toBeNull()
    wrapper.unmount()
  })
})
