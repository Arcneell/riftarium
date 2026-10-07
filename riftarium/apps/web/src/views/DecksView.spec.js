import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import DecksView from "./DecksView.vue"
import { api } from "../api.js"
import { resetPlayStats } from "../composables/usePlayStats.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/decks", component: DecksView },
      { path: "/decks/:id", component: { template: "<div />" } }
    ]
  })
  router.push("/decks")
  await router.isReady()
  const wrapper = mount(DecksView, {
    global: { plugins: [router], stubs: { Icon: true } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("DecksView", () => {
  beforeEach(() => {
    /* Le bilan des parties est mis en cache au niveau du module : on repart à zéro. */
    resetPlayStats()
    api.mockReset()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/mine") return Promise.resolve([])
      if (path === "/api/decks" && options.method === "POST") return Promise.resolve({ id: 7 })
      if (path === "/api/decks/example" && options.method === "POST") return Promise.resolve({ id: 9 })
      if (options.method === "DELETE") return Promise.resolve(null)
      return Promise.resolve(null)
    })
  })

  it("ouvre la modale de création puis navigue vers l'éditeur", async () => {
    const { wrapper, router } = await mountView()
    expect(document.body.querySelector(".rift-modal")).toBeNull()

    await wrapper.get(".mesdecks-new").trigger("click")
    const modal = document.body.querySelector(".rift-modal")
    expect(modal).not.toBeNull()
    expect(modal.textContent).toContain("Nouveau deck")

    const nameInput = modal.querySelector("input[type=text]")
    nameInput.value = "Fureur de Noxus"
    nameInput.dispatchEvent(new Event("input"))
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()

    const call = api.mock.calls.find(([path, options]) => path === "/api/decks" && options?.method === "POST")
    expect(call[1].body.name).toBe("Fureur de Noxus")
    expect(call[1].body.format).toBe("tournament")
    expect(router.currentRoute.value.path).toBe("/decks/7")
    wrapper.unmount()
  })

  it("génère un deck d'exemple depuis la modale", async () => {
    const { wrapper, router } = await mountView()
    await wrapper.get(".mesdecks-new").trigger("click")
    const modal = document.body.querySelector(".rift-modal")
    const ownedButton = [...modal.querySelectorAll(".mesdecks-examples button")].find((b) =>
      b.textContent.includes("Avec ma collection")
    )
    ownedButton.click()
    await flushPromises()

    const call = api.mock.calls.find(([path]) => path === "/api/decks/example")
    expect(call[1].body).toEqual({ mode: "owned" })
    expect(router.currentRoute.value.path).toBe("/decks/9")
    wrapper.unmount()
  })

  it("création en échec : le message s'affiche et la modale reste ouverte", async () => {
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/mine") return Promise.resolve([])
      if (path === "/api/decks" && options.method === "POST") return Promise.reject(new Error("Nom déjà pris"))
      return Promise.resolve(null)
    })
    const { wrapper, router } = await mountView()
    await wrapper.get(".mesdecks-new").trigger("click")
    const modal = document.body.querySelector(".rift-modal")

    const nameInput = modal.querySelector("input[type=text]")
    nameInput.value = "Fureur de Noxus"
    nameInput.dispatchEvent(new Event("input"))
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()

    expect(document.body.querySelector(".rift-modal")).not.toBeNull()
    expect(document.body.querySelector(".rift-modal .mesdecks-error").textContent).toContain("Nom déjà pris")
    expect(router.currentRoute.value.path).toBe("/decks")
    wrapper.unmount()
  })

  it("la modale se ferme avec Échap sans créer de deck", async () => {
    const { wrapper } = await mountView()
    await wrapper.get(".mesdecks-new").trigger("click")
    expect(document.body.querySelector(".rift-modal")).not.toBeNull()

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    await flushPromises()
    expect(document.body.querySelector(".rift-modal")).toBeNull()
    expect(api.mock.calls.some(([, options]) => options?.method === "POST")).toBe(false)
    wrapper.unmount()
  })

  it("affiche le bilan W/L du deck quand /api/play/stats le renseigne", async () => {
    const deck = {
      id: 4,
      name: "Jinx — prêt à jouer",
      format: "tournament",
      is_public: false,
      likes: 0,
      card_count: 56,
      checks: [{ ok: true }],
      cards: []
    }
    api.mockImplementation((path) => {
      if (path === "/api/decks/mine") return Promise.resolve([deck])
      if (path === "/api/play/stats") {
        return Promise.resolve({
          by_deck: [{ deck_id: 4, name: deck.name, format: "tournament", played: 4, won: 3, lost: 1, win_rate: 0.75 }]
        })
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    const badge = wrapper.get(".deck-card-record")
    expect(badge.text()).toBe("3 V · 1 D")
    expect(badge.attributes("title")).toContain("3 victoire(s), 1 défaite(s)")
    wrapper.unmount()
  })

  it("n'affiche pas de bilan pour un deck sans partie suivie", async () => {
    api.mockImplementation((path) => {
      if (path === "/api/decks/mine") {
        return Promise.resolve([
          { id: 4, name: "Sans partie", format: "tournament", likes: 0, card_count: 1, cards: [] }
        ])
      }
      if (path === "/api/play/stats") return Promise.resolve({ by_deck: [] })
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    expect(wrapper.find(".deck-card-record").exists()).toBe(false)
    wrapper.unmount()
  })

  it("aucun deck : RiftEmpty avec Nouveau deck et les deux exemples", async () => {
    const { wrapper, router } = await mountView()
    const empty = wrapper.get(".rift-empty")
    expect(empty.text()).toContain("Forgez votre premier deck")
    const labels = empty.findAll("button").map((b) => b.text())
    expect(labels).toEqual(["Nouveau deck", "Exemple avec ma collection", "Exemple à compléter"])

    await empty.findAll("button")[2].trigger("click")
    await flushPromises()
    const call = api.mock.calls.find(([path]) => path === "/api/decks/example")
    expect(call[1].body).toEqual({ mode: "discover" })
    expect(router.currentRoute.value.path).toBe("/decks/9")
    wrapper.unmount()
  })

  it("double clic sur Créer : un seul POST", async () => {
    let release
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/mine") return Promise.resolve([])
      if (path === "/api/decks" && options.method === "POST") {
        return new Promise((resolve) => {
          release = () => resolve({ id: 7 })
        })
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    await wrapper.get(".mesdecks-new").trigger("click")
    const modal = document.body.querySelector(".rift-modal")
    const nameInput = modal.querySelector("input[type=text]")
    nameInput.value = "Fureur de Noxus"
    nameInput.dispatchEvent(new Event("input"))
    await flushPromises()

    const form = modal.querySelector("form")
    form.dispatchEvent(new Event("submit"))
    form.dispatchEvent(new Event("submit"))
    await flushPromises()
    release()
    await flushPromises()

    const posts = api.mock.calls.filter(([path, options]) => path === "/api/decks" && options?.method === "POST")
    expect(posts).toHaveLength(1)
    wrapper.unmount()
  })

  it("échec de chargement : message et Réessayer relance le GET", async () => {
    let attempts = 0
    api.mockImplementation((path) => {
      if (path === "/api/decks/mine") {
        attempts += 1
        return attempts === 1 ? Promise.reject(new Error("Serveur indisponible")) : Promise.resolve([])
      }
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    const alert = wrapper.get(".mesdecks-error")
    expect(alert.attributes("role")).toBe("alert")
    expect(alert.text()).toContain("Serveur indisponible")
    expect(wrapper.find(".rift-empty").exists()).toBe(false)

    const retry = wrapper.findAll("button").find((b) => b.text() === "Réessayer")
    await retry.trigger("click")
    await flushPromises()
    expect(attempts).toBe(2)
    expect(wrapper.find(".mesdecks-error").exists()).toBe(false)
    expect(wrapper.find(".rift-empty").exists()).toBe(true)
    wrapper.unmount()
  })

  it("le format se choisit au clavier dans le radiogroup", async () => {
    const { wrapper } = await mountView()
    await wrapper.get(".mesdecks-new").trigger("click")
    const modal = document.body.querySelector(".rift-modal")
    const radios = [...modal.querySelectorAll("[role=radiogroup] [role=radio]")]
    expect(radios[0].getAttribute("aria-checked")).toBe("true")

    radios[0].dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true }))
    await flushPromises()
    expect(radios[1].getAttribute("aria-checked")).toBe("true")
    expect(modal.textContent).toContain("Format libre, non officiel")

    const nameInput = modal.querySelector("input[type=text]")
    nameInput.value = "Libre"
    nameInput.dispatchEvent(new Event("input"))
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()
    const call = api.mock.calls.find(([path, options]) => path === "/api/decks" && options?.method === "POST")
    expect(call[1].body.format).toBe("free")
    wrapper.unmount()
  })

  it("supprime un deck après confirmation dans la modale du site", async () => {
    const deck = {
      id: 4,
      name: "Jinx — prêt à jouer",
      format: "tournament",
      is_public: false,
      likes: 0,
      card_count: 56,
      checks: [{ ok: true }, { ok: true }],
      cards: []
    }
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/mine") return Promise.resolve([deck])
      if (options.method === "DELETE") return Promise.resolve(null)
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()
    const confirmSpy = vi.spyOn(window, "confirm")

    await wrapper.find(".deck-card-remove").trigger("click")
    expect(confirmSpy).not.toHaveBeenCalled()
    expect(api.mock.calls.some(([, options]) => options?.method === "DELETE")).toBe(false)

    const modal = document.body.querySelector(".rift-modal")
    expect(modal).not.toBeNull()
    expect(modal.textContent).toContain("Jinx — prêt à jouer")
    expect(modal.textContent).toContain("impossible de le récupérer")

    const confirmButton = [...modal.querySelectorAll("button")].find(
      (button) => button.textContent.trim() === "Supprimer"
    )
    confirmButton.click()
    await flushPromises()

    expect(api.mock.calls.some(([path, options]) => path === "/api/decks/4" && options?.method === "DELETE")).toBe(true)
    expect(document.body.querySelector(".rift-modal")).toBeNull()
    confirmSpy.mockRestore()
    wrapper.unmount()
  })
})
