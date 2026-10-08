import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftStepper from "./RiftStepper.vue"

const mountStepper = (props = {}) => mount(RiftStepper, { props: { value: 2, label: "Annie", ...props } })

describe("RiftStepper", () => {
  it("rend deux boutons nommés et la valeur en aria-live", () => {
    const wrapper = mountStepper()
    const buttons = wrapper.findAll("button")
    expect(buttons).toHaveLength(2)
    expect(buttons[0].attributes("type")).toBe("button")
    expect(buttons[0].attributes("aria-label")).toBe("Retirer un exemplaire d'Annie")
    expect(buttons[1].attributes("aria-label")).toBe("Ajouter un exemplaire d'Annie")
    const value = wrapper.get(".rift-stepper-value")
    expect(value.text()).toBe("2")
    expect(value.attributes("aria-live")).toBe("polite")
  })

  it("garde « de » devant une consonne", () => {
    const wrapper = mountStepper({ label: "Jinx" })
    expect(wrapper.get(".rift-stepper-plus").attributes("aria-label")).toBe("Ajouter un exemplaire de Jinx")
  })

  it("prend les libellés complets passés par l'appelant", () => {
    const wrapper = mountStepper({
      incrementLabel: "Ajouter un exemplaire à l'échange (lot NM · Français)",
      decrementLabel: "Retirer un exemplaire de l'échange (lot NM · Français)"
    })
    expect(wrapper.get(".rift-stepper-plus").attributes("aria-label")).toBe(
      "Ajouter un exemplaire à l'échange (lot NM · Français)"
    )
    expect(wrapper.get(".rift-stepper-minus").attributes("aria-label")).toBe(
      "Retirer un exemplaire de l'échange (lot NM · Français)"
    )
  })

  it("émet increment et decrement", async () => {
    const wrapper = mountStepper()
    await wrapper.get(".rift-stepper-plus").trigger("click")
    await wrapper.get(".rift-stepper-minus").trigger("click")
    expect(wrapper.emitted("increment")).toHaveLength(1)
    expect(wrapper.emitted("decrement")).toHaveLength(1)
  })

  it("désactive − au minimum et + au maximum", () => {
    const atMin = mountStepper({ value: 0 })
    expect(atMin.get(".rift-stepper-minus").attributes("disabled")).toBeDefined()
    expect(atMin.get(".rift-stepper-plus").attributes("disabled")).toBeUndefined()
    const atMax = mountStepper({ value: 5, max: 5 })
    expect(atMax.get(".rift-stepper-plus").attributes("disabled")).toBeDefined()
    expect(atMax.get(".rift-stepper-minus").attributes("disabled")).toBeUndefined()
  })

  it("désactive les deux boutons pendant busy", () => {
    const wrapper = mountStepper({ busy: true })
    wrapper.findAll("button").forEach((b) => expect(b.attributes("disabled")).toBeDefined())
  })

  it("porte la taille en classe", () => {
    expect(mountStepper().classes()).toContain("rift-stepper--md")
    expect(mountStepper({ size: "sm" }).classes()).toContain("rift-stepper--sm")
  })
})
