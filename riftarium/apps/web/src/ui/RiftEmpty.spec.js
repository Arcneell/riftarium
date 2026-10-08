import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftEmpty from "./RiftEmpty.vue"

describe("RiftEmpty", () => {
  it("annonce l'état vide avec titre, texte et actions", () => {
    const wrapper = mount(RiftEmpty, {
      props: { title: "Aucune carte", text: "Essayez d'autres filtres." },
      slots: { default: "<button>Réinitialiser</button>" }
    })
    expect(wrapper.attributes("role")).toBe("status")
    expect(wrapper.get(".rift-empty-title").text()).toBe("Aucune carte")
    expect(wrapper.text()).toContain("Essayez d'autres filtres.")
    expect(wrapper.get("button").text()).toBe("Réinitialiser")
  })
})
