import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ScanView from "./ScanView.vue"
import { api, session } from "../api.js"
import { hashesFromFile } from "../scanCapture.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

/* jsdom n'a pas de canvas 2D : la partie capture est mockée, le matching (scanHash) reste réel. */
vi.mock("../scanCapture.js", () => ({
  hashesFromFile: vi.fn(),
  hashesFromVideoFrame: vi.fn(),
  imageDataFromRegion: vi.fn()
}))

const ZERO = "0".repeat(128)
const HASH_ITEMS = [
  { id: "card-1", h: ZERO }, // distance 0
  { id: "card-2", h: ZERO.slice(0, 127) + "1" }, // distance 1
  { id: "card-3", h: ZERO.slice(0, 126) + "ff" }, // distance 8
  { id: "card-4", h: "f".repeat(128) } // distance 512 : jamais dans le top 3
]

function fakeCard(id) {
  return {
    id,
    name: `Carte ${id}`,
    image_url: `https://cdn.example/${id}.png`,
    riftbound_id: `ogn-00${id.slice(-1)}`,
    set_id: "OGN",
    type: "Unit",
    rarity: "Common",
    domains: ["Fury"]
  }
}

function mockApi({ items = HASH_ITEMS, algo = "dhash16-hv-art" } = {}) {
  api.mockImplementation((path, options = {}) => {
    if (path === "/api/cards/hashes") return Promise.resolve({ algo, count: items.length, items })
    if (path.startsWith("/api/collection/") && options.method === "POST") {
      return Promise.resolve({ card_id: path.split("/")[3], total_qty: 1, entries: [] })
    }
    if (path.startsWith("/api/cards/")) return Promise.resolve(fakeCard(path.split("/").pop()))
    return Promise.reject(new Error(`appel inattendu : ${path}`))
  })
}

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/scan", component: ScanView },
      { path: "/cartes/:id", component: { template: "<div />" } },
      { path: "/connexion", component: { template: "<div />" } },
      { path: "/collection", component: { template: "<div />" } }
    ]
  })
  router.push("/scan")
  await router.isReady()
  const wrapper = mount(ScanView, {
    global: { plugins: [router], stubs: { Icon: true } }
  })
  await flushPromises()
  return { wrapper, router }
}

async function importPhoto(wrapper) {
  const input = wrapper.get(".scan-import input")
  Object.defineProperty(input.element, "files", {
    value: [new File(["x"], "carte.jpg", { type: "image/jpeg" })],
    configurable: true
  })
  await input.trigger("change")
  await flushPromises()
}

function setMediaDevices(value) {
  Object.defineProperty(navigator, "mediaDevices", { value, configurable: true })
}

describe("ScanView", () => {
  beforeEach(() => {
    api.mockReset()
    hashesFromFile.mockReset()
    mockApi()
    session.token = null
  })

  afterEach(() => {
    setMediaDevices(undefined)
    session.token = null
  })

  it("sans caméra (desktop) : le fallback « importer une photo » est visible", async () => {
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/cards/hashes")
    expect(wrapper.find(".scan-nocam").text()).toContain("Importez une photo")
    expect(wrapper.find(".scan-import input").exists()).toBe(true)
    expect(wrapper.find(".scan-stage").exists()).toBe(false)
    wrapper.unmount()
  })

  it("permission caméra refusée : explication claire, fallback fichier toujours là", async () => {
    const rejection = Object.assign(new Error("Permission denied"), { name: "NotAllowedError" })
    setMediaDevices({ getUserMedia: vi.fn().mockRejectedValue(rejection) })
    const { wrapper } = await mountView()
    expect(wrapper.find(".scan-nocam").text()).toContain("refusé")
    expect(wrapper.find(".scan-import input").exists()).toBe(true)
    wrapper.unmount()
  })

  it("index vide : message « Empreintes pas encore calculées », pas de caméra démarrée", async () => {
    mockApi({ items: [] })
    const getUserMedia = vi.fn()
    setMediaDevices({ getUserMedia })
    const { wrapper } = await mountView()
    expect(wrapper.find(".scan-empty").text()).toContain("Empreintes pas encore calculées")
    expect(wrapper.find(".scan-import input").exists()).toBe(false)
    expect(getUserMedia).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("algo d'empreintes inattendu (vieux cache) : message d'incompatibilité, pas de scan possible", async () => {
    mockApi({ algo: "dhash16-hv" })
    const getUserMedia = vi.fn()
    setMediaDevices({ getUserMedia })
    const { wrapper } = await mountView()
    expect(wrapper.find(".error").text()).toContain("dhash16-hv-art")
    expect(wrapper.find(".error").text()).toContain("incompatibles")
    expect(wrapper.find(".scan-import input").exists()).toBe(false)
    expect(getUserMedia).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("photo importée → les 3 candidats les plus proches, triés par distance", async () => {
    hashesFromFile.mockResolvedValue([ZERO])
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    const rows = wrapper.findAll(".scan-candidate")
    expect(rows).toHaveLength(3)
    expect(rows[0].text()).toContain("Carte card-1")
    expect(rows[1].text()).toContain("Carte card-2")
    expect(rows[2].text()).toContain("Carte card-3")
    expect(rows[0].text()).toContain("écart 0/512")
    expect(api).toHaveBeenCalledWith("/api/cards/card-1")
    wrapper.unmount()
  })

  it("connecté : confirmer un candidat ajoute +1 à la collection et permet d'enchaîner", async () => {
    session.token = "1"
    hashesFromFile.mockResolvedValue([ZERO])
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    const first = wrapper.findAll(".scan-candidate")[0]
    expect(first.element.tagName).toBe("BUTTON")
    await first.trigger("click")
    await flushPromises()

    const call = api.mock.calls.find(([path]) => path === "/api/collection/card-1/entries")
    /* Défaut : FR (site français, préférence mémorisée ensuite via localStorage). */
    expect(call[1]).toEqual({ method: "POST", body: { qty: 1, condition: "NM", lang: "FR" } })
    expect(wrapper.find(".scan-added").text()).toContain("Ajouté ✓")
    /* On peut enchaîner sans quitter : l'import reste disponible et « Nouveau scan » vide les résultats. */
    expect(wrapper.find(".scan-import input").exists()).toBe(true)
    const again = wrapper.findAll("button").find((button) => button.text() === "Nouveau scan")
    await again.trigger("click")
    expect(wrapper.findAll(".scan-candidate")).toHaveLength(0)
    wrapper.unmount()
  })

  it("non connecté : le candidat mène à la fiche carte et invite à se connecter", async () => {
    hashesFromFile.mockResolvedValue([ZERO])
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    expect(wrapper.find(".scan-login").text()).toContain("Connectez-vous")
    const first = wrapper.findAll(".scan-candidate")[0]
    expect(first.element.tagName).toBe("A")
    expect(first.attributes("href")).toBe("/cartes/card-1")
    expect(api.mock.calls.some(([path]) => path.includes("/entries"))).toBe(false)
    wrapper.unmount()
  })

  it("meilleure distance trop mauvaise (> 200/512) : aucun résultat plausible, on propose de reprendre", async () => {
    hashesFromFile.mockResolvedValue(["f".repeat(128)])
    mockApi({ items: [{ id: "card-1", h: ZERO }] })
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    expect(wrapper.find(".scan-nomatch").text()).toContain("Aucun résultat plausible")
    expect(wrapper.findAll(".scan-candidate")).toHaveLength(0)
    expect(api.mock.calls.some(([path]) => path === "/api/cards/card-1")).toBe(false)
    wrapper.unmount()
  })
})
