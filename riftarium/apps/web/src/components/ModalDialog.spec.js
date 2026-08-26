import { mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { afterEach, describe, expect, it } from "vitest"
import ModalDialog from "./ModalDialog.vue"

const Host = {
  components: { ModalDialog },
  data: () => ({ open: false }),
  template: `
    <div>
      <button id="opener" @click="open = true">Ouvrir</button>
      <ModalDialog v-if="open" title="Test" @close="open = false">
        <button id="a">A</button>
        <button id="b">B</button>
      </ModalDialog>
    </div>`
}

function pressTab(shiftKey = false) {
  document.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab", shiftKey, bubbles: true, cancelable: true }))
}

async function openModal() {
  const wrapper = mount(Host, { attachTo: document.body })
  const opener = wrapper.get("#opener")
  opener.element.focus()
  await opener.trigger("click")
  await nextTick()
  await nextTick()
  return wrapper
}

describe("ModalDialog", () => {
  afterEach(() => {
    document.body.innerHTML = ""
    document.body.classList.remove("nav-locked")
  })

  it("prend le focus à l'ouverture sur le premier élément focusable", async () => {
    const wrapper = await openModal()
    expect(document.activeElement?.className).toBe("modal-close")
    wrapper.unmount()
  })

  it("Tab et Shift+Tab bouclent à l'intérieur de la modale", async () => {
    const wrapper = await openModal()
    const last = document.getElementById("b")
    last.focus()
    pressTab()
    expect(document.activeElement?.className).toBe("modal-close")

    pressTab(true)
    expect(document.activeElement?.id).toBe("b")
    wrapper.unmount()
  })

  it("verrouille le défilement de la page par la classe du tiroir, pas par un style inline", async () => {
    /* `overflow: hidden` en style inline ne retient pas iOS Safari : c'est la
       classe body.nav-locked (déjà stylée) qui fige la page derrière la modale. */
    const wrapper = await openModal()
    expect(document.body.classList.contains("nav-locked")).toBe(true)
    expect(document.body.style.overflow).toBe("")

    wrapper.unmount()
    expect(document.body.classList.contains("nav-locked")).toBe(false)
  })

  it("deux modales empilées : la page reste figée tant que la dernière n'est pas fermée", async () => {
    const first = await openModal()
    const second = await openModal()
    expect(document.body.classList.contains("nav-locked")).toBe(true)

    second.unmount()
    expect(document.body.classList.contains("nav-locked")).toBe(true)

    first.unmount()
    expect(document.body.classList.contains("nav-locked")).toBe(false)
  })

  it("le fond ferme au clic complet, pas au premier contact du doigt", async () => {
    const wrapper = await openModal()
    const overlay = document.querySelector(".modal-overlay")

    /* Un début de glissement sur le fond ne doit plus fermer la modale. */
    overlay.dispatchEvent(new Event("pointerdown", { bubbles: true }))
    await nextTick()
    expect(wrapper.vm.open).toBe(true)

    overlay.dispatchEvent(new Event("click", { bubbles: true }))
    await nextTick()
    expect(wrapper.vm.open).toBe(false)
    wrapper.unmount()
  })

  it("restitue le focus à l'élément déclencheur à la fermeture", async () => {
    const wrapper = await openModal()
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await nextTick()
    expect(wrapper.vm.open).toBe(false)
    expect(document.activeElement?.id).toBe("opener")
    wrapper.unmount()
  })
})
