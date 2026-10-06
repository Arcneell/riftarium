import { flushPromises, mount } from "@vue/test-utils"
import { defineComponent, h, ref } from "vue"
import { beforeEach, describe, expect, it, vi } from "vitest"
import { GHOST_FILTERS, useCollectionBinder } from "./useCollectionBinder.js"
import { api } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

function fakeCard(index, ownedQty) {
  return { id: `card-${index}`, name: `Carte ${index}`, owned_qty: ownedQty }
}

/* Hôte minimal : monte le composable et expose son retour, comme le fera la page. */
function mountBinder({ active = true, blocked = false } = {}) {
  const activeRef = ref(active)
  const blockedRef = ref(blocked)
  let binder
  const Host = defineComponent({
    setup() {
      binder = useCollectionBinder({ active: () => activeRef.value, isBlocked: () => blockedRef.value })
      return () => h("div")
    }
  })
  const wrapper = mount(Host)
  return { wrapper, binder, activeRef, blockedRef }
}

function pathsCalled() {
  return api.mock.calls.map(([path]) => String(path))
}

function key(name, init = {}, target = window) {
  const event = new KeyboardEvent("keydown", { key: name, bubbles: true, cancelable: true, ...init })
  target.dispatchEvent(event)
  return event
}

/* Ouvre un set et attend la première double page. */
async function openSet(binder, id = "OGN") {
  binder.selectSet(id)
  await flushPromises()
}

