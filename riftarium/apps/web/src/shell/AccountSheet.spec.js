import { mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AccountSheet from "./AccountSheet.vue"

async function mountSheet() {
  const router = await makeRouter("/")
  const wrapper = mount(AccountSheet, { attachTo: document.body, global: { plugins: [router], components: { Icon } } })
  await nextTick()
  return wrapper
}

const texts = () => [...document.querySelectorAll(".rift-sheet a, .rift-sheet button")].map((n) => n.textContent.trim())

describe("AccountSheet", () => {
  afterEach(() => {
    Object.assign(session, { token: null, handle: null, isAdmin: null })
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("visiteur : Jouer et Connexion", async () => {
    const wrapper = await mountSheet()
    expect(texts()).toEqual(expect.arrayContaining(["Salon", "Historique", "Statistiques", "Connexion"]))
    expect(texts()).not.toContain("Déconnexion")
    wrapper.unmount()
  })

  it("membre : Jouer, compte, wishlist, déconnexion ; admin en plus", async () => {
    Object.assign(session, { token: "1", handle: "Kaelis", isAdmin: true })
    const wrapper = await mountSheet()
    expect(texts()).toEqual(
      expect.arrayContaining(["Salon", "Profil", "Amis", "Wishlist", "Administration", "Déconnexion"])
    )
    wrapper.unmount()
  })

  it("un lien choisi ferme la feuille", async () => {
    const wrapper = await mountSheet()
    document.querySelector(".rift-sheet a[href='/salon']").click()
    await nextTick()
    expect(wrapper.emitted("close")).toBeTruthy()
    wrapper.unmount()
  })
})
