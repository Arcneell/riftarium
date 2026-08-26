import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ScanView from "./ScanView.vue"
import { api, session } from "../api.js"
import { hashesFromVideoFrame, scanFile } from "../scanCapture.js"
import { readCodeText } from "../scanOcr.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

/* jsdom n'a pas de canvas 2D : la partie capture est mockée, le matching (scanHash) reste réel. */
vi.mock("../scanCapture.js", () => ({
  scanFile: vi.fn(),
  hashesFromVideoFrame: vi.fn(),
  codeImageFromVideoFrame: vi.fn(),
  imageDataFromRegion: vi.fn()
}))

/* jsdom n'a pas de Worker : seules les fonctions qui parlent à tesseract sont remplacées,
   le parsing et l'appariement des codes restent réels. */
vi.mock("../scanOcr.js", async (importOriginal) => {
  const actual = await importOriginal()
  return {
    ...actual,
    readCodeText: vi.fn().mockResolvedValue(""),
    ensureOcrWorker: vi.fn().mockResolvedValue({}),
    terminateOcrWorker: vi.fn().mockResolvedValue()
  }
})

/** Empreinte à 4 × `nibbles` bits de distance de celle de card-1. */
const H = (nibbles) => "f".repeat(nibbles) + "0".repeat(128 - nibbles)
const ZERO = H(0)
const HASH_ITEMS = [
  { id: "card-1", rid: "ogn-001-298", h: H(0) }, // distance 0
  { id: "card-2", rid: "ogn-002-298", h: H(4) }, // 16
  { id: "card-3", rid: "ogn-003-298", h: H(10) }, // 40
  { id: "card-4", rid: "ogn-004-298", h: H(128) } // 512 : jamais dans le top 3
]

function fakeCard(id) {
  return {
    id,
    name: `Carte ${id}`,
    image_url: `https://cdn.example/${id}.png`,
    riftbound_id: `ogn-00${id.slice(-1)}-298`,
    set_id: "OGN",
    type: "Unit",
    rarity: "Common",
    domains: ["Fury"],
    price_eur: 3.2,
    price_foil_eur: 11.5
  }
}