describe("useCollectionBinder", () => {
  beforeEach(() => {
    api.mockReset()
    api.mockImplementation(() =>
      Promise.resolve({ total: 298, page: 1, size: 18, items: [fakeCard(1, 3), fakeCard(9, 0)] })
    )
  })

  it("exporte les trois filtres de pochettes", () => {
    expect(GHOST_FILTERS.map((chip) => chip.value)).toEqual(["", "1", "0"])
  })

  it("clic sur un set : ouvre ce set à la première page et complète les pages de 9 cases", async () => {
    const { binder } = mountBinder()
    await openSet(binder, "SFD")
    expect(
      pathsCalled().some((path) => path.includes("set_id=SFD") && path.includes("page=1") && path.includes("size=18"))
    ).toBe(true)
    expect(binder.spread.value).toMatchObject({ key: "SFD||1", page: 1, pages: 17, total: 298 })
    expect(binder.spread.value).not.toHaveProperty("deal")
    expect(binder.leftCards.value).toHaveLength(9)
    expect(binder.rightCards.value).toHaveLength(9)
    expect(binder.leftCards.value[0].id).toBe("card-1")
    expect(binder.leftCards.value[2]).toBeNull()
  })

  it("chips : « Manquantes » filtre la double page sur owned=0", async () => {
    const { binder } = mountBinder()
    await openSet(binder)
    api.mockClear()
    binder.setGhostFilter("0")
    await flushPromises()
    expect(pathsCalled().some((path) => path.includes("owned=0"))).toBe(true)
    expect(binder.binderPage.value).toBe(1)
  })

  it("tourner la page : demande la double page suivante du set", async () => {
    const { binder } = mountBinder()
    await openSet(binder)
    api.mockClear()
    binder.turnPage(1)
    await flushPromises()
    expect(pathsCalled().some((path) => path.includes("page=2"))).toBe(true)
    expect(binder.turnDir.value).toBe(1)
  })

  it("tourner avant la première page ne fait rien", async () => {
    const { binder } = mountBinder()
    await openSet(binder)
    api.mockClear()
    binder.turnPage(-1)
    await flushPromises()
    expect(api).not.toHaveBeenCalled()
  })

  it("tourner au-delà de la dernière page ne fait rien", async () => {
    api.mockImplementation(() => Promise.resolve({ total: 20, page: 2, size: 18, items: [fakeCard(1, 1)] }))
    const { binder } = mountBinder()
    binder.selectSet("OGN")
    binder.turnPage(1)
    await flushPromises()
    expect(binder.binderPage.value).toBe(2)
    expect(binder.spread.value.pages).toBe(2)
    api.mockClear()
    binder.turnPage(1)
    await flushPromises()
    expect(binder.binderPage.value).toBe(2)
    expect(api).not.toHaveBeenCalled()
  })

  it("flèches du clavier : feuillettent le classeur", async () => {
    const { binder } = mountBinder()
    await openSet(binder)
    api.mockClear()
    const event = new KeyboardEvent("keydown", { key: "ArrowRight", cancelable: true })
    binder.onKeydown(event)
    await flushPromises()
    expect(event.defaultPrevented).toBe(true)
    expect(pathsCalled().some((path) => path.includes("page=2"))).toBe(true)
    binder.onKeydown(new KeyboardEvent("keydown", { key: "ArrowLeft" }))
    await flushPromises()
    expect(binder.binderPage.value).toBe(1)
  })

  it("flèches ignorées dans un champ, avec un modificateur ou quand isBlocked()", async () => {
    const { binder, blockedRef, activeRef } = mountBinder()
    await openSet(binder)
    api.mockClear()

    const input = document.createElement("input")
    document.body.appendChild(input)
    const fromInput = new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true })
    input.dispatchEvent(fromInput)
    binder.onKeydown(
      Object.defineProperty(new KeyboardEvent("keydown", { key: "ArrowRight" }), "target", { value: input })
    )
    for (const modifier of ["altKey", "ctrlKey", "metaKey"]) {
      binder.onKeydown(new KeyboardEvent("keydown", { key: "ArrowRight", [modifier]: true }))
    }
    const prevented = new KeyboardEvent("keydown", { key: "ArrowRight", cancelable: true })
    prevented.preventDefault()
    binder.onKeydown(prevented)
    blockedRef.value = true
    binder.onKeydown(new KeyboardEvent("keydown", { key: "ArrowRight" }))
    blockedRef.value = false
    activeRef.value = false
    binder.onKeydown(new KeyboardEvent("keydown", { key: "ArrowRight" }))
    await flushPromises()
    expect(api).not.toHaveBeenCalled()
    expect(binder.binderPage.value).toBe(1)
    input.remove()
  })

  it("n'enregistre aucun écouteur global", async () => {
    const { binder } = mountBinder()
    await openSet(binder)
    api.mockClear()
    key("ArrowRight")
    await flushPromises()
    expect(api).not.toHaveBeenCalled()
  })

  it("une réponse tardive d'un set précédent est ignorée", async () => {
    const pending = {}
    api.mockImplementation((path) => {
      const setId = new URLSearchParams(String(path).split("?")[1]).get("set_id")
      return new Promise((resolve) => {
        pending[setId] = () => resolve({ total: 18, page: 1, size: 18, items: [fakeCard(setId === "OGN" ? 1 : 2, 1)] })
      })
    })
    const { binder } = mountBinder()
    binder.selectSet("OGN")
    await flushPromises()
    binder.selectSet("SFD")
    await flushPromises()
    pending.SFD()
    await flushPromises()
    expect(binder.spread.value.key).toBe("SFD||1")
    expect(binder.binderLoading.value).toBe(false)
    pending.OGN()
    await flushPromises()
    expect(binder.spread.value.key).toBe("SFD||1")
    expect(binder.spread.value.items[0].id).toBe("card-2")
  })

  it("une erreur d'API est exposée dans binderError", async () => {
    api.mockRejectedValue(new Error("Hors ligne"))
    const { binder } = mountBinder()
    await openSet(binder)
    expect(binder.binderError.value).toBe("Hors ligne")
    expect(binder.binderLoading.value).toBe(false)
  })

  it("ne charge rien tant que le classeur est inactif", async () => {
    const { binder } = mountBinder({ active: false })
    await openSet(binder)
    expect(api).not.toHaveBeenCalled()
  })
})
