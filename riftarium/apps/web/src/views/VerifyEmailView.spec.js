import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import VerifyEmailView from "./VerifyEmailView.vue"
import { api, ApiError, session } from "../api.js"
import { router as appRouter } from "../router.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

async function mountView(path = "/verification-email?token=jeton-mail") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/verification-email", component: VerifyEmailView },
      { path: "/connexion", component: { template: "<div />" } }
    ]
  })
  router.push(path)
  await router.isReady()
  const wrapper = mount(VerifyEmailView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } }
  })
  await flushPromises()
  return { wrapper, router }
}

describe("VerifyEmailView", () => {
  beforeEach(() => {
    session.token = null
    session.handle = null
    session.avatarUrl = null
    session.emailVerified = null
    api.mockReset()
    api.mockResolvedValue(null)
  })

  it("est déclarée dans le routeur en noindex avec un titre français", () => {
    const resolved = appRouter.resolve("/verification-email")
    expect(resolved.meta.noindex).toBe(true)
    expect(resolved.meta.title).toBe("Vérification de l'adresse e-mail")
  })

  it("appelle automatiquement l'API au montage et confirme l'adresse", async () => {
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/auth/verify-email", {
      method: "POST",
      body: { token: "jeton-mail" }
    })
    expect(wrapper.text()).toContain("Adresse vérifiée !")
    const home = wrapper.findAll("a").find((a) => a.attributes("href") === "/")
    expect(home).toBeTruthy()
    const login = wrapper.findAll("a").find((a) => a.attributes("href") === "/connexion")
    expect(login).toBeTruthy()
  })

  it("met à jour le statut de session quand l'utilisateur est connecté", async () => {
    session.token = "1"
    session.emailVerified = false
    await mountView()
    expect(session.emailVerified).toBe(true)
  })

  it("retire le jeton de l'adresse au montage tout en l'envoyant à l'API", async () => {
    const { router } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/auth/verify-email", {
      method: "POST",
      body: { token: "jeton-mail" }
    })
    expect(router.currentRoute.value.query.token).toBeUndefined()
  })

  it("n'écrit plus rien après démontage pendant la vérification", async () => {
    let rejectVerify
    api.mockImplementation(() => new Promise((resolve, reject) => (rejectVerify = reject)))
    const { wrapper } = await mountView()
    expect(wrapper.text()).toContain("Vérification en cours")
    wrapper.unmount()
    rejectVerify(new ApiError(400, "Jeton invalide ou expiré"))
    await flushPromises()
    /* Aucun warning Vue ni écriture d'état : le composant n'existe plus. */
    expect(wrapper.vm.state).toBe("loading")
  })

  it("sans jeton dans l'adresse : erreur immédiate, aucun appel à l'API", async () => {
    const { wrapper } = await mountView("/verification-email")
    expect(api).not.toHaveBeenCalled()
    expect(wrapper.get(".error").text()).toContain("jeton est manquant")
  })

  it("jeton expiré (400), visiteur déconnecté : message et invitation à se connecter", async () => {
    api.mockRejectedValue(new ApiError(400, "Jeton invalide ou expiré"))
    const { wrapper } = await mountView()
    expect(wrapper.get(".error").text()).toContain("invalide ou a expiré")
    const login = wrapper.findAll("a").find((a) => a.attributes("href") === "/connexion")
    expect(login).toBeTruthy()
    expect(wrapper.find("button").exists()).toBe(false)
  })

  it("jeton expiré, utilisateur connecté : propose de renvoyer l'e-mail de vérification", async () => {
    session.token = "1"
    api.mockRejectedValueOnce(new ApiError(400, "Jeton invalide ou expiré"))
    const { wrapper } = await mountView()

    api.mockResolvedValueOnce(null)
    await wrapper.get("button").trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/resend-verification", { method: "POST" })
    expect(wrapper.get(".success").text()).toContain("vient d'être envoyé")
  })

  it("renvoi limité (429) : message dédié sans casser la page", async () => {
    session.token = "1"
    api.mockRejectedValueOnce(new ApiError(400, "Jeton invalide ou expiré"))
    const { wrapper } = await mountView()

    api.mockRejectedValueOnce(new ApiError(429, "Too Many Requests"))
    await wrapper.get("button").trigger("click")
    await flushPromises()
    expect(wrapper.text()).toContain("Trop de demandes")
  })
})
