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
    document.querySelectorAll(".apercu-bulle").forEach((node) => node.remove())
  })

  it("ouvre un aperçu zoom après un court survol et l'annule à la sortie", async () => {
    const Component = await loadComponent()
    const wrapper = mount(Component, {
      props: { card },
      slots: { default: "<a href='/cartes/ogn-037a-298'>tuile</a>" },
      attachTo: document.body
    })

    await wrapper.get(".apercu-hote").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(449)
    await flushPromises()
    expect(document.querySelector(".apercu-bulle")).toBeNull()

    await vi.advanceTimersByTimeAsync(1)
    await flushPromises()
    const preview = document.querySelector(".apercu-bulle")
    expect(preview).not.toBeNull()
    expect(preview.textContent).toContain("Immortal Phoenix")
    expect(preview.querySelector(".apercu-foil")).not.toBeNull()
    /* Variante, nom et texte de jeu rendu par RiftText (glyphes, mots-clés). */
    expect(preview.querySelector(".apercu-variante").textContent).toBe("Alt-art")
    expect(preview.querySelector(".apercu-nom").textContent).toBe("Immortal Phoenix")
    expect(preview.querySelector(".apercu-texte.rift-text")).not.toBeNull()
    expect(preview.querySelector(".apercu-illus img").getAttribute("alt")).toBe("Aperçu : Immortal Phoenix")
    /* Infobulle et non dialogue : rien à fermer, aucun focus à piéger. */
    expect(preview.getAttribute("role")).toBe("tooltip")
    expect(wrapper.get("a").attributes("href")).toBe("/cartes/ogn-037a-298")

    await wrapper.get(".apercu-hote").trigger("mouseleave")
    await flushPromises()
    expect(document.querySelector(".apercu-bulle")).toBeNull()
    wrapper.unmount()
  })

  it("apparaît tout de suite si le mouvement réduit est demandé", async () => {
    const Component = await loadComponent({ reduced: true, fine: true })
    const wrapper = mount(Component, {
      props: { card },
      slots: { default: "<span>tuile</span>" },
      attachTo: document.body
    })
    await wrapper.get(".apercu-hote").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(0)
    await flushPromises()
    expect(document.querySelector(".apercu-bulle.apercu-instant")).not.toBeNull()
    wrapper.unmount()
  })

  it("n'affiche rien sans pointeur fin", async () => {
    const Component = await loadComponent({ fine: false })
    const wrapper = mount(Component, {
      props: { card },
      slots: { default: "<span>tuile</span>" },
      attachTo: document.body
    })
    await wrapper.get(".apercu-hote").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(2500)
    await flushPromises()
    expect(document.querySelector(".apercu-bulle")).toBeNull()
    wrapper.unmount()
  })

  it("s'ouvre aussi au focus clavier et se ferme à la sortie du focus", async () => {
    const Component = await loadComponent()
    const wrapper = mount(Component, {
      props: { card },
      slots: { default: "<a href='/cartes/ogn-037a-298'>tuile</a>" },
      attachTo: document.body
    })
    await wrapper.get(".apercu-hote").trigger("focusin")
    await vi.advanceTimersByTimeAsync(450)
    await flushPromises()
    expect(document.querySelector(".apercu-bulle")).not.toBeNull()
    await wrapper.get(".apercu-hote").trigger("focusout")
    await flushPromises()
    expect(document.querySelector(".apercu-bulle")).toBeNull()
    wrapper.unmount()
  })

  it("désactivé : aucun aperçu", async () => {
    const Component = await loadComponent()
    const wrapper = mount(Component, {
      props: { card, disabled: true },
      slots: { default: "<span>tuile</span>" },
      attachTo: document.body
    })
    await wrapper.get(".apercu-hote").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(2500)
    await flushPromises()
    expect(document.querySelector(".apercu-bulle")).toBeNull()
    wrapper.unmount()
  })

  it("carte paysage : l'hôte et la bulle portent le format paysage, sans reflet hors foil", async () => {
    const Component = await loadComponent({ reduced: true, fine: true })
    const wrapper = mount(Component, {
      props: { card: { ...card, alternate_art: false, orientation: "landscape", text: "" } },
      slots: { default: "<span>tuile</span>" },
      attachTo: document.body
    })
    expect(wrapper.get(".apercu-hote").classes()).toContain("apercu-paysage")
    await wrapper.get(".apercu-hote").trigger("mouseenter")
    await vi.advanceTimersByTimeAsync(0)
    await flushPromises()
    const preview = document.querySelector(".apercu-bulle")
    expect(preview.classList.contains("apercu-paysage")).toBe(true)
    expect(preview.querySelector(".apercu-foil")).toBeNull()
    expect(preview.querySelector(".apercu-texte")).toBeNull()
    wrapper.unmount()
  })
})
