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
    document.body.style.overflow = ""
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

  it("restitue le focus à l'élément déclencheur à la fermeture", async () => {
    const wrapper = await openModal()
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    await nextTick()
    expect(wrapper.vm.open).toBe(false)
    expect(document.activeElement?.id).toBe("opener")
    wrapper.unmount()
  })
})
