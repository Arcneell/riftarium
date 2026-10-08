import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CardCollectionPanel from "./CardCollectionPanel.vue"
import { api, session } from "../api.js"
import { tradeSettings } from "../trades.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const card = (extras = {}) => ({ id: "ogn-037-298", name: "Immortal Phoenix", wished_qty: 0, ...extras })
const stateOf = (entries) => ({ entries, total_qty: entries.reduce((n, e) => n + e.qty, 0) })
const isPost = ([path, options]) => path === "/api/collection/ogn-037-298/entries" && options?.method === "POST"

/* Le parent applique le patch émis : on le simule en réinjectant la carte mise à jour. */
async function mountPanel(initial = card()) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/connexion", component: { template: "<div />" } }
    ]
  })
  router.push("/")
  await router.isReady()
  const patches = []
  const wrapper = mount(CardCollectionPanel, {
    props: {
      card: initial,
      onChange: (patch) => {
        patches.push(patch)
        wrapper.setProps({ card: { ...wrapper.props("card"), ...patch } })
      }
    },
    global: { plugins: [router], stubs: { Icon: true } }
  })
  await flushPromises()
  return { wrapper, patches }
}

function login() {
  session.token = "jeton"
  session.handle = "visiteur"
}

describe("CardCollectionPanel", () => {
  beforeEach(() => {
    session.token = null
    session.handle = null
    localStorage.clear()
    api.mockReset()
  })

  it("visiteur non connecté : pas de bouton wishlist, seulement l'invitation à se connecter", async () => {
    const { wrapper } = await mountPanel()
    expect(wrapper.find(".panel-wish").exists()).toBe(false)
    expect(wrapper.find(".panel-add").exists()).toBe(false)
    const link = wrapper.get("a[href='/connexion']")
    expect(wrapper.text()).toContain("Connectez-vous pour suivre vos exemplaires et votre wishlist")
    expect(link.exists()).toBe(true)
    expect(api).not.toHaveBeenCalled()
    wrapper.unmount()
  })

  it("connecté : le cœur bascule l'ajout (PUT qty 1) puis le retrait (DELETE) de la wishlist", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298") return Promise.resolve({ entries: [], total_qty: 0 })
      return Promise.resolve(options.method ? null : {})
    })
    const { wrapper, patches } = await mountPanel()

    const toggle = wrapper.get(".panel-wish")
    expect(toggle.text()).toContain("Ajouter à la wishlist")
    expect(toggle.attributes("aria-pressed")).toBe("false")

    await toggle.trigger("click")
    await flushPromises()
    const put = api.mock.calls.find(
      ([path, options]) => path === "/api/wishlist/ogn-037-298" && options?.method === "PUT"
    )
    expect(put[1].body).toEqual({ qty: 1 })
    expect(patches).toContainEqual({ id: "ogn-037-298", wished_qty: 1 })
    expect(toggle.text()).toContain("Dans ma wishlist")
    expect(toggle.attributes("aria-pressed")).toBe("true")

    await toggle.trigger("click")
    await flushPromises()
    expect(
      api.mock.calls.some(([path, options]) => path === "/api/wishlist/ogn-037-298" && options?.method === "DELETE")
    ).toBe(true)
    expect(patches).toContainEqual({ id: "ogn-037-298", wished_qty: 0 })
    expect(toggle.attributes("aria-pressed")).toBe("false")
    wrapper.unmount()
  })

  it("ajoute un lot précis : POST puis remise à 1 de la quantité, choix conservés", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) return Promise.resolve(stateOf([]))
      if (path === "/api/collection/ogn-037-298/entries" && options.method === "POST") {
        return Promise.resolve(stateOf([{ id: 1, qty: 3, condition: "EX", lang: "EN" }]))
      }
      return Promise.resolve({})
    })
    const { wrapper, patches } = await mountPanel()

    const plus = wrapper.get(".panel-add .rift-stepper-plus")
    await plus.trigger("click")
    await plus.trigger("click")
    expect(wrapper.get(".panel-add .rift-stepper-value").text()).toBe("3")
    await wrapper.get(".panel-add [aria-label='État'] [title='Excellent']").trigger("click")
    await wrapper.get(".panel-add [aria-label='Langue'] [title='Anglais']").trigger("click")
    await wrapper.get(".panel-add-submit").trigger("click")
    await flushPromises()

    expect(api.mock.calls.find(isPost)[1].body).toEqual({ qty: 3, condition: "EX", lang: "EN" })
    expect(wrapper.get(".panel-add .rift-stepper-value").text()).toBe("1")
    expect(wrapper.get(".panel-add [title='Excellent']").attributes("aria-checked")).toBe("true")
    expect(patches).toContainEqual({ id: "ogn-037-298", owned_qty: 3 })
    wrapper.unmount()
  })

  it("ajout en échec : la saisie est conservée et l'erreur affichée", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) return Promise.resolve(stateOf([]))
      if (path === "/api/collection/ogn-037-298/entries" && options.method === "POST") {
        return Promise.reject(new Error("Collection indisponible"))
      }
      return Promise.resolve({})
    })
    const { wrapper } = await mountPanel()

    const plus = wrapper.get(".panel-add .rift-stepper-plus")
    for (let i = 0; i < 3; i++) await plus.trigger("click")
    await wrapper.get(".panel-add-submit").trigger("click")
    await flushPromises()

    const error = wrapper.get(".panel-error")
    expect(error.text()).toContain("Collection indisponible")
    expect(error.attributes("role")).toBe("alert")
    expect(wrapper.get(".panel-add .rift-stepper-value").text()).toBe("4")
    wrapper.unmount()
  })

  it("un échec de chargement des lots laisse le panneau utilisable, sans erreur visible", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) {
        return Promise.reject(new Error("Collection indisponible"))
      }
      return Promise.resolve({})
    })
    const { wrapper } = await mountPanel()

    expect(wrapper.find(".panel-error").exists()).toBe(false)
    expect(wrapper.find("[role=alert]").exists()).toBe(false)
    expect(wrapper.find(".panel-wish").exists()).toBe(true)
    expect(wrapper.find(".panel-add").exists()).toBe(true)
    expect(wrapper.find(".panel-count").exists()).toBe(true)
    wrapper.unmount()
  })

  it("changer de carte recharge les lots de la nouvelle carte", async () => {
    login()
    let resolveOld
    api.mockImplementation((path) => {
      if (path === "/api/collection/ogn-037-298") {
        return new Promise((resolve) => {
          resolveOld = resolve
        })
      }
      if (path === "/api/collection/ogn-001-298") {
        return Promise.resolve(stateOf([{ id: 9, qty: 2, condition: "NM", lang: "FR" }]))
      }
      return Promise.resolve({})
    })
    const { wrapper } = await mountPanel()

    await wrapper.setProps({ card: card({ id: "ogn-001-298" }) })
    await flushPromises()
    expect(api.mock.calls.some(([path]) => path === "/api/collection/ogn-001-298")).toBe(true)
    expect(wrapper.findAll(".panel-lot")).toHaveLength(1)

    // la réponse tardive de l'ancienne carte ne doit rien écrire
    resolveOld(stateOf([{ id: 1, qty: 5, condition: "NM", lang: "EN" }]))
    await flushPromises()
    expect(wrapper.findAll(".panel-lot")).toHaveLength(1)
    expect(wrapper.get(".panel-count .rift-stepper-value").text()).toBe("2")
    wrapper.unmount()
  })

  it("le compteur : + ajoute un exemplaire (préférence NM / FR), − en retire un", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) {
        return Promise.resolve(stateOf([{ id: 4, qty: 2, condition: "NM", lang: "FR" }]))
      }
      if (path === "/api/collection/ogn-037-298/entries" && options.method === "POST") {
        return Promise.resolve(stateOf([{ id: 4, qty: 3, condition: "NM", lang: "FR" }]))
      }
      if (path === "/api/collection/entries/4" && options.method === "PATCH") {
        return Promise.resolve(stateOf([{ id: 4, qty: 2, condition: "NM", lang: "FR" }]))
      }
      return Promise.resolve({})
    })
    const { wrapper, patches } = await mountPanel()
    expect(wrapper.get(".panel-count .rift-stepper-value").text()).toBe("2")

    await wrapper.get(".panel-count .rift-stepper-plus").trigger("click")
    await flushPromises()
    expect(api.mock.calls.find(isPost)[1].body).toEqual({ qty: 1, condition: "NM", lang: "FR" })
    expect(patches).toContainEqual({ id: "ogn-037-298", owned_qty: 3 })
    expect(wrapper.get(".panel-count .rift-stepper-value").text()).toBe("3")

    await wrapper.get(".panel-count .rift-stepper-minus").trigger("click")
    await flushPromises()
    const patch = api.mock.calls.find(([path, o]) => path === "/api/collection/entries/4" && o?.method === "PATCH")
    expect(patch[1].body).toEqual({ qty: 2 })
    expect(patches).toContainEqual({ id: "ogn-037-298", owned_qty: 2 })
    wrapper.unmount()
  })

  it("la préférence : « changer » la modifie, elle est persistée et utilisée par le + suivant", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) return Promise.resolve(stateOf([]))
      if (options.method === "POST") return Promise.resolve(stateOf([{ id: 1, qty: 1, condition: "EX", lang: "EN" }]))
      return Promise.resolve({})
    })
    const { wrapper } = await mountPanel()
    expect(wrapper.get(".panel-pref").text()).toContain("Ajouté en NM · Français")

    await wrapper.get(".panel-pref-change").trigger("click")
    await wrapper.get(".panel-pref-edit [title='Excellent']").trigger("click")
    await wrapper.get(".panel-pref-edit [title='Anglais']").trigger("click")
    expect(wrapper.get(".panel-pref").text()).toContain("Ajouté en EX · Anglais")
    expect(JSON.parse(localStorage.getItem("riftarium_collection_defaults"))).toEqual({ condition: "EX", lang: "EN" })

    await wrapper.get(".panel-count .rift-stepper-plus").trigger("click")
    await flushPromises()
    expect(api.mock.calls.find(isPost)[1].body).toEqual({ qty: 1, condition: "EX", lang: "EN" })
    wrapper.unmount()
  })

  it("chaque lot a son stepper : ± 1 par PATCH, le « − » d'un lot à 1 le supprime (qty 0)", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) {
        return Promise.resolve(stateOf([{ id: 1, qty: 2, condition: "NM", lang: "FR" }]))
      }
      if (path === "/api/collection/entries/1" && options.method === "PATCH") return Promise.resolve(stateOf([]))
      return Promise.resolve({})
    })
    const { wrapper, patches } = await mountPanel()

    expect(wrapper.get("summary").text()).toContain("Détail des exemplaires (1 lot)")
    expect(wrapper.get("details").attributes("open")).toBeUndefined()
    const lot = () => wrapper.get(".panel-lot")
    expect(lot().text()).toContain("NM · Français")
    expect(lot().get(".rift-stepper-value").text()).toBe("2")
    expect(lot().find(".rift-stepper--md").exists()).toBe(true)
    const patchCalls = () =>
      api.mock.calls.filter(([path, o]) => path === "/api/collection/entries/1" && o?.method === "PATCH")

    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/entries/1" && options.method === "PATCH") {
        return Promise.resolve(
          stateOf(options.body.qty ? [{ id: 1, qty: options.body.qty, condition: "NM", lang: "FR" }] : [])
        )
      }
      return Promise.resolve({})
    })
    await lot().get("[aria-label='Retirer un exemplaire de ce lot NM · Français']").trigger("click")
    await flushPromises()
    expect(patchCalls()[0][1].body).toEqual({ qty: 1 })
    expect(lot().get(".rift-stepper-value").text()).toBe("1")
    expect(patches).toContainEqual({ id: "ogn-037-298", owned_qty: 1 })

    await lot().get(".rift-stepper-plus").trigger("click")
    await flushPromises()
    expect(patchCalls()[1][1].body).toEqual({ qty: 2 })

    await lot().get(".rift-stepper-minus").trigger("click")
    await flushPromises()
    await lot().get(".rift-stepper-minus").trigger("click")
    await flushPromises()
    expect(patchCalls()[3][1].body).toEqual({ qty: 0 })
    expect(patches).toContainEqual({ id: "ogn-037-298", owned_qty: 0 })
    expect(wrapper.find(".panel-lot").exists()).toBe(false)
    expect(wrapper.get("summary").text()).toBe("Détail des exemplaires")
    wrapper.unmount()
  })

  it("pendant une requête (busy), les steppers de lot sont désactivés", async () => {
    login()
    let release
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) {
        return Promise.resolve(stateOf([{ id: 1, qty: 2, condition: "NM", lang: "FR" }]))
      }
      return new Promise((resolve) => (release = resolve))
    })
    const { wrapper } = await mountPanel()
    await wrapper.get(".panel-lot .rift-stepper-plus").trigger("click")
    expect(wrapper.get(".panel-lot .rift-stepper-plus").attributes("disabled")).toBeDefined()
    expect(wrapper.get(".panel-lot .rift-stepper-minus").attributes("disabled")).toBeDefined()
    release(stateOf([{ id: 1, qty: 3, condition: "NM", lang: "FR" }]))
    await flushPromises()
    expect(wrapper.get(".panel-lot .rift-stepper-plus").attributes("disabled")).toBeUndefined()
    wrapper.unmount()
  })

  it("« changer » reste une cible de 44 px alignée (inline-flex)", () => {
    const source = readFileSync(resolve("src/cards/CardCollectionPanel.vue"), "utf8")
    expect(source).toMatch(/\.panel-pref-change\s*\{\s*display: inline-flex;\s*align-items: center;/)
  })

  it("le détail des exemplaires porte un chevron décoratif qui pivote selon [open]", async () => {
    login()
    api.mockResolvedValue({ entries: [], total_qty: 0 })
    const { wrapper } = await mountPanel()
    const chevron = wrapper.get("summary.panel-detail-title .panel-detail-chevron")
    expect(chevron.attributes("aria-hidden")).toBe("true")
    /* jsdom n'applique pas le CSS scopé : on vérifie la règle dans la source du composant. */
    const source = readFileSync(resolve("src/cards/CardCollectionPanel.vue"), "utf8")
    expect(source).toMatch(
      /\.panel-detail\[open\] > \.panel-detail-title \.panel-detail-chevron\s*\{\s*transform: rotate\(45deg\)/
    )
    wrapper.unmount()
  })

  it("aucun select ni champ numérique dans le panneau", async () => {
    login()
    api.mockResolvedValue(stateOf([{ id: 1, qty: 2, condition: "NM", lang: "FR" }]))
    const { wrapper } = await mountPanel()
    expect(wrapper.find("select").exists()).toBe(false)
    expect(wrapper.find("input[type=number]").exists()).toBe(false)
    wrapper.unmount()
  })

  it("une réponse tardive d'une ancienne carte n'émet rien et n'écrase pas les lots", async () => {
    login()
    let resolvePost
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298/entries" && options.method === "POST") {
        return new Promise((resolve) => {
          resolvePost = resolve
        })
      }
      if (path === "/api/collection/ogn-001-298") {
        return Promise.resolve(stateOf([{ id: 9, qty: 2, condition: "NM", lang: "FR" }]))
      }
      return Promise.resolve({ entries: [], total_qty: 0 })
    })
    const { wrapper, patches } = await mountPanel()

    await wrapper.get(".panel-add-submit").trigger("click")
    await wrapper.setProps({ card: card({ id: "ogn-001-298" }) })
    await flushPromises()
    resolvePost(stateOf([{ id: 1, qty: 1, condition: "NM", lang: "EN" }]))
    await flushPromises()

    expect(patches).toEqual([])
    expect(wrapper.findAll(".panel-lot")).toHaveLength(1)
    expect(wrapper.get(".panel-count .rift-stepper-value").text()).toBe("2")
    expect(wrapper.find(".panel-saved").exists()).toBe(false)
    wrapper.unmount()
  })
})

