import { mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import RiftSheet from "./RiftSheet.vue"

const Host = {
  components: { RiftSheet },
  data: () => ({ open: true }),
  template: `<div><RiftSheet v-if="open" title="Compte" @close="open = false"><a href="/profil">Profil</a></RiftSheet></div>`
}

async function mountHost() {
  const wrapper = mount(Host, { attachTo: document.body, global: { components: { Icon } } })
  await nextTick()
  await nextTick()
  return wrapper
}

describe("RiftSheet", () => {
  afterEach(() => {
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("est un dialogue modal titré, qui bloque le défilement de la page", async () => {
    const wrapper = await mountHost()
    const dialog = document.querySelector(".rift-sheet")
    expect(dialog.getAttribute("role")).toBe("dialog")
    expect(document.getElementById(dialog.getAttribute("aria-labelledby")).textContent).toBe("Compte")
    expect(document.body.classList.contains("nav-locked")).toBe(true)
    wrapper.unmount()
  })

  it("se ferme sur Échap et rend le défilement", async () => {
    const wrapper = await mountHost()
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await nextTick()
    expect(document.querySelector(".rift-sheet")).toBeNull()
    expect(document.body.classList.contains("nav-locked")).toBe(false)
    wrapper.unmount()
  })

  it("se ferme au clic sur le voile, pas sur la feuille", async () => {
    const wrapper = await mountHost()
    document.querySelector(".rift-sheet").click()
    await nextTick()
    expect(document.querySelector(".rift-sheet")).not.toBeNull()
    document.querySelector(".rift-sheet-overlay").click()
    await nextTick()
    expect(document.querySelector(".rift-sheet")).toBeNull()
    wrapper.unmount()
  })
})
