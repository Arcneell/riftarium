import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import AuthView from "./AuthView.vue"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/connexion", component: AuthView },
      { path: "/", component: { template: "<div />" } },
      { path: "/cgu", component: { template: "<div />" } },
      { path: "/confidentialite", component: { template: "<div />" } }
    ]
  })
  router.push("/connexion")
  await router.isReady()
  const wrapper = mount(AuthView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } }
  })
  await flushPromises()
  return { wrapper, router }
}

describe("AuthView", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockResolvedValue({ token: "jeton", handle: "nyra", avatar_url: null })
  })

  it("refuse l'inscription sans âge ni conditions", async () => {
    const { wrapper } = await mountView()
    await wrapper.get(".filters .filter:last-child").trigger("click")
    await wrapper.get("#handle").setValue("nyra")
    await wrapper.get("#email").setValue("nyra@example.org")
    await wrapper.get("#password").setValue("motdepasse123")
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(wrapper.get(".error").text()).toContain("15 ans")
    expect(api).not.toHaveBeenCalled()
  })

  it("envoie les consentements à l'API une fois les cases cochées", async () => {
    const { wrapper, router } = await mountView()
    await wrapper.get(".filters .filter:last-child").trigger("click")
    await wrapper.get("#handle").setValue("nyra")
    await wrapper.get("#email").setValue("nyra@example.org")
    await wrapper.get("#password").setValue("motdepasse123")
    const checks = wrapper.findAll(".legal-check input")
    await checks[0].setValue(true)
    await checks[1].setValue(true)
    await wrapper.get("form").trigger("submit")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/register", {
      method: "POST",
      body: {
        handle: "nyra",
        email: "nyra@example.org",
        password: "motdepasse123",
        accept_terms: true,
        confirm_age: true
      }
    })
    expect(router.currentRoute.value.path).toBe("/")
  })
})