describe("CardCollectionPanel — à échanger", () => {
  beforeEach(() => {
    localStorage.clear()
    api.mockReset()
    Object.assign(tradeSettings, { loaded: false, enabled: false, zone: null })
    login()
  })

  function setupApi({ enabled }) {
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/auth/me") return Promise.resolve({ trade_enabled: enabled, trade_zone: "sud" })
      if (path === "/api/collection/ogn-037-298")
        return Promise.resolve(stateOf([{ id: 5, qty: 3, condition: "NM", lang: "FR" }]))
      if (path === "/api/trades/offers") return Promise.resolve([{ id: 1, entry_id: 5, qty: 1, entry_qty: 3 }])
      return Promise.resolve(options.method ? null : {})
    })
  }

  it("règle la quantité proposée de chaque lot quand les échanges sont activés", async () => {
    setupApi({ enabled: true })
    const { wrapper } = await mountPanel()
    const trade = wrapper.get(".panel-lot-trade")
    expect(trade.get(".rift-stepper-value").text()).toBe("1")
    await trade.get(".rift-stepper-plus").trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/trades/offers/5", { method: "PUT", body: { qty: 2 } })
    expect(wrapper.get(".panel-lot-trade .rift-stepper-value").text()).toBe("2")
    wrapper.unmount()
  })

  it("masque la ligne quand les échanges ne sont pas activés", async () => {
    setupApi({ enabled: false })
    const { wrapper } = await mountPanel()
    expect(wrapper.find(".panel-lot-trade").exists()).toBe(false)
    expect(api).not.toHaveBeenCalledWith("/api/trades/offers")
    wrapper.unmount()
  })
})
