import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import ProfileTrades from "./ProfileTrades.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const PROFILE = { trade_enabled: true, trade_zone: "sud", trade_contact: "Discord : moi", notify_trades: true }

async function mountPanel(profile = PROFILE) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: "/:any(.*)*", component: { template: "<div />" } }]
  })
  router.push("/profil")
  await router.isReady()
  return mount(ProfileTrades, { props: { profile }, global: { plugins: [router] } })
}

const buttonWith = (wrapper, label) => wrapper.findAll("button").find((button) => button.text().includes(label))

describe("ProfileTrades", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation((path, options) => Promise.resolve({ ...PROFILE, ...options.body }))
  })

  it("reprend les réglages du profil", async () => {
    const wrapper = await mountPanel()
    expect(wrapper.get("input[type=checkbox][name=trade_enabled]").element.checked).toBe(true)
    expect(wrapper.get("input[type=text]").element.value).toBe("Discord : moi")
    expect(wrapper.get("[role=radio][aria-checked=true]").text()).toBe("Sud")
  })

  it("enregistre zone, contact et e-mails, puis émet le profil à jour", async () => {
    const wrapper = await mountPanel()
    await wrapper
      .findAll("[role=radio]")
      .find((radio) => radio.text() === "Ouest")
      .trigger("click")
    await wrapper.get("input[type=text]").setValue("Insta : moi")
    await wrapper.get("input[type=checkbox][name=notify_trades]").setValue(false)
    await buttonWith(wrapper, "Enregistrer").trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/me", {
      method: "PATCH",
      body: { trade_enabled: true, trade_zone: "ouest", trade_contact: "Insta : moi", notify_trades: false }
    })
    expect(wrapper.emitted("saved")[0][0].trade_zone).toBe("ouest")
    expect(wrapper.text()).toContain("Réglages d'échange enregistrés")
  })

  it("affiche le refus de l'API sans perdre la saisie", async () => {
    api.mockRejectedValue(new Error("Choisissez une zone et un contact pour activer les échanges"))
    const wrapper = await mountPanel({ ...PROFILE, trade_contact: null })
    await wrapper.get("input[type=text]").setValue("")
    await buttonWith(wrapper, "Enregistrer").trigger("click")
    await flushPromises()
    expect(wrapper.get("[role=alert]").text()).toContain("Choisissez une zone")
  })
})
