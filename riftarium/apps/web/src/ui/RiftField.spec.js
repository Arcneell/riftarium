import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import RiftField from "./RiftField.vue"

const global = { components: { Icon } }

describe("RiftField", () => {
  it("relie le label à l'input et émet update:modelValue", async () => {
    const wrapper = mount(RiftField, { props: { label: "Nom", modelValue: "" }, global })
    const input = wrapper.get("input")
    expect(wrapper.get("label").attributes("for")).toBe(input.attributes("id"))
    await input.setValue("Ahri")
    expect(wrapper.emitted("update:modelValue")[0]).toEqual(["Ahri"])
  })

  it("masque visuellement le label sans le retirer", () => {
    const wrapper = mount(RiftField, { props: { label: "Recherche", hideLabel: true }, global })
    expect(wrapper.get("label").classes()).toContain("sr-only")
  })

  it("annonce l'erreur et marque l'input invalide", () => {
    const wrapper = mount(RiftField, { props: { label: "E-mail", error: "Adresse invalide" }, global })
    const input = wrapper.get("input")
    const error = wrapper.get(".rift-field-error")
    expect(input.attributes("aria-invalid")).toBe("true")
    expect(input.attributes("aria-describedby")).toBe(error.attributes("id"))
    expect(error.text()).toBe("Adresse invalide")
  })

  it("transmet les attributs et écouteurs non déclarés à l'input", async () => {
    let pressed = null
    const wrapper = mount(RiftField, {
      props: { label: "Recherche", search: true },
      attrs: {
        role: "combobox",
        "aria-expanded": "false",
        onKeydown: (event) => (pressed = event.key)
      },
      global
    })
    const input = wrapper.get("input")
    expect(input.attributes("role")).toBe("combobox")
    expect(input.attributes("type")).toBe("search")
    await input.trigger("keydown", { key: "ArrowDown" })
    expect(pressed).toBe("ArrowDown")
  })
})
