import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import DecksView from "./DecksView.vue"
import { api } from "../api.js"

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
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("DecksView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/decks/mine") return Promise.resolve([])
      if (path === "/api/decks" && options.method === "POST") return Promise.resolve({ id: 7 })
      if (path === "/api/decks/example" && options.method === "POST") return Promise.resolve({ id: 9 })
      return Promise.resolve(null)
    })
  })

  it("ouvre la modale de création puis navigue vers l'éditeur", async () => {
    const { wrapper, router } = await mountView()
    expect(document.body.querySelector(".modal")).toBeNull()

    await wrapper.get(".toolbar .btn-gold").trigger("click")
    const modal = document.body.querySelector(".modal")
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
    await wrapper.get(".toolbar .btn-gold").trigger("click")
    const modal = document.body.querySelector(".modal")
    const ownedButton = [...modal.querySelectorAll(".example-actions button")].find((b) =>
      b.textContent.includes("Avec ma collection")
    )
    ownedButton.click()
    await flushPromises()

    const call = api.mock.calls.find(([path]) => path === "/api/decks/example")
    expect(call[1].body).toEqual({ mode: "owned" })
    expect(router.currentRoute.value.path).toBe("/decks/9")
    wrapper.unmount()
  })

  it("la modale se ferme avec Échap sans créer de deck", async () => {
    const { wrapper } = await mountView()
    await wrapper.get(".toolbar .btn-gold").trigger("click")
    expect(document.body.querySelector(".modal")).not.toBeNull()

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    await flushPromises()
    expect(document.body.querySelector(".modal")).toBeNull()
    expect(api.mock.calls.some(([, options]) => options?.method === "POST")).toBe(false)
    wrapper.unmount()
  })
})
