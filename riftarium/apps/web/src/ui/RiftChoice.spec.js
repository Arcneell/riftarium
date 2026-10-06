import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftChoice from "./RiftChoice.vue"

const options = [
  { value: "NM", label: "NM", title: "Near Mint" },
  { value: "EX", label: "EX", title: "Excellent" },
  { value: "GD", label: "GD", title: "Good" }
]
const mountChoice = (modelValue = "EX") =>
  mount(RiftChoice, { props: { modelValue, options, label: "État" }, attachTo: document.body })

describe("RiftChoice", () => {
  it("rend un groupe radio nommé avec aria-checked et tabindex itinérant", () => {
    const wrapper = mountChoice()
    const group = wrapper.get("[role=radiogroup]")
    expect(group.attributes("aria-label")).toBe("État")
    const radios = wrapper.findAll("[role=radio]")
    expect(radios.map((r) => r.attributes("aria-checked"))).toEqual(["false", "true", "false"])
    expect(radios.map((r) => r.attributes("tabindex"))).toEqual(["-1", "0", "-1"])
    expect(radios[0].attributes("title")).toBe("Near Mint")
    expect(radios[0].attributes("type")).toBe("button")
    wrapper.unmount()
  })

  it("garde une puce tabulable sans sélection valide", () => {
    const wrapper = mountChoice("")
    expect(wrapper.findAll("[role=radio]").map((r) => r.attributes("tabindex"))).toEqual(["0", "-1", "-1"])
    wrapper.unmount()
  })

  it("un clic sélectionne", async () => {
    const wrapper = mountChoice()
    await wrapper.findAll("[role=radio]")[2].trigger("click")
    expect(wrapper.emitted("update:modelValue")).toEqual([["GD"]])
    wrapper.unmount()
  })

  it("les flèches déplacent la sélection et le focus, en boucle", async () => {
    const wrapper = mountChoice()
    const radios = wrapper.findAll("[role=radio]")
    await radios[1].trigger("keydown", { key: "ArrowRight" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["GD"])
    expect(document.activeElement).toBe(radios[2].element)
    await radios[1].trigger("keydown", { key: "ArrowLeft" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["NM"])
    await radios[0].trigger("keydown", { key: "ArrowLeft" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["GD"])
    await radios[2].trigger("keydown", { key: "ArrowDown" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["NM"])
    await radios[1].trigger("keydown", { key: "End" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["GD"])
    await radios[1].trigger("keydown", { key: "Home" })
    expect(wrapper.emitted("update:modelValue").at(-1)).toEqual(["NM"])
    wrapper.unmount()
  })

  it("laisse passer les raccourcis avec Alt, Ctrl ou Meta", async () => {
    const wrapper = mountChoice()
    const radio = wrapper.findAll("[role=radio]")[1]
    for (const mod of ["altKey", "ctrlKey", "metaKey"]) {
      const event = new KeyboardEvent("keydown", { key: "ArrowRight", [mod]: true, bubbles: true, cancelable: true })
      radio.element.dispatchEvent(event)
      expect(event.defaultPrevented).toBe(false)
    }
    expect(wrapper.emitted("update:modelValue")).toBeUndefined()
    wrapper.unmount()
  })

  it("ignore les autres touches", async () => {
    const wrapper = mountChoice()
    await wrapper.findAll("[role=radio]")[1].trigger("keydown", { key: "a" })
    expect(wrapper.emitted("update:modelValue")).toBeUndefined()
    wrapper.unmount()
  })
})
