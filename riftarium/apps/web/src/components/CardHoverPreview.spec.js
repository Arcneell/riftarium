import { flushPromises, mount } from "@vue/test-utils"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

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

/* Les deux préférences sont lues une seule fois, à l'évaluation du module (une
   grille monte des centaines de tuiles) : chaque scénario recharge donc le
   composant après avoir posé son matchMedia. */
async function loadComponent(preferences) {
  matchMedia(preferences)
  vi.resetModules()
  return (await import("./CardHoverPreview.vue")).default
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
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
    document.querySelectorAll(".card-preview").forEach((node) => node.remove())
  })

  it("ouvre un aperçu zoom après un court survol et l'annule à la sortie", async () => {
    const Component = await loadComponent()
    const wrapper = mount(Component, {
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
    /* Infobulle et non dialogue : rien à fermer, aucun focus à piéger. */
    expect(preview.getAttribute("role")).toBe("tooltip")
    expect(wrapper.get("a").attributes("href")).toBe("/cartes/ogn-037a-298")

    await wrapper.get(".card-hover").trigger("mouseleave")
    await flushPromises()
    expect(document.querySelector(".card-preview")).toBeNull()
    wrapper.unmount()
  })

  it("apparaît tout de suite si le mouvement réduit est demandé", async () => {
    const Component = await loadComponent({ reduced: true, fine: true })
    const wrapper = mount(Component, {
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
    const Component = await loadComponent({ fine: false })
    const wrapper = mount(Component, {
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
