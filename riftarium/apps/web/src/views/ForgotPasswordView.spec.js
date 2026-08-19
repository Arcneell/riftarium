import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import ForgotPasswordView from "./ForgotPasswordView.vue"
import { api, ApiError } from "../api.js"
import { router as appRouter } from "../router.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const NEUTRAL = "Si un compte existe avec cette adresse, un e-mail de réinitialisation a été envoyé."

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/mot-de-passe-oublie", component: ForgotPasswordView },
      { path: "/connexion", component: { template: "<div />" } }
    ]
  })
  router.push("/mot-de-passe-oublie")
  await router.isReady()
  const wrapper = mount(ForgotPasswordView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } }
  })
  await flushPromises()
  return { wrapper, router }
}

describe("ForgotPasswordView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockResolvedValue(null)
  })

  it("est déclarée dans le routeur en noindex avec un titre français", () => {
    const resolved = appRouter.resolve("/mot-de-passe-oublie")
    expect(resolved.meta.noindex).toBe(true)
    expect(resolved.meta.title).toBe("Mot de passe oublié")
  })

  it("affiche le champ e-mail et un lien de retour à la connexion", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.find("#forgot-email").exists()).toBe(true)
    const back = wrapper.findAll("a").find((a) => a.attributes("href") === "/connexion")
    expect(back).toBeTruthy()
    expect(back.text()).toContain("Retour à la connexion")
  })

  it("envoie l'adresse à l'API puis affiche le message neutre", async () => {
    const { wrapper } = await mountView()
    await wrapper.get("#forgot-email").setValue("nyra@example.org")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/forgot-password", {
      method: "POST",
      body: { email: "nyra@example.org" }
    })
    expect(wrapper.text()).toContain(NEUTRAL)
    expect(wrapper.find("form").exists()).toBe(false)
  })

  it("affiche le même message neutre même quand l'API échoue (anti-énumération)", async () => {
    api.mockRejectedValue(new ApiError(400, "Adresse inconnue"))
    const { wrapper } = await mountView()
    await wrapper.get("#forgot-email").setValue("inconnue@example.org")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(wrapper.text()).toContain(NEUTRAL)
    expect(wrapper.text()).not.toContain("Adresse inconnue")
  })

  it("signale la limite de débit (429) sans dévoiler l'existence du compte", async () => {
    api.mockRejectedValue(new ApiError(429, "Too Many Requests"))
    const { wrapper } = await mountView()
    await wrapper.get("#forgot-email").setValue("nyra@example.org")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(wrapper.get(".error").text()).toContain("Trop de demandes")
    expect(wrapper.find("form").exists()).toBe(true)
  })

  it("désactive le bouton et ignore les doubles soumissions pendant la requête", async () => {
    let resolveSend
    api.mockImplementation(() => new Promise((resolve) => (resolveSend = resolve)))
    const { wrapper } = await mountView()
    await wrapper.get("#forgot-email").setValue("nyra@example.org")

    await wrapper.get("form").trigger("submit")
    expect(wrapper.get("button[type=submit]").attributes("disabled")).toBeDefined()

    await wrapper.get("form").trigger("submit")
    expect(api).toHaveBeenCalledTimes(1)

    resolveSend(null)
    await flushPromises()
    expect(wrapper.text()).toContain(NEUTRAL)
  })
})
