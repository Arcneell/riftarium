import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { api, session } from "../api.js"
import EmailVerifyNotice from "./EmailVerifyNotice.vue"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function apiError(status, message = "Erreur") {
  return Object.assign(new Error(message), { status })
}

describe("EmailVerifyNotice", () => {
  beforeEach(() => {
    api.mockReset()
    session.token = "1"
    session.emailVerified = false
  })

  afterEach(() => {
    vi.useRealTimers()
    session.token = null
    session.emailVerified = null
  })

  it("s'affiche seulement pour une session dont l'adresse n'est pas vérifiée", async () => {
    const wrapper = mount(EmailVerifyNotice)
    const notice = wrapper.get(".bandeau-verif")
    expect(notice.attributes("role")).toBe("status")
    /* Action requise : filet sang. */
    expect(notice.classes()).toContain("bandeau-cadre--action")
    expect(notice.text()).toContain("Adresse e-mail non vérifiée.")
    expect(wrapper.get(".bandeau-verif-renvoi").classes()).toContain("rift-btn--sm")

    session.emailVerified = true
    await flushPromises()
    expect(wrapper.find(".bandeau-verif").exists()).toBe(false)
    session.emailVerified = null
    await flushPromises()
    expect(wrapper.find(".bandeau-verif").exists()).toBe(false)
    session.emailVerified = false
    session.token = null
    await flushPromises()
    expect(wrapper.find(".bandeau-verif").exists()).toBe(false)
  })

  it("renvoie l'e-mail, bloque le double clic pendant l'envoi et confirme", async () => {
    let resolve
    api.mockReturnValueOnce(new Promise((r) => (resolve = r)))
    const wrapper = mount(EmailVerifyNotice)
    const button = wrapper.get(".bandeau-verif-renvoi")
    await button.trigger("click")
    expect(button.text()).toBe("Envoi…")
    expect(button.attributes("disabled")).toBeDefined()
    await button.trigger("click")
    expect(api).toHaveBeenCalledTimes(1)
    expect(api).toHaveBeenCalledWith("/api/auth/resend-verification", { method: "POST" })
    resolve({})
    await flushPromises()
    expect(wrapper.text()).toContain("E-mail de vérification renvoyé.")
    expect(button.text()).toBe("Renvoyer l'e-mail")
  })

  it("limite de débit : message dédié", async () => {
    api.mockRejectedValueOnce(apiError(429))
    const wrapper = mount(EmailVerifyNotice)
    await wrapper.get(".bandeau-verif-renvoi").trigger("click")
    await flushPromises()
    expect(wrapper.get(".bandeau-erreur").text()).toBe("Trop de demandes. Réessayez dans quelques minutes.")
  })

  it("autre erreur : message de l'API", async () => {
    api.mockRejectedValueOnce(apiError(500, "Service indisponible"))
    const wrapper = mount(EmailVerifyNotice)
    await wrapper.get(".bandeau-verif-renvoi").trigger("click")
    await flushPromises()
    expect(wrapper.get(".bandeau-erreur").text()).toBe("Service indisponible")
  })

  it("adresse déjà vérifiée : le dit, puis le bandeau s'efface", async () => {
    vi.useFakeTimers()
    api.mockRejectedValueOnce(apiError(400))
    const wrapper = mount(EmailVerifyNotice)
    await wrapper.get(".bandeau-verif-renvoi").trigger("click")
    await flushPromises()
    expect(wrapper.text()).toContain("Votre adresse était déjà vérifiée.")
    await vi.advanceTimersByTimeAsync(2500)
    expect(session.emailVerified).toBe(true)
    expect(wrapper.find(".bandeau-verif").exists()).toBe(false)
  })

  it("déconnexion pendant le délai : la session n'est pas ressuscitée", async () => {
    vi.useFakeTimers()
    api.mockRejectedValueOnce(apiError(400))
    const wrapper = mount(EmailVerifyNotice)
    await wrapper.get(".bandeau-verif-renvoi").trigger("click")
    await flushPromises()
    session.token = null
    session.emailVerified = null
    await vi.advanceTimersByTimeAsync(2500)
    expect(session.emailVerified).toBe(null)
  })
})
