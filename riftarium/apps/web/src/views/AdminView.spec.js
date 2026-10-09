import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import AdminView from "./AdminView.vue"
import { api, session } from "../api.js"
import { lastDays } from "../components/charts/chartUtils.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

/* Axe de 30 jours zéro-remplis (comme le backend), se terminant le 19 août. */
const seriesDays = lastDays(30, "2026-08-19")

const statsFixture = {
  users: { total: 42, new_7d: 3, new_30d: 9, suspended: 1, verified: 40 },
  decks: { total: 18, public: 7, pending: 2, published: 12, rejected: 4, likes_total: 55, views_total: 640 },
  collection: { entries_total: 130, cards_total: 780 },
  cards: { total: 512, sets: 3 },
  visits: {
    today_hits: 24,
    hits_7d: 210,
    hits_30d: 900,
    uniques_today: 12,
    uniques_7d: 88,
    /* Volontairement à trous : le zéro-remplissage sur 30 jours se fait côté client. */
    daily: [
      { day: "2026-08-18", hits: 30, uniques: 14 },
      { day: "2026-08-19", hits: 15, uniques: 8 }
    ],
    sections_7d: [
      { section: "cartes", hits: 120 },
      { section: "home", hits: 60 }
    ]
  },
  series: {
    signups_daily: seriesDays.map((day) => ({ day, count: day === "2026-08-19" ? 2 : 0 })),
    decks_daily: seriesDays.map((day) => ({ day, count: day === "2026-08-19" ? 3 : day === "2026-08-17" ? 1 : 0 }))
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
    global: { plugins: [router], stubs: { Icon: true } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

async function openTab(wrapper, index) {
  await wrapper.findAll("[role=tab]")[index].trigger("click")
  await flushPromises()
}

/* Couleur d'une puce statique (RiftChip static selected color=…). */
const chipColor = (chip) => chip.attributes("style") || ""
const rowChips = (row) => row.findAll(".rift-chip")
/* Panneau d'onglet visible : les onglets déjà visités restent montés, masqués par v-show. */
const visiblePanel = (wrapper) => wrapper.findAll("[role=tabpanel]").find((panel) => panel.isVisible())

const modalEl = () => document.body.querySelector(".rift-modal")

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
    /* Statut de modération en puce statique sur les derniers decks (attente : --ink-muted). */
    const chip = wrapper.get(".console-recent .rift-chip")
    expect(chip.text()).toBe("En attente")
    expect(chip.element.tagName).toBe("SPAN")
    expect(chipColor(chip)).toContain("var(--ink-muted)")
    /* Deltas 7 j sous les tuiles Total (utilisateurs : new_7d ; decks : somme de la série). */
    const deltas = wrapper.findAll(".console-delta").map((node) => node.text())
    expect(deltas).toContain("+3 (7 j)")
    expect(deltas).toContain("+4 (7 j)")
    expect(wrapper.text()).toContain("210")
    wrapper.unmount()
  })

  it("trace les graphiques : fréquentation zéro-remplie, séries 30 j, rubriques et modération", async () => {
    const { wrapper } = await mountView()
    const figures = wrapper.findAll("figure.graphe-figure")

    /* Fréquentation : 30 colonnes malgré 2 jours de données (zéro-remplissage client), 2 séries → légende. */
    const frequentation = figures.find((figure) => figure.text().includes("Fréquentation (30 jours)"))
    expect(frequentation).toBeTruthy()
    expect(frequentation.findAll(".graphe-band")).toHaveLength(30)
    expect(frequentation.get("polyline").attributes("stroke")).toBe("var(--blood-bright)")
    expect(frequentation.findAll(".graphe-legend .graphe-key").map((key) => key.text())).toEqual([
      "Visites",
      "Visiteurs uniques"
    ])

    /* Séries serveur : inscriptions et decks créés, 30 colonnes chacune. */
    const inscriptions = figures.find((figure) => figure.text().includes("Inscriptions (30 jours)"))
    expect(inscriptions.findAll(".graphe-band")).toHaveLength(30)
    const decksCrees = figures.find((figure) => figure.text().includes("Decks créés (30 jours)"))
    expect(decksCrees.findAll(".graphe-band")).toHaveLength(30)

    /* Rubriques : barres horizontales avec libellés traduits et valeurs directes. */
    const rubriques = figures.find((figure) => figure.text().includes("Rubriques les plus visitées"))
    expect(rubriques.findAll(".graphe-bar")).toHaveLength(2)
    expect(rubriques.findAll(".graphe-row-label").map((node) => node.text())).toEqual(["Cartes", "Accueil"])
    expect(rubriques.findAll(".graphe-value-text").map((node) => node.text())).toEqual(["120", "60"])

    /* Modération : barre empilée avec légende comptée. */
    const moderation = figures.find((figure) => figure.text().includes("Statuts de modération"))
    expect(moderation.findAll(".graphe-segment")).toHaveLength(3)
    expect(moderation.findAll(".graphe-legend .graphe-key").map((key) => key.text())).toEqual([
      "Publiés 12",
      "En attente 2",
      "Rejetés 4"
    ])

    /* Chaque graphique offre son alternative texte. */
    const toggle = frequentation.get(".graphe-toggle")
    await toggle.trigger("click")
    expect(frequentation.findAll(".graphe-table tbody tr")).toHaveLength(30)
    wrapper.unmount()
  })

  it("masque la barre des statuts de modération quand le total vaut zéro", async () => {
    api.mockImplementation((path) => {
      if (path === "/api/admin/stats") {
        const fixture = structuredClone(statsFixture)
        fixture.decks.published = 0
        fixture.decks.pending = 0
        fixture.decks.rejected = 0
        return Promise.resolve(fixture)
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    expect(wrapper.text()).not.toContain("Statuts de modération")
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
    const suspended = wrapper.findAll(".console-row .rift-chip").filter((c) => chipColor(c).includes("--blood-text"))
    expect(suspended).toHaveLength(1)
    expect(suspended[0].attributes("title")).toBe("Spam")
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

    const buttons = wrapper.findAll(".console-row")[0].findAll("button")
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

    const rows = wrapper.findAll(".console-row")
    const lift = rows[1].findAll("button").find((button) => button.text() === "Lever la suspension")
    expect(lift).toBeTruthy()
    api.mockImplementationOnce(() => Promise.reject(new Error("Suspension introuvable")))
    await lift.trigger("click")
    await flushPromises()
    expect(wrapper.get(".console-row-error").text()).toBe("Suspension introuvable")
    expect(wrapper.get(".console-row-error").attributes("role")).toBe("alert")
    expect(wrapper.findAll(".console-row")[1].find(".console-row-error").exists()).toBe(true)

    await lift.trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/users/2/suspend", { method: "DELETE" })
    wrapper.unmount()
  })

  it("suppression d'un compte : exige le pseudo exact avant d'appeler l'API", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)

    const buttons = wrapper.findAll(".console-row")[0].findAll("button")
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
    const link = wrapper.get(".console-deck-name")
    expect(link.text()).toBe("Aggro Fureur")
    expect(link.attributes("href")).toBe("/decks/7")

    api.mockClear()
    const row = wrapper.findAll(".console-row")[0]
    await row
      .findAll("button")
      .find((button) => button.text() === "Approuver")
      .trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/decks/7/moderation", { method: "POST", body: { status: "approved" } })
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/decks?"))).toBe(true)

    api.mockClear()
    await wrapper
      .findAll(".console-row")[0]
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
      .findAll(".console-row")[0]
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

  it("page : h1 « Administration », sans bandeau illustré", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.get("h1").text()).toBe("Administration")
    expect(wrapper.find(".page-banner").exists()).toBe(false)
    const tabs = wrapper.findAll("[role=tab]")
    expect(tabs.map((tab) => tab.text())).toEqual(["Statistiques", "Utilisateurs", "Decks"])
    expect(tabs[0].attributes("aria-selected")).toBe("true")
    expect(visiblePanel(wrapper).attributes("aria-labelledby")).toBe(tabs[0].attributes("id"))
    wrapper.unmount()
  })

  it("onglets : RiftSegments au clavier", async () => {
    const { wrapper } = await mountView()
    const tabs = () => wrapper.findAll("[role=tab]")
    expect(wrapper.get("[role=tablist]").attributes("aria-label")).toBe("Sections d'administration")
    api.mockClear()
    await tabs()[0].trigger("keydown", { key: "ArrowRight" })
    await flushPromises()
    expect(tabs()[1].attributes("aria-selected")).toBe("true")
    expect(document.activeElement).toBe(tabs()[1].element)
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/users?"))).toBe(true)
    expect(visiblePanel(wrapper).attributes("id")).toContain("users")

    await tabs()[1].trigger("keydown", { key: "End" })
    await flushPromises()
    expect(tabs()[2].attributes("aria-selected")).toBe("true")
    expect(api.mock.calls.some(([path]) => path.startsWith("/api/admin/decks?"))).toBe(true)

    await tabs()[2].trigger("keydown", { key: "ArrowRight" })
    await flushPromises()
    expect(tabs()[0].attributes("aria-selected")).toBe("true")
    expect(api).toHaveBeenCalledWith("/api/admin/stats")
    wrapper.unmount()
  })

  it("graphiques : couleurs en tokens, aucune var(--chart-…)", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.html()).not.toContain("--chart-")
    const figures = wrapper.findAll("figure.graphe-figure")
    const byTitle = (title) => figures.find((figure) => figure.text().includes(title))

    /* Volume en bronze, uniques en sang vif, inscriptions en bronze clair, troisième série en encre atténuée. */
    const frequentation = byTitle("Fréquentation (30 jours)")
    expect(frequentation.get(".graphe-col").attributes("fill")).toBe("var(--bronze)")
    expect(frequentation.get("polyline").attributes("stroke")).toBe("var(--blood-bright)")
    expect(byTitle("Inscriptions (30 jours)").get(".graphe-col").attributes("fill")).toBe("var(--bronze-light)")
    expect(byTitle("Decks créés (30 jours)").get(".graphe-col").attributes("fill")).toBe("var(--ink-muted)")
    expect(byTitle("Rubriques les plus visitées").get(".graphe-bar").attributes("fill")).toBe("var(--bronze)")

    /* Statuts : ok bronze clair, attente encre atténuée, ko sang. */
    const fills = byTitle("Statuts de modération")
      .findAll(".graphe-segment")
      .map((segment) => segment.attributes("fill"))
    expect(fills).toEqual(["var(--bronze-light)", "var(--ink-muted)", "var(--blood)"])
    wrapper.unmount()
  })

  it("tableaux denses : en-têtes, intitulés de cellule et actions compactes", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 2)
    const table = wrapper.get("table.console-table")
    expect(table.findAll("thead th").map((th) => th.text())).toEqual(["Deck", "Statut", "Activité", "Actions"])
    const row = wrapper.findAll(".console-row")[0]
    /* Chaque cellule porte son intitulé pour l'empilement en carte sous 768 px. */
    expect(row.findAll("td").every((td) => td.attributes("data-label"))).toBe(true)
    const status = rowChips(row)[0]
    expect(status.text()).toBe("En attente")
    expect(chipColor(status)).toContain("var(--ink-muted)")
    expect(row.findAll(".rift-btn--sm").length).toBeGreaterThanOrEqual(2)
    wrapper.unmount()
  })

  it("statuts de deck : publié en bronze clair, rejeté en encre de sang", async () => {
    api.mockImplementation((path) => {
      if (path.startsWith("/api/admin/decks?")) {
        const fixture = structuredClone(decksFixture)
        fixture.items.push(
          { ...fixture.items[0], id: 8, name: "Rampe", moderation_status: "published" },
          { ...fixture.items[0], id: 9, name: "Spam", moderation_status: "rejected" }
        )
        return Promise.resolve(fixture)
      }
      if (path === "/api/admin/stats") return Promise.resolve(structuredClone(statsFixture))
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    await openTab(wrapper, 2)
    const rows = wrapper.findAll(".console-row")
    expect(rowChips(rows[1])[0].text()).toBe("Publié")
    expect(chipColor(rowChips(rows[1])[0])).toContain("var(--bronze-light)")
    expect(rowChips(rows[2])[0].text()).toBe("Rejeté")
    expect(chipColor(rowChips(rows[2])[0])).toContain("var(--blood-text)")
    /* Un deck publié ne propose plus « Approuver », un deck rejeté plus « Rejeter ». */
    expect(rows[1].findAll("button").map((b) => b.text())).not.toContain("Approuver")
    expect(rows[2].findAll("button").map((b) => b.text())).not.toContain("Rejeter")
    wrapper.unmount()
  })

  it("modération en échec : erreur sur la ligne, statut inchangé", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 2)
    api.mockClear()
    api.mockImplementationOnce(() => Promise.reject(new Error("Deck introuvable")))
    await wrapper
      .findAll(".console-row")[0]
      .findAll("button")
      .find((button) => button.text() === "Approuver")
      .trigger("click")
    await flushPromises()

    expect(api).toHaveBeenCalledTimes(1)
    expect(api).toHaveBeenCalledWith("/api/admin/decks/7/moderation", { method: "POST", body: { status: "approved" } })
    const row = wrapper.findAll(".console-row")[0]
    const error = row.get(".console-row-error")
    expect(error.attributes("role")).toBe("alert")
    expect(error.text()).toBe("Deck introuvable")
    expect(rowChips(row)[0].text()).toBe("En attente")
    /* Les actions redeviennent disponibles. */
    expect(row.findAll("button").every((b) => b.attributes("disabled") === undefined)).toBe(true)
    wrapper.unmount()
  })

  it("sanction définitive : modale de confirmation, annuler n'envoie rien", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)

    const openModal = async () => {
      await wrapper
        .findAll(".console-row")[0]
        .findAll("button")
        .find((button) => button.text() === "Suspendre")
        .trigger("click")
      const modal = modalEl()
      setNativeValue(modal.querySelector("textarea"), "Triche répétée", "input")
      setNativeValue(modal.querySelector("select"), "876000", "change")
      await flushPromises()
      modal.querySelector("form").dispatchEvent(new Event("submit"))
      await flushPromises()
      return modalEl()
    }

    api.mockClear()
    let modal = await openModal()
    /* Première validation : aucune requête, la modale demande confirmation. */
    expect(api).not.toHaveBeenCalled()
    expect(modal.textContent).toContain("définitive")
    expect(modal.querySelector("form")).toBeNull()
    /* Le focus passe sur l'avertissement, jamais sur le bouton qui envoie la sanction. */
    expect(document.activeElement).toBe(modal.querySelector(".console-confirm"))
    expect(document.activeElement.textContent).not.toContain("Suspendre définitivement")
    const cancel = [...modal.querySelectorAll("button")].find((b) => b.textContent.trim() === "Annuler")
    cancel.click()
    await flushPromises()
    expect(modalEl()).toBeNull()
    expect(api).not.toHaveBeenCalled()

    /* Confirmée, la sanction part avec les 876000 h et le motif. */
    modal = await openModal()
    const confirm = [...modal.querySelectorAll("button")].find((b) =>
      b.textContent.includes("Suspendre définitivement")
    )
    confirm.click()
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/users/1/suspend", {
      method: "POST",
      body: { hours: 876000, reason: "Triche répétée" }
    })
    expect(modalEl()).toBeNull()
    wrapper.unmount()
  })

  async function reachPermanentConfirmation(wrapper) {
    await wrapper
      .findAll(".console-row")[0]
      .findAll("button")
      .find((button) => button.text() === "Suspendre")
      .trigger("click")
    const modal = modalEl()
    setNativeValue(modal.querySelector("textarea"), "Triche répétée", "input")
    setNativeValue(modal.querySelector("select"), "876000", "change")
    await flushPromises()
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()
    return modalEl()
  }

  it("sanction définitive : Échap pendant la confirmation ferme sans rien envoyer", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)
    api.mockClear()
    const modal = await reachPermanentConfirmation(wrapper)
    expect(modal.querySelector(".console-confirm")).not.toBeNull()

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await flushPromises()
    expect(modalEl()).toBeNull()
    expect(api).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("sanction définitive : « Retour » revient au formulaire en gardant motif et durée", async () => {
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)
    api.mockClear()
    let modal = await reachPermanentConfirmation(wrapper)
    const back = [...modal.querySelectorAll("button")].find((b) => b.textContent.trim() === "Retour")
    back.click()
    await flushPromises()

    modal = modalEl()
    expect(modal).not.toBeNull()
    expect(modal.querySelector(".console-confirm")).toBeNull()
    expect(modal.querySelector("textarea").value).toBe("Triche répétée")
    expect(modal.querySelector("select").value).toBe("876000")
    expect(document.activeElement).toBe(modal.querySelector("select"))
    expect(api).not.toHaveBeenCalled()

    /* Une durée temporaire choisie au retour part sans étape de confirmation. */
    setNativeValue(modal.querySelector("select"), "720", "change")
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/admin/users/1/suspend", {
      method: "POST",
      body: { hours: 720, reason: "Triche répétée" }
    })
    wrapper.unmount()
  })

  it("onglets : recherche, filtre et page conservés, données rechargées à l'activation", async () => {
    api.mockImplementation((path) => {
      if (path === "/api/admin/stats") return Promise.resolve(structuredClone(statsFixture))
      if (path.startsWith("/api/admin/users?")) return Promise.resolve({ ...structuredClone(usersFixture), total: 45 })
      if (path.startsWith("/api/admin/decks?")) return Promise.resolve(structuredClone(decksFixture))
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    await openTab(wrapper, 1)
    const usersPanel = () => wrapper.get("#console-panel-users")
    const decksPanel = () => wrapper.get("#console-panel-decks")

    vi.useFakeTimers()
    await usersPanel().get("input[type=search]").setValue("nyra")
    await vi.advanceTimersByTimeAsync(300)
    await usersPanel()
      .findAll("button")
      .find((button) => button.text().includes("Suivant"))
      .trigger("click")
    await vi.advanceTimersByTimeAsync(300)
    vi.useRealTimers()
    await flushPromises()
    expect(usersPanel().text()).toContain("page 2 / 3")

    await openTab(wrapper, 2)
    vi.useFakeTimers()
    await decksPanel()
      .findAll(".rift-chip")
      .find((chip) => chip.text() === "Publiés")
      .trigger("click")
    await vi.advanceTimersByTimeAsync(300)
    vi.useRealTimers()
    await flushPromises()

    /* Retour sur Utilisateurs : même recherche, même page, liste rechargée. */
    api.mockClear()
    await openTab(wrapper, 1)
    expect(usersPanel().get("input[type=search]").element.value).toBe("nyra")
    expect(usersPanel().text()).toContain("page 2 / 3")
    const usersCalls = api.mock.calls.filter(([path]) => path.startsWith("/api/admin/users?"))
    expect(usersCalls).toHaveLength(1)
    expect(usersCalls[0][0]).toContain("q=nyra")
    expect(usersCalls[0][0]).toContain("page=2")

    /* Retour sur Decks : même filtre, file rechargée. */
    api.mockClear()
    await openTab(wrapper, 2)
    const published = decksPanel()
      .findAll(".rift-chip")
      .find((chip) => chip.text() === "Publiés")
    expect(published.attributes("aria-pressed")).toBe("true")
    const decksCalls = api.mock.calls.filter(([path]) => path.startsWith("/api/admin/decks?"))
    expect(decksCalls).toHaveLength(1)
    expect(decksCalls[0][0]).toContain("status=published")

    /* Retour sur Statistiques : rechargées aussi. */
    api.mockClear()
    await openTab(wrapper, 0)
    expect(api).toHaveBeenCalledWith("/api/admin/stats")
    wrapper.unmount()
  })
})
