import { defineComponent, h } from "vue"
import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it, vi } from "vitest"
import { useQuerySyncedFilters } from "./useQuerySyncedFilters.js"

/* Schéma d'exemple couvrant les cinq genres de champs. */
const SCHEMA = {
  q: { kind: "text" },
  set_id: { kind: "list", param: "set" },
  domain: { kind: "list" },
  sort: { kind: "enum", values: ["likes", "views"], default: "likes", reset: false },
  liked: { kind: "flag" },
  page: { kind: "page" }
}

async function mountFilters({ path = "/liste", schema = SCHEMA, options = {} } = {}) {
  let filters
  const Host = defineComponent({
    setup() {
      filters = useQuerySyncedFilters(schema, {
        fetcher: async () => ({ total: 0, items: [] }),
        pageSize: 10,
        debounce: 10,
        ...options
      })
      return () => h("div")
    }
  })
  const router = createRouter({ history: createMemoryHistory(), routes: [{ path: "/liste", component: Host }] })
  router.push(path)
  await router.isReady()
  const wrapper = mount(Host, { global: { plugins: [router] } })
  await flushPromises()
  return { wrapper, router, filters }
}

describe("useQuerySyncedFilters", () => {
  it("fromQuery : hydrate l'état depuis la query string au montage", async () => {
    const { wrapper, filters } = await mountFilters({ path: "/liste?q=jinx&set=OGN,SFD&domain=Fury&page=2&sort=bogus" })
    expect(filters.state).toMatchObject({
      q: "jinx",
      set_id: ["OGN", "SFD"],
      domain: ["Fury"],
      sort: "likes", // valeur inconnue → défaut
      liked: false,
      page: 2
    })
    wrapper.unmount()
  })

  it("toQuery : n'inclut que les valeurs hors défaut, sous leur nom d'URL", async () => {
    const { wrapper, filters } = await mountFilters()
    expect(filters.toQuery()).toEqual({})
    Object.assign(filters.state, {
      q: "x",
      set_id: ["OGN"],
      domain: ["Fury", "Calm"],
      sort: "views",
      liked: true,
      page: 4
    })
    expect(filters.toQuery()).toEqual({ q: "x", set: "OGN", domain: "Fury,Calm", sort: "views", liked: "1", page: "4" })
    wrapper.unmount()
  })

  it("répercute un filtre choisi dans l'URL, revient page 1 et recharge après débounce", async () => {
    const fetcher = vi.fn(async () => ({ total: 12, items: ["x"] }))
    const { wrapper, router, filters } = await mountFilters({ options: { fetcher } })
    filters.state.page = 3
    filters.setFilter("domain", ["Fury"])
    expect(filters.state.page).toBe(1)
    await vi.waitFor(() => expect(router.currentRoute.value.query).toEqual({ domain: "Fury" }))
    await vi.waitFor(() => expect(fetcher).toHaveBeenCalled())
    expect(filters.result.value.total).toBe(12)
    expect(filters.pageCount.value).toBe(2) // 12 résultats / 10 par page
    wrapper.unmount()
  })

  it("navigation historique : l'URL redevient la source de vérité de l'état", async () => {
    const { wrapper, router, filters } = await mountFilters()
    router.replace({ path: "/liste", query: { q: "jinx", set: "OGN", sort: "views", liked: "1", page: "3" } })
    await flushPromises()
    expect(filters.state).toMatchObject({ q: "jinx", set_id: ["OGN"], sort: "views", liked: true, page: 3 })
    wrapper.unmount()
  })

  it("reset : remet les défauts mais épargne les champs marqués reset:false", async () => {
    const { wrapper, filters } = await mountFilters({ path: "/liste?q=x&domain=Fury,Calm&liked=1&sort=views&page=2" })
    expect(filters.activeCount.value).toBe(4) // q + 2 domaines + liked (ni tri ni page)
    filters.reset()
    expect(filters.state).toMatchObject({ q: "", set_id: [], domain: [], liked: false, page: 1 })
    expect(filters.state.sort).toBe("views")
    expect(filters.activeCount.value).toBe(0)
    wrapper.unmount()
  })

  it("séquence : une réponse arrivée après une requête plus récente est ignorée", async () => {
    const resolvers = []
    const fetcher = vi.fn(() => new Promise((resolve) => resolvers.push(resolve)))
    const { wrapper, filters } = await mountFilters({ options: { fetcher } })

    const first = filters.load()
    const second = filters.load()
    resolvers[1]({ total: 2, items: ["récent"] })
    await second
    resolvers[0]({ total: 1, items: ["périmé"] })
    await first

    expect(filters.result.value.total).toBe(2)
    expect(filters.loading.value).toBe(false)
    wrapper.unmount()
  })

  it("syncUrl:false : état local aux défauts, l'URL n'est jamais touchée", async () => {
    const fetcher = vi.fn(async () => ({ total: 0, items: [] }))
    const { wrapper, router, filters } = await mountFilters({
      path: "/liste?q=jinx",
      options: { fetcher, syncUrl: false }
    })
    expect(filters.state.q).toBe("")
    filters.setFilter("domain", ["Fury"])
    await vi.waitFor(() => expect(fetcher).toHaveBeenCalled())
    expect(router.currentRoute.value.query).toEqual({ q: "jinx" })
    wrapper.unmount()
  })

  it("enabled : la garde bloque le chargement débouncé", async () => {
    const fetcher = vi.fn(async () => ({ total: 0, items: [] }))
    const { wrapper, filters } = await mountFilters({ options: { fetcher, enabled: () => false } })
    filters.setFilter("domain", ["Fury"])
    await new Promise((resolve) => setTimeout(resolve, 40))
    expect(fetcher).not.toHaveBeenCalled()
    wrapper.unmount()
  })
})