function mockApi({ items = HASH_ITEMS, algo = "dhash16-hv-art" } = {}) {
  api.mockImplementation((path, options = {}) => {
    if (path.startsWith("/api/cards/hashes")) return Promise.resolve({ algo, count: items.length, items })
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
  await flushPromises() // le chargement de la carte verrouillée est une requête de plus
}

function setMediaDevices(value) {
  Object.defineProperty(navigator, "mediaDevices", { value, configurable: true })
}

describe("ScanView", () => {
  beforeEach(() => {
    api.mockReset()
    scanFile.mockReset()
    hashesFromVideoFrame.mockReset()
    readCodeText.mockReset()
    readCodeText.mockResolvedValue("")
    scanFile.mockResolvedValue({ hexes: [ZERO], codeImage: null })
    mockApi()
    session.token = null
    localStorage.removeItem("riftarium.scanPrefs")
  })

  afterEach(() => {
    setMediaDevices(undefined)
    session.token = null
  })

  it("sans caméra (desktop) : le fallback « importer une photo » est visible", async () => {
    const { wrapper } = await mountView()
    /* La version voyage dans l'URL : sans elle, un onglet rouvert après déploiement
       rejouerait depuis son cache (max-age=3600) un payload sans `rid`. */
    expect(api).toHaveBeenCalledWith("/api/cards/hashes?v=2")
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

  it("catalogue vide : message dédié, pas de caméra démarrée", async () => {
    mockApi({ items: [] })
    const getUserMedia = vi.fn()
    setMediaDevices({ getUserMedia })
    const { wrapper } = await mountView()
    expect(wrapper.find(".scan-empty").text()).toContain("Aucune carte à reconnaître")
    expect(wrapper.find(".scan-import input").exists()).toBe(false)
    expect(getUserMedia).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("cartes connues mais aucune empreinte : la lecture du code reste proposée par import", async () => {
    /* La voie « code » n'a besoin que de rid : tout couper priverait l'utilisateur du seul
       moyen d'identification encore disponible. */
    mockApi({ items: HASH_ITEMS.map((item) => ({ ...item, h: null })) })
    const getUserMedia = vi.fn()
    setMediaDevices({ getUserMedia })
    const { wrapper } = await mountView()
    expect(wrapper.find(".scan-empty").exists()).toBe(false)
    expect(wrapper.find(".scan-nocam").text()).toContain("seule la lecture du code")
    expect(wrapper.find(".scan-import input").exists()).toBe(true)
    /* Pas de boucle caméra : sans empreinte elle n'aurait rien à comparer d'une image à l'autre. */
    expect(getUserMedia).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("payload d'avant `rid` (cache Redis ou navigateur périmé) : refusé, pas exploité", async () => {
    /* Le laisser passer serait pire qu'une erreur : plus aucun code lisible, et un
       regroupement par variante qui met toutes les cartes dans le même sac. */
    mockApi({ items: HASH_ITEMS.map(({ id, h }) => ({ id, h })) })
    const getUserMedia = vi.fn()
    setMediaDevices({ getUserMedia })
    const { wrapper } = await mountView()
    expect(wrapper.find(".error").text()).toContain("incompatible")
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

  it("photo importée : panneau résultat avec visuel, code, prix et méthode d'identification", async () => {
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    const panel = wrapper.get(".scan-result")
    expect(panel.text()).toContain("Carte card-1")
    expect(panel.get(".scan-result-code").text()).toBe("OGN-001-298 · OGN")
    /* Le prix est l'information que l'on vient chercher quand on scanne sans rien ajouter. */
    expect(panel.get(".price-amount").text()).toContain("3,20")
    expect(panel.get(".price-foil").text()).toContain("11,50")
    expect(panel.get(".price-note").text()).toContain("Prix indicatifs")
    expect(panel.get(".price-link").attributes("href")).toContain("cardmarket.com")
    expect(panel.get(".scan-method").text()).toBe("Ressemblance visuelle, écart 0/512")
    /* Une seule requête carte au verrouillage : les alternatives restent des ids. */
    expect(api.mock.calls.filter(([path]) => path.startsWith("/api/cards/card-")).length).toBe(1)
    wrapper.unmount()
  })

  it("code lu sur la photo : le panneau annonce le code plutôt qu'une ressemblance", async () => {
    scanFile.mockResolvedValue({ hexes: [H(128)], codeImage: {} })
    readCodeText.mockResolvedValue("OGN 002/298")
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    expect(wrapper.get(".scan-result").text()).toContain("Carte card-2")
    /* Le code est affiché tel qu'il est imprimé sur la carte, zéros compris. */
    expect(wrapper.get(".scan-method").text()).toBe("Code lu : OGN 002/298")
    wrapper.unmount()
  })

  it("connecté : le panneau ajoute la carte à la collection et confirme", async () => {
    session.token = "1"
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    await wrapper.get(".scan-add").trigger("click")
    await flushPromises()
    const call = api.mock.calls.find(([path]) => path === "/api/collection/card-1/entries")
    /* Défaut : FR (site français, préférence mémorisée ensuite via localStorage). */
    expect(call[1]).toEqual({ method: "POST", body: { qty: 1, condition: "NM", lang: "FR" } })
    expect(wrapper.get(".scan-added").text()).toContain("Ajouté ✓")
    wrapper.unmount()
  })

  it("non connecté : pas de bouton d'ajout, un lien vers la connexion qui revient au scan", async () => {
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    expect(wrapper.find(".scan-add").exists()).toBe(false)
    expect(wrapper.find(".scan-auto").exists()).toBe(false)
    const login = wrapper.get(".scan-login a")
    expect(login.text()).toContain("Connectez-vous")
    expect(login.attributes("href")).toBe("/connexion?suite=/scan")
    /* La consultation reste possible sans compte : la fiche est à un lien. */
    expect(wrapper.find('a[href="/cartes/card-1"]').exists()).toBe(true)
    expect(api.mock.calls.some(([path]) => path.includes("/entries"))).toBe(false)
    wrapper.unmount()
  })

  it("« Ce n'est pas la bonne carte ? » déplie les alternatives et permet d'en choisir une", async () => {
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    /* Repliées par défaut : leurs visuels ne sont pas chargés tant qu'on ne les demande pas. */
    expect(wrapper.find(".scan-alt-list").exists()).toBe(false)
    await wrapper.get(".scan-alt-toggle").trigger("click")
    await flushPromises()

    const alternatives = wrapper.findAll(".scan-alt-item")
    expect(alternatives).toHaveLength(3)
    expect(alternatives[0].text()).toContain("Carte card-2")
    expect(alternatives[0].text()).toContain("écart 16/512")

    await alternatives[0].trigger("click")
    await flushPromises()
    expect(wrapper.get(".scan-result").text()).toContain("Carte card-2")
    expect(wrapper.get(".scan-method").text()).toBe("Choisie dans les alternatives")
    wrapper.unmount()
  })

  it("aucune carte plausible : on propose de reprendre la photo, sans charger de carte", async () => {
    scanFile.mockResolvedValue({ hexes: [H(128)], codeImage: null })
    mockApi({ items: [{ id: "card-1", rid: "ogn-001-298", h: ZERO }] })
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    expect(wrapper.get(".scan-nomatch").text()).toContain("Aucun résultat plausible")
    expect(wrapper.find(".scan-result").exists()).toBe(false)
    expect(api.mock.calls.some(([path]) => path === "/api/cards/card-1")).toBe(false)
    wrapper.unmount()
  })

  it("mode ajout automatique : la carte est ajoutée au verrouillage et un toast le confirme", async () => {
    session.token = "1"
    const { wrapper } = await mountView()
    await wrapper.get(".scan-auto input").setValue(true)
    /* Le mode est mémorisé pour la prochaine session de scan. */
    expect(JSON.parse(localStorage.getItem("riftarium.scanPrefs")).auto).toBe(true)

    await importPhoto(wrapper)
    await flushPromises()
    expect(api.mock.calls.some(([path]) => path === "/api/collection/card-1/entries")).toBe(true)
    expect(wrapper.get(".scan-toast").text()).toContain("Ajouté : Carte card-1 ×1")
    expect(wrapper.get(".scan-toast").text()).toContain("3,20")
    wrapper.unmount()
  })

  it("carte introuvable au verrouillage : erreur affichée et écran toujours utilisable", async () => {
    api.mockImplementation((path) => {
      if (path.startsWith("/api/cards/hashes")) {
        return Promise.resolve({ algo: "dhash16-hv-art", count: HASH_ITEMS.length, items: HASH_ITEMS })
      }
      return Promise.reject(new Error("Carte introuvable"))
    })
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    expect(wrapper.get(".error").text()).toContain("Carte introuvable")
    /* Le panneau résultat est fermé : ses boutons de reprise ne peuvent pas servir de sortie. */
    expect(wrapper.find(".scan-result").exists()).toBe(false)
    expect(wrapper.find(".scan-import input").exists()).toBe(true)
    wrapper.unmount()
  })

  it("démontage : la boucle s'arrête et les pistes caméra sont coupées", async () => {
    const stop = vi.fn()
    const track = { stop, getCapabilities: () => ({}) }
    const stream = { getTracks: () => [track], getVideoTracks: () => [track] }
    setMediaDevices({ getUserMedia: vi.fn().mockResolvedValue(stream) })
    /* Rectangle non nul : sans lui la boucle ne capturerait rien et le test ne prouverait rien. */
    const rect = { left: 0, top: 0, right: 300, bottom: 400, width: 300, height: 400, x: 0, y: 0 }
    const originalRect = Element.prototype.getBoundingClientRect
    Element.prototype.getBoundingClientRect = () => rect
    Object.defineProperty(HTMLVideoElement.prototype, "videoWidth", { value: 1920, configurable: true })
    Object.defineProperty(HTMLVideoElement.prototype, "videoHeight", { value: 1080, configurable: true })
    hashesFromVideoFrame.mockReturnValue([H(128)])

    try {
      const { wrapper } = await mountView()
      await new Promise((resolve) => setTimeout(resolve, 350))
      const pendantLeScan = hashesFromVideoFrame.mock.calls.length
      expect(pendantLeScan).toBeGreaterThan(0)

      wrapper.unmount()
      expect(stop).toHaveBeenCalled() // pas de LED caméra fantôme
      await new Promise((resolve) => setTimeout(resolve, 400))
      expect(hashesFromVideoFrame.mock.calls.length).toBe(pendantLeScan)
    } finally {
      Element.prototype.getBoundingClientRect = originalRect
    }
  })

  it("photo illisible : message d'erreur, l'import reste disponible", async () => {
    scanFile.mockRejectedValue(new Error("boom"))
    const { wrapper } = await mountView()
    await importPhoto(wrapper)

    expect(wrapper.get(".error").text()).toContain("Photo illisible")
    expect(wrapper.find(".scan-import input").exists()).toBe(true)
    wrapper.unmount()
  })
})
