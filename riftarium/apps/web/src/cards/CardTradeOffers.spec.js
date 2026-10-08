import { enableAutoUnmount, flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import CardTradeOffers from "./CardTradeOffers.vue"
import Icon from "../components/Icon.vue"
import { api, session } from "../api.js"
import { tradeSettings } from "../trades.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const PHOENIX = { id: "ogn-037-298", name: "Immortal Phoenix" }
const offer = (handle, zone) => ({
  offer_id: handle.length,
  owner: { handle, avatar_url: null, zone },
  condition: "NM",
  lang: "EN",
  qty: 1,
  mutual: false,
  pending_request_id: null
})

async function mountBlock() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: "/:any(.*)*", component: { template: "<div />" } }]
  })
  router.push("/cartes/ogn-037-298")
  await router.isReady()
  const wrapper = mount(CardTradeOffers, {
    props: { card: PHOENIX },
    global: { plugins: [router], components: { Icon } }
  })
  await flushPromises()
  return wrapper
}

enableAutoUnmount(afterEach)

describe("CardTradeOffers", () => {
  beforeEach(() => {
    api.mockReset()
    Object.assign(tradeSettings, { loaded: false, enabled: false, zone: null })
    session.token = "1"
  })

  it("n'affiche rien à un visiteur", async () => {
    session.token = null
    const wrapper = await mountBlock()
    expect(wrapper.text()).toBe("")
    expect(api).not.toHaveBeenCalled()
  })

  it("invite à activer les échanges", async () => {
    api.mockResolvedValue({ trade_enabled: false })
    const wrapper = await mountBlock()
    expect(wrapper.get("a[href='/echanges']").text()).toContain("Activer les échanges")
  })

  it("compte les offres, dont celles de ma zone, et les liste", async () => {
    api.mockImplementation((path) =>
      path === "/api/auth/me"
        ? Promise.resolve({ trade_enabled: true, trade_zone: "sud" })
        : Promise.resolve({ offers: [offer("bob", "sud"), offer("carl", "nord")], total: 2, in_my_zone: 1 })
    )
    const wrapper = await mountBlock()
    expect(api).toHaveBeenCalledWith("/api/trades/cards/ogn-037-298/offers")
    expect(wrapper.text()).toContain("2 joueurs la proposent, dont 1 dans votre zone")
    expect(wrapper.findAll(".offre")).toHaveLength(2)
  })

  it("se tait quand personne ne la propose", async () => {
    api.mockImplementation((path) =>
      path === "/api/auth/me"
        ? Promise.resolve({ trade_enabled: true, trade_zone: "sud" })
        : Promise.resolve({ offers: [], total: 0, in_my_zone: 0 })
    )
    const wrapper = await mountBlock()
    expect(wrapper.text()).toContain("Personne ne la propose")
  })
})
