import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import CardHoverPreview from "./CardHoverPreview.vue"

function matchMedia({ reduced = false, fine = true } = {}) {
  window.matchMedia = (query) => ({
    matches: String(query).includes("prefers-reduced-motion")
      ? reduced
      : String(query).includes("hover: hover") || String(query).includes("pointer: fine")
        ? fine
        : false,
    media: query,
    addEventListener() {},
    removeEventListener() {},
    addListener() {},
    removeListener() {},
    dispatchEvent() {
      return false
    }
  })
}

const card = {
  id: "ogn-037a-298",
  name: "Immortal Phoenix",
  image_url: "https://cdn.example/phoenix.png",
  text: "Gain :rb_might:.",
  alternate_art: true
}

describe("CardHoverPreview", () => {
  beforeEach(() => {
    matchMedia()
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
    document.querySelectorAll(".card-preview").forEach((node) => node.remove())
  })

  it("ouvre un aperçu zoom après un court survol et l'annule à la sortie", async () => {
    const wrapper = mount(CardHoverPreview, {
      props: { card },
      slots: { default: "<a href='/cartes/ogn-037a-298'>tuile</a>" },
      attachTo: document.body
    })

    await wrapper.get(".card-hover").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(449)
    await flushPromises()
    expect(document.querySelector(".card-preview")).toBeNull()

    await vi.advanceTimersByTimeAsync(1)
    await flushPromises()
    const preview = document.querySelector(".card-preview")
    expect(preview).not.toBeNull()
    expect(preview.textContent).toContain("Immortal Phoenix")
    expect(preview.querySelector(".card-foil")).not.toBeNull()
    expect(wrapper.get("a").attributes("href")).toBe("/cartes/ogn-037a-298")

    await wrapper.get(".card-hover").trigger("mouseleave")
    await flushPromises()
    expect(document.querySelector(".card-preview")).toBeNull()
    wrapper.unmount()
  })

  it("apparaît tout de suite si le mouvement réduit est demandé", async () => {
    matchMedia({ reduced: true, fine: true })
    const wrapper = mount(CardHoverPreview, {
      props: { card },
      slots: { default: "<span>tuile</span>" },
      attachTo: document.body
    })
    await wrapper.get(".card-hover").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(0)
    await flushPromises()
    expect(document.querySelector(".card-preview.instant")).not.toBeNull()
    wrapper.unmount()
  })

  it("n'affiche rien sans pointeur fin", async () => {
    matchMedia({ fine: false })
    const wrapper = mount(CardHoverPreview, {
      props: { card },
      slots: { default: "<span>tuile</span>" },
      attachTo: document.body
    })
    await wrapper.get(".card-hover").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(2500)
    await flushPromises()
    expect(document.querySelector(".card-preview")).toBeNull()
    wrapper.unmount()
  })
})
