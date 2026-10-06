import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import CardCollectionPanel from "./CardCollectionPanel.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const card = (extras = {}) => ({ id: "ogn-037-298", name: "Immortal Phoenix", wished_qty: 0, ...extras })

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
    api.mockReset()
  })

  it("visiteur non connecté : pas de bouton wishlist, seulement l'invitation à se connecter", async () => {
    const { wrapper } = await mountPanel()
    expect(wrapper.find(".wish-toggle").exists()).toBe(false)
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

    const toggle = wrapper.get(".wish-toggle")
    expect(toggle.text()).toContain("Ajouter à la wishlist")
    expect(toggle.attributes("aria-pressed")).toBe("false")

    await toggle.trigger("click")
    await flushPromises()
    const put = api.mock.calls.find(
      ([path, options]) => path === "/api/wishlist/ogn-037-298" && options?.method === "PUT"
    )
    expect(put[1].body).toEqual({ qty: 1 })
    expect(patches).toContainEqual({ wished_qty: 1 })
    expect(toggle.text()).toContain("Dans ma wishlist")
    expect(toggle.attributes("aria-pressed")).toBe("true")

    await toggle.trigger("click")
    await flushPromises()
    expect(
      api.mock.calls.some(([path, options]) => path === "/api/wishlist/ogn-037-298" && options?.method === "DELETE")
    ).toBe(true)
    expect(patches).toContainEqual({ wished_qty: 0 })
    expect(toggle.attributes("aria-pressed")).toBe("false")
    wrapper.unmount()
  })

  it("ajoute un lot : POST puis remise à 1 de la quantité saisie", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) {
        return Promise.resolve({ entries: [], total_qty: 0 })
      }
      if (path === "/api/collection/ogn-037-298/entries" && options.method === "POST") {
        return Promise.resolve({ entries: [{ id: 1, qty: 3, condition: "NM", lang: "EN" }], total_qty: 3 })
      }
      return Promise.resolve({})
    })
    const { wrapper, patches } = await mountPanel()

    await wrapper.get(".panel-add input[type=number]").setValue(3)
    await wrapper.get(".panel-add button").trigger("click")
    await flushPromises()

    const post = api.mock.calls.find(
      ([path, options]) => path === "/api/collection/ogn-037-298/entries" && options?.method === "POST"
    )
    expect(post[1].body).toEqual({ qty: 3, condition: "NM", lang: "EN" })
    expect(wrapper.get(".panel-add input[type=number]").element.value).toBe("1")
    expect(wrapper.get(".panel-saved").text()).toContain("Lot ajouté.")
    expect(patches).toContainEqual({ owned_qty: 3 })
    wrapper.unmount()
  })

  it("ajout en échec : la saisie est conservée et l'erreur affichée", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) {
        return Promise.resolve({ entries: [], total_qty: 0 })
      }
      if (path === "/api/collection/ogn-037-298/entries" && options.method === "POST") {
        return Promise.reject(new Error("Collection indisponible"))
      }
      return Promise.resolve({})
    })
    const { wrapper } = await mountPanel()

    await wrapper.get(".panel-add input[type=number]").setValue(4)
    await wrapper.get(".panel-add button").trigger("click")
    await flushPromises()

    const error = wrapper.get(".panel-error")
    expect(error.text()).toContain("Collection indisponible")
    expect(error.attributes("role")).toBe("alert")
    expect(wrapper.get(".panel-add input[type=number]").element.value).toBe("4")
    wrapper.unmount()
  })

  it("un échec de chargement des lots laisse le panneau utilisable", async () => {
    login()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/collection/ogn-037-298" && !options.method) {
        return Promise.reject(new Error("Collection indisponible"))
      }
      return Promise.resolve({})
    })
    const { wrapper } = await mountPanel()

    expect(wrapper.find(".panel-error").exists()).toBe(false)
    expect(wrapper.text()).toContain("Aucun exemplaire pour l'instant.")
    expect(wrapper.find(".wish-toggle").exists()).toBe(true)
    expect(wrapper.find(".panel-add").exists()).toBe(true)
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
        return Promise.resolve({ entries: [{ id: 9, qty: 2, condition: "NM", lang: "FR" }], total_qty: 2 })
      }
      return Promise.resolve({})
    })
    const { wrapper } = await mountPanel()

    await wrapper.setProps({ card: card({ id: "ogn-001-298" }) })
    await flushPromises()
    expect(api.mock.calls.some(([path]) => path === "/api/collection/ogn-001-298")).toBe(true)
    expect(wrapper.findAll(".panel-lot:not(.panel-add)")).toHaveLength(1)

    // la réponse tardive de l'ancienne carte ne doit rien écrire
    resolveOld({ entries: [{ id: 1, qty: 5, condition: "NM", lang: "EN" }], total_qty: 5 })
    await flushPromises()
    expect(wrapper.findAll(".panel-lot:not(.panel-add)")).toHaveLength(1)
    expect(wrapper.get(".panel-lot:not(.panel-add) input[type=number]").element.value).toBe("2")
    wrapper.unmount()
  })
})
