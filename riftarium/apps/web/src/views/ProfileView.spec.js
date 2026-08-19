import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import ProfileView from "./ProfileView.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const profile = {
  id: 1,
  handle: "testeur",
  email: "testeur@example.org",
  email_verified: true,
  bio: "",
  avatar_card_id: null,
  avatar_url: null,
  created_at: "2026-01-15T10:00:00+00:00",
  stats: { unique_cards: 12, total_cards: 40, decks: 2, public_decks: 1, likes_received: 7 }
}

const faces = [
  {
    id: "ogn-247-298",
    name: "Daughter of the Void",
    image_url: "https://cdn.example/ahri.png",
    orientation: "landscape"
  }
]

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/profil", component: ProfileView },
      { path: "/confidentialite", component: { template: "<div />" } }
    ]
  })
  router.push("/profil")
  await router.isReady()
  const wrapper = mount(ProfileView, {
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

describe("ProfileView", () => {
  beforeEach(() => {
    session.token = "jeton-test"
    session.handle = "testeur"
    session.avatarUrl = null
    session.emailVerified = null
    api.mockReset()
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/auth/me" && !options.method) return Promise.resolve({ ...profile })
      if (path === "/api/auth/avatars") return Promise.resolve(faces)
      if (path === "/api/auth/me" && options.method === "PATCH") {
        return Promise.resolve({
          ...profile,
          ...options.body,
          handle: options.body.handle || profile.handle,
          avatar_url: options.body.avatar_card_id ? faces[0].image_url : null
        })
      }
      if (path === "/api/auth/password") {
        return Promise.resolve({ token: "nouveau-jeton", handle: "testeur", avatar_url: null })
      }
      if (path === "/api/auth/export") {
        return Promise.resolve({ handle: "testeur", collection: [], decks: [] })
      }
      if (path === "/api/auth/me" && options.method === "DELETE") return Promise.resolve(null)
      return Promise.resolve(null)
    })
  })

  it("affiche les stats et la grille de légendes", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.text()).toContain("testeur")
    expect(wrapper.text()).toContain("12")
    expect(wrapper.text()).toContain("Likes reçus")
    expect(wrapper.text()).toContain("Daughter of the Void")
    expect(wrapper.findAll(".avatar-pick")).toHaveLength(2)
    expect(wrapper.get(".avatar-scroller").attributes("aria-label")).toBe("Choisir un portrait")
    wrapper.unmount()
  })

  it("enregistre un pseudo et une bio", async () => {
    const { wrapper } = await mountView()
    await wrapper.get("#profile-handle").setValue("nyra")
    await wrapper.get("#profile-bio").setValue("Main Ahri")
    await wrapper.get("#profile-handle-pwd").setValue("motdepasse123")
    await wrapper.get("form.panel").trigger("submit")
    await flushPromises()

    const call = api.mock.calls.find(([path, options]) => path === "/api/auth/me" && options?.method === "PATCH")
    expect(call[1].body).toEqual({
      bio: "Main Ahri",
      handle: "nyra",
      current_password: "motdepasse123"
    })
    wrapper.unmount()
  })

  it("choisit un portrait de légende", async () => {
    const { wrapper } = await mountView()
    const picks = wrapper.findAll(".avatar-pick")
    await picks[1].trigger("click")
    await flushPromises()
    const call = api.mock.calls.find(
      ([path, options]) => path === "/api/auth/me" && options?.method === "PATCH" && options.body?.avatar_card_id
    )
    expect(call[1].body).toEqual({ avatar_card_id: "ogn-247-298" })
    wrapper.unmount()
  })

  it("signale un changement d'e-mail avec l'envoi d'un e-mail de vérification", async () => {
    const { wrapper } = await mountView()
    const emailForm = wrapper.findAll("form.panel")[1]
    await emailForm.get("#profile-email").setValue("nouvelle@example.org")
    await emailForm.get("#profile-email-pwd").setValue("motdepasse123")
    await emailForm.trigger("submit")
    await flushPromises()

    const call = api.mock.calls.find(([path, options]) => path === "/api/auth/me" && options?.method === "PATCH")
    expect(call[1].body).toEqual({ email: "nouvelle@example.org", current_password: "motdepasse123" })
    expect(wrapper.get(".success").text()).toBe(
      "Email mis à jour — un e-mail de vérification a été envoyé à la nouvelle adresse."
    )
    wrapper.unmount()
  })

  it("masque le rappel de vérification quand l'adresse est vérifiée", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.find(".verify-line").exists()).toBe(false)
    expect(session.emailVerified).toBe(true)
    wrapper.unmount()
  })

  it("adresse non vérifiée : affiche le rappel et renvoie l'e-mail de vérification", async () => {
    api.mockImplementation((path, options = {}) => {
      if (path === "/api/auth/me" && !options.method) return Promise.resolve({ ...profile, email_verified: false })
      if (path === "/api/auth/avatars") return Promise.resolve(faces)
      if (path === "/api/auth/resend-verification") return Promise.resolve(null)
      return Promise.resolve(null)
    })
    const { wrapper } = await mountView()

    const line = wrapper.get(".verify-line")
    expect(line.text()).toContain("Adresse e-mail non vérifiée")
    expect(session.emailVerified).toBe(false)

    await line.get("button").trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/resend-verification", { method: "POST" })
    expect(line.get(".success").text()).toContain("E-mail de vérification renvoyé")
    wrapper.unmount()
  })

  it("refuse un nouveau mot de passe non confirmé", async () => {
    const { wrapper } = await mountView()
    const forms = wrapper.findAll("form.panel")
    const pwdForm = forms[2]
    await pwdForm.get("#profile-pwd-current").setValue("ancien")
    await pwdForm.get("#profile-pwd-new").setValue("nouveausecret")
    await pwdForm.get("#profile-pwd-confirm").setValue("autrechose")
    await pwdForm.trigger("submit")
    await flushPromises()
    expect(wrapper.text()).toContain("Les mots de passe ne correspondent pas")
    expect(api.mock.calls.some(([path]) => path === "/api/auth/password")).toBe(false)
    wrapper.unmount()
  })

  it("demande une confirmation avant de supprimer le compte", async () => {
    const { wrapper, router } = await mountView()
    await wrapper.get(".profile-danger .btn-danger").trigger("click")
    const modal = document.body.querySelector(".modal")
    expect(modal).not.toBeNull()
    modal.querySelector("input[type=password]").value = "motdepasse123"
    modal.querySelector("input[type=password]").dispatchEvent(new Event("input"))
    modal.querySelector("input[type=text]").value = "testeur"
    modal.querySelector("input[type=text]").dispatchEvent(new Event("input"))
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()

    const call = api.mock.calls.find(([path, options]) => path === "/api/auth/me" && options?.method === "DELETE")
    expect(call[1].body).toEqual({ password: "motdepasse123", handle: "testeur" })
    expect(session.token).toBeNull()
    expect(router.currentRoute.value.path).toBe("/")
    wrapper.unmount()
  })
})
