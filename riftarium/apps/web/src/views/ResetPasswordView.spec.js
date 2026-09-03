import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import ResetPasswordView from "./ResetPasswordView.vue"
import { api, ApiError } from "../api.js"
import { router as appRouter } from "../router.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

async function mountView(path = "/reinitialisation?token=jeton-mail") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/reinitialisation", component: ResetPasswordView },
      { path: "/mot-de-passe-oublie", component: { template: "<div />" } },
      { path: "/connexion", component: { template: "<div />" } }
    ]
  })
  router.push(path)
  await router.isReady()
  const wrapper = mount(ResetPasswordView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } }
  })
  await flushPromises()
  return { wrapper, router }
}

describe("ResetPasswordView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockResolvedValue(null)
  })

  it("est déclarée dans le routeur en noindex avec un titre français", () => {
    const resolved = appRouter.resolve("/reinitialisation")
    expect(resolved.meta.noindex).toBe(true)
    expect(resolved.meta.title).toBe("Réinitialiser le mot de passe")
  })

  it("sans jeton dans l'adresse : message d'erreur et lien pour redemander un e-mail", async () => {
    const { wrapper } = await mountView("/reinitialisation")
    expect(wrapper.find("form").exists()).toBe(false)
    expect(wrapper.get(".error").text()).toContain("jeton est manquant")
    const link = wrapper.findAll("a").find((a) => a.attributes("href") === "/mot-de-passe-oublie")
    expect(link).toBeTruthy()
    expect(api).not.toHaveBeenCalled()
  })

  it("retire le jeton de l'adresse au montage tout en le gardant pour l'envoi", async () => {
    const { wrapper, router } = await mountView()
    expect(router.currentRoute.value.query.token).toBeUndefined()
    expect(wrapper.find("form").exists()).toBe(true)
    await wrapper.get("#reset-password").setValue("nouveausecret")
    await wrapper.get("#reset-confirm").setValue("nouveausecret")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/reset-password", {
      method: "POST",
      body: { token: "jeton-mail", new_password: "nouveausecret" }
    })
  })

  it("refuse un nouveau mot de passe non confirmé, sans appeler l'API", async () => {
    const { wrapper } = await mountView()
    await wrapper.get("#reset-password").setValue("nouveausecret")
    await wrapper.get("#reset-confirm").setValue("autrechose")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(wrapper.get(".error").text()).toContain("Les mots de passe ne correspondent pas")
    expect(api).not.toHaveBeenCalled()
  })

  it("envoie le jeton et le nouveau mot de passe puis invite à se reconnecter", async () => {
    const { wrapper } = await mountView()
    await wrapper.get("#reset-password").setValue("nouveausecret")
    await wrapper.get("#reset-confirm").setValue("nouveausecret")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/reset-password", {
      method: "POST",
      body: { token: "jeton-mail", new_password: "nouveausecret" }
    })
    expect(wrapper.text()).toContain("Mot de passe mis à jour, reconnectez-vous")
    const login = wrapper.findAll("a").find((a) => a.attributes("href") === "/connexion")
    expect(login).toBeTruthy()
  })

  it("jeton expiré (400) : message clair et lien pour redemander un e-mail", async () => {
    api.mockRejectedValue(new ApiError(400, "Jeton invalide ou expiré"))
    const { wrapper } = await mountView()
    await wrapper.get("#reset-password").setValue("nouveausecret")
    await wrapper.get("#reset-confirm").setValue("nouveausecret")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(wrapper.get(".error").text()).toContain("invalide ou a expiré")
    const link = wrapper.findAll("a").find((a) => a.attributes("href") === "/mot-de-passe-oublie")
    expect(link).toBeTruthy()
  })

  it("affiche les autres erreurs de l'API telles quelles", async () => {
    api.mockRejectedValue(new ApiError(422, "Mot de passe trop court"))
    const { wrapper } = await mountView()
    await wrapper.get("#reset-password").setValue("nouveausecret")
    await wrapper.get("#reset-confirm").setValue("nouveausecret")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(wrapper.get(".error").text()).toContain("Mot de passe trop court")
    expect(wrapper.findAll("a").some((a) => a.attributes("href") === "/mot-de-passe-oublie")).toBe(false)
  })
})
