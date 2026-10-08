import { afterEach, describe, expect, it, vi } from "vitest"
import { ref } from "vue"
import { useDeckDrag } from "./useDeckDrag.js"

const card = { id: "u1", name: "Phénix" }

function setup(overrides = {}) {
  const panelEl = document.createElement("div")
  panelEl.getBoundingClientRect = () => ({ left: 500, right: 800, top: 0, bottom: 600 })
  const options = {
    enabled: () => true,
    finePointer: true,
    reducedMotion: true,
    panel: ref(panelEl),
    onDropAdd: vi.fn(() => true),
    onDropRemove: vi.fn(),
    onStart: vi.fn(),
    ...overrides
  }
  const api = useDeckDrag(options)
  return { ...api, options }
}

const down = (api, from = "gallery", extra = {}) =>
  api.onTilePointerDown(card, from, {
    pointerType: "mouse",
    button: 0,
    clientX: 100,
    clientY: 100,
    target: document.createElement("div"),
    ...extra
  })
const move = (x, y) => window.dispatchEvent(new MouseEvent("pointermove", { clientX: x, clientY: y }))
const up = () => window.dispatchEvent(new MouseEvent("pointerup"))
const settle = () => new Promise((resolve) => setTimeout(resolve, 0))

let current
afterEach(() => {
  current?.dispose()
  current = null
})

describe("useDeckDrag", () => {
  it("un déplacement de moins de 8 px n'active pas le glisser", () => {
    current = setup()
    down(current)
    move(105, 105)
    expect(current.drag.active).toBe(false)
    expect(current.options.onStart).not.toHaveBeenCalled()
    expect(document.body.classList.contains("drag-active")).toBe(false)
    move(120, 100)
    expect(current.drag.active).toBe(true)
    expect(current.options.onStart).toHaveBeenCalledOnce()
    up()
  })

  it("déposer sur le panneau appelle onDropAdd", async () => {
    current = setup()
    down(current, "gallery")
    move(300, 100)
    move(600, 100)
    expect(current.drag.overDeck).toBe(true)
    up()
    expect(current.suppressClick()).toBe(true)
    await settle()
    expect(current.options.onDropAdd).toHaveBeenCalledWith(card)
    expect(current.options.onDropRemove).not.toHaveBeenCalled()
    expect(current.drag.active).toBe(false)
    expect(current.suppressClick()).toBe(false)
  })

  it("relâcher hors du panneau depuis le deck appelle onDropRemove", async () => {
    current = setup()
    down(current, "deck")
    move(300, 100)
    up()
    await settle()
    expect(current.options.onDropRemove).toHaveBeenCalledWith("u1")
    expect(current.options.onDropAdd).not.toHaveBeenCalled()
  })

  it("toucher (pointerType touch) n'active rien", () => {
    current = setup()
    down(current, "gallery", { pointerType: "touch" })
    move(300, 100)
    expect(current.drag.active).toBe(false)
  })

  it("dispose retire les écouteurs", () => {
    current = setup()
    down(current)
    move(300, 100)
    expect(document.body.classList.contains("drag-active")).toBe(true)
    const spy = vi.spyOn(window, "removeEventListener")
    current.dispose()
    expect(spy).toHaveBeenCalledWith("pointermove", expect.any(Function))
    expect(spy).toHaveBeenCalledWith("pointerup", expect.any(Function))
    expect(document.body.classList.contains("drag-active")).toBe(false)
    spy.mockRestore()
  })
})
