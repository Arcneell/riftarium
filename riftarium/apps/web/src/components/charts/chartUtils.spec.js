import { mount } from "@vue/test-utils"
import { nextTick, ref } from "vue"
import { describe, expect, it } from "vitest"
import { lastDays, niceScale, useMeasuredWidth, zeroFillDays } from "./chartUtils.js"

describe("niceScale", () => {
  it("arrondit à des ticks propres (3-4 valeurs)", () => {
    expect(niceScale(9)).toEqual({ top: 10, ticks: [0, 5, 10] })
    expect(niceScale(100)).toEqual({ top: 100, ticks: [0, 50, 100] })
    expect(niceScale(30)).toEqual({ top: 30, ticks: [0, 10, 20, 30] })
    expect(niceScale(7)).toEqual({ top: 10, ticks: [0, 5, 10] })
  })

  it("gère zéro sans diviser par zéro", () => {
    const scale = niceScale(0)
    expect(scale.top).toBeGreaterThan(0)
    expect(scale.ticks[0]).toBe(0)
  })
})

describe("lastDays", () => {
  it("produit N jours ISO consécutifs se terminant au jour demandé", () => {
    const days = lastDays(30, "2026-08-19")
    expect(days).toHaveLength(30)
    expect(days[29]).toBe("2026-08-19")
    expect(days[28]).toBe("2026-08-18")
    expect(days[0]).toBe("2026-07-21")
  })
})

describe("useMeasuredWidth", () => {
  /* Monte le hook sur un élément : la largeur mesurée est forcée par l'appelant. */
  function mountHook() {
    const Host = {
      setup() {
        const el = ref(null)
        return { el, width: useMeasuredWidth(el, 640) }
      },
      template: `<div ref="el">{{ width }}</div>`
    }
    return mount(Host)
  }

  it("mesure le conteneur dès le montage plutôt que d'attendre le ResizeObserver", async () => {
    /* Sans cela, un graphique de 328 px de large est rendu pour 640 px : tout le
       texte du SVG est deux fois trop petit jusqu'à la première notification. */
    const original = Object.getOwnPropertyDescriptor(Element.prototype, "clientWidth")
    Object.defineProperty(Element.prototype, "clientWidth", { configurable: true, get: () => 328 })
    try {
      const wrapper = mountHook()
      await nextTick()
      expect(wrapper.text()).toBe("328")
      wrapper.unmount()
    } finally {
      Object.defineProperty(Element.prototype, "clientWidth", original)
    }
  })

  it("garde la valeur de repli tant que l'élément n'a pas de largeur (hors flux)", async () => {
    const wrapper = mountHook()
    await nextTick()
    expect(wrapper.text()).toBe("640")
    wrapper.unmount()
  })
})

describe("zeroFillDays", () => {
  it("remplit les jours manquants avec les valeurs vides fournies", () => {
    const axis = lastDays(30, "2026-08-19")
    const sparse = [
      { day: "2026-08-18", hits: 30, uniques: 14 },
      { day: "2026-08-19", hits: 15, uniques: 8 }
    ]
    const filled = zeroFillDays(sparse, axis, { hits: 0, uniques: 0 })
    expect(filled).toHaveLength(30)
    expect(filled[0]).toEqual({ day: "2026-07-21", hits: 0, uniques: 0 })
    expect(filled[28]).toEqual({ day: "2026-08-18", hits: 30, uniques: 14 })
    expect(filled[29].hits).toBe(15)
    expect(filled.filter((entry) => entry.hits === 0)).toHaveLength(28)
  })

  it("tolère une liste absente", () => {
    expect(zeroFillDays(undefined, ["2026-08-19"], { count: 0 })).toEqual([{ day: "2026-08-19", count: 0 }])
  })
})
