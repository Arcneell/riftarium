import { mount } from "@vue/test-utils"
import { nextTick } from "vue"
import { describe, expect, it } from "vitest"
import CardZoom from "./CardZoom.vue"

const card = { name: "Jinx", img: "https://cdn.example/jinx.png?w=280" }

describe("CardZoom", () => {
  it("dialogue avec image grande taille et alt", () => {
    const wrapper = mount(CardZoom, { props: { card }, attachTo: document.body })
    expect(document.body.querySelector('[role="dialog"]')).not.toBeNull()
    const img = document.body.querySelector("img.carte-zoom-img")
    expect(img.getAttribute("src")).toContain("w=1024")
    expect(img.getAttribute("alt")).toBe("Jinx")
    wrapper.unmount()
  })

  it("Échap émet close", async () => {
    const wrapper = mount(CardZoom, { props: { card }, attachTo: document.body })
    await nextTick()
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    expect(wrapper.emitted("close")).toHaveLength(1)
    wrapper.unmount()
  })

  it("clic sur l'image émet close", () => {
    const wrapper = mount(CardZoom, { props: { card }, attachTo: document.body })
    document.body.querySelector("img.carte-zoom-img").click()
    expect(wrapper.emitted("close")).toHaveLength(1)
    wrapper.unmount()
  })

  it("le focus revient au déclencheur", async () => {
    const opener = document.createElement("button")
    document.body.appendChild(opener)
    opener.focus()
    const wrapper = mount(CardZoom, { props: { card }, attachTo: document.body })
    await nextTick()
    await nextTick()
    expect(document.activeElement).not.toBe(opener)
    wrapper.unmount()
    expect(document.activeElement).toBe(opener)
    opener.remove()
  })
})
