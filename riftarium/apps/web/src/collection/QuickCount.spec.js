import { flushPromises, mount } from "@vue/test-utils"
import { reactive } from "vue"
import { beforeEach, describe, expect, it, vi } from "vitest"
import QuickCount from "./QuickCount.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const card = { id: "c1", name: "Ahri", owned_qty: 2 }
const state = (entries) => ({ card_id: "c1", total_qty: entries.reduce((n, e) => n + e.qty, 0), entries })

describe("QuickCount", () => {
  beforeEach(() => {
    api.mockReset()
    localStorage.clear()
    session.token = "1"
  })

  it("+ envoie un POST avec les préférences et émet change", async () => {
    api.mockResolvedValue(state([{ id: 1, qty: 3, condition: "NM", lang: "FR" }]))
    const wrapper = mount(QuickCount, { props: { card } })
    expect(wrapper.get(".rift-stepper-value").text()).toBe("2")
    await wrapper.get(".rift-stepper-plus").trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/collection/c1/entries", {
      method: "POST",
      body: { qty: 1, condition: "NM", lang: "FR" }
    })
    expect(wrapper.emitted("change")[0][0]).toEqual({ id: "c1", owned_qty: 3 })
    expect(wrapper.get(".rift-stepper-value").text()).toBe("3")
  })

  it("− charge les lots (GET) puis réduit (PATCH)", async () => {
    api.mockImplementation((path, opts) => {
      if (!opts) return Promise.resolve(state([{ id: 7, qty: 2, condition: "NM", lang: "FR" }]))
      return Promise.resolve(state([{ id: 7, qty: 1, condition: "NM", lang: "FR" }]))
    })
    const wrapper = mount(QuickCount, { props: { card } })
    await wrapper.get(".rift-stepper-minus").trigger("click")
    await flushPromises()
    expect(api.mock.calls[0]).toEqual(["/api/collection/c1"])
    expect(api.mock.calls[1]).toEqual(["/api/collection/entries/7", { method: "PATCH", body: { qty: 1 } }])
    expect(wrapper.emitted("change")[0][0]).toEqual({ id: "c1", owned_qty: 1 })
  })

  it("les clics n'atteignent jamais le lien parent", async () => {
    api.mockResolvedValue(state([{ id: 1, qty: 3, condition: "NM", lang: "FR" }]))
    const onClick = vi.fn()
    const wrapper = mount(
      {
        components: { QuickCount },
        props: ["card"],
        template: '<a href="#x" @click="onClick"><QuickCount :card="card" /></a>',
        methods: { onClick }
      },
      { props: { card } }
    )
    const event = new MouseEvent("click", { bubbles: true, cancelable: true })
    wrapper.get(".rift-stepper-plus").element.dispatchEvent(event)
    expect(event.defaultPrevented).toBe(true)
    expect(onClick).not.toHaveBeenCalled()
  })

  it("utilise les préférences partagées passées en propriété", async () => {
    api.mockResolvedValue(state([{ id: 1, qty: 3, condition: "EX", lang: "EN" }]))
    const defaults = reactive({ condition: "NM", lang: "FR" })
    const wrapper = mount(QuickCount, { props: { card, defaults } })
    defaults.condition = "EX"
    defaults.lang = "EN"
    await wrapper.get(".rift-stepper-plus").trigger("click")
    expect(api.mock.calls[0][1].body).toMatchObject({ condition: "EX", lang: "EN" })
  })
})
