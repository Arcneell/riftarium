import { flushPromises } from "@vue/test-utils"
import { nextTick, ref } from "vue"
import { beforeEach, describe, expect, it, vi } from "vitest"
import { useOwnedCopies } from "./useOwnedCopies.js"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const state = (entries, id = "c1") => ({
  card_id: id,
  total_qty: entries.reduce((n, e) => n + e.qty, 0),
  entries
})
const lot = (id, qty, condition = "NM", lang = "FR") => ({ id, qty, condition, lang })

function deferred() {
  let resolve, reject
  const promise = new Promise((res, rej) => {
    resolve = res
    reject = rej
  })
  return { promise, resolve, reject }
}

describe("useOwnedCopies", () => {
  beforeEach(() => {
    api.mockReset()
    localStorage.clear()
    session.token = "1"
  })

  it("charge les lots quand la carte change, si connecté", async () => {
    api.mockResolvedValue(state([lot(1, 2)]))
    const cardId = ref("c1")
    const owned = useOwnedCopies(cardId)
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/collection/c1")
    expect(owned.entries.value).toEqual([lot(1, 2)])
    expect(owned.total.value).toBe(2)
  })

  it("ne charge pas sans session ni avec autoload à false", async () => {
    session.token = null
    useOwnedCopies(ref("c1"))
    session.token = "1"
    useOwnedCopies(ref("c1"), { autoload: false })
    await flushPromises()
    expect(api).not.toHaveBeenCalled()
  })

  it("increment envoie les préférences et prévient onChange", async () => {
    const onChange = vi.fn()
    const owned = useOwnedCopies(ref("c1"), { onChange, autoload: false })
    owned.setDefaults({ condition: "EX", lang: "EN" })
    expect(JSON.parse(localStorage.getItem("riftarium_collection_defaults"))).toEqual({ condition: "EX", lang: "EN" })
    api.mockResolvedValue(state([lot(5, 1, "EX", "EN")]))
    await owned.increment()
    expect(api).toHaveBeenCalledWith("/api/collection/c1/entries", {
      method: "POST",
      body: { qty: 1, condition: "EX", lang: "EN" }
    })
    expect(owned.total.value).toBe(1)
    expect(onChange).toHaveBeenCalledWith({ id: "c1", owned_qty: 1 })
  })

  it("decrement choisit le lot des préférences, sinon le plus grand id", async () => {
    const owned = useOwnedCopies(ref("c1"), { autoload: false })
    api.mockResolvedValueOnce(state([lot(1, 1, "NM", "FR"), lot(7, 2, "EX", "EN"), lot(3, 1, "NM", "EN")]))
    await owned.load()
    api.mockResolvedValueOnce(state([lot(7, 2, "EX", "EN"), lot(3, 1, "NM", "EN")]))
    await owned.decrement() // défauts NM / FR : lot 1
    expect(api).toHaveBeenLastCalledWith("/api/collection/entries/1", { method: "PATCH", body: { qty: 0 } })
    api.mockResolvedValueOnce(state([lot(7, 1, "EX", "EN"), lot(3, 1, "NM", "EN")]))
    await owned.decrement() // plus de NM / FR : plus grand id = 7
    expect(api).toHaveBeenLastCalledWith("/api/collection/entries/7", { method: "PATCH", body: { qty: 1 } })
  })

  it("decrement sans exemplaire n'envoie rien", async () => {
    const owned = useOwnedCopies(ref("c1"), { autoload: false })
    await owned.decrement()
    expect(api).not.toHaveBeenCalled()
  })

  it("ignore une mutation lancée pendant busy", async () => {
    const pending = deferred()
    api.mockReturnValue(pending.promise)
    const owned = useOwnedCopies(ref("c1"), { autoload: false })
    const first = owned.increment()
    await nextTick()
    expect(owned.busy.value).toBe(true)
    await owned.increment()
    expect(api).toHaveBeenCalledTimes(1)
    pending.resolve(state([lot(1, 1)]))
    await first
    expect(owned.busy.value).toBe(false)
  })

  it("oublie une réponse arrivée après un changement de carte", async () => {
    const pending = deferred()
    api.mockReturnValueOnce(pending.promise)
    const onChange = vi.fn()
    const cardId = ref("c1")
    const owned = useOwnedCopies(cardId, { onChange, autoload: false })
    const run = owned.increment()
    cardId.value = "c2"
    pending.resolve(state([lot(1, 1)]))
    await run
    expect(owned.entries.value).toEqual([])
    expect(onChange).not.toHaveBeenCalled()
    expect(owned.busy.value).toBe(false)
  })

  it("garde l'erreur et l'état intact", async () => {
    const owned = useOwnedCopies(ref("c1"), { autoload: false })
    api.mockResolvedValueOnce(state([lot(1, 1)]))
    await owned.load()
    api.mockRejectedValueOnce(new Error("Serveur indisponible"))
    await owned.increment()
    expect(owned.error.value).toBe("Serveur indisponible")
    expect(owned.entries.value).toEqual([lot(1, 1)])
    expect(owned.busy.value).toBe(false)
  })

  it("ignore la réponse d'un chargement lancé avant un changement de carte", async () => {
    const first = deferred()
    api.mockReturnValueOnce(first.promise)
    const cardId = ref("c1")
    const owned = useOwnedCopies(cardId)
    api.mockResolvedValueOnce(state([lot(9, 4)], "c2"))
    cardId.value = "c2"
    await flushPromises()
    first.resolve(state([lot(1, 1)]))
    await flushPromises()
    expect(owned.entries.value).toEqual([lot(9, 4)])
    expect(owned.loading.value).toBe(false)
  })

  it("une mutation pendant un chargement l'emporte sur la réponse tardive du GET", async () => {
    const get = deferred()
    api.mockReturnValueOnce(get.promise)
    const owned = useOwnedCopies(ref("c1"))
    api.mockResolvedValueOnce(state([lot(2, 1)]))
    await owned.increment()
    get.resolve(state([]))
    await flushPromises()
    expect(owned.entries.value).toEqual([lot(2, 1)])
    expect(owned.total.value).toBe(1)
    expect(owned.loading.value).toBe(false)
  })

  it("c1 puis c2 puis c1 : la mutation lancée sur le premier c1 est ignorée", async () => {
    const post = deferred()
    const onChange = vi.fn()
    const cardId = ref("c1")
    const owned = useOwnedCopies(cardId, { onChange, autoload: false })
    api.mockReturnValueOnce(post.promise)
    const run = owned.increment()
    cardId.value = "c2"
    await nextTick()
    cardId.value = "c1"
    await nextTick()
    post.resolve(state([lot(1, 1)]))
    await run
    expect(owned.entries.value).toEqual([])
    expect(onChange).not.toHaveBeenCalled()
    expect(owned.busy.value).toBe(false)
  })

  it("changement de carte sans autoload : les lots de l'ancienne carte sont oubliés, « − » ne fait rien", async () => {
    const cardId = ref("c1")
    const owned = useOwnedCopies(cardId, { autoload: false })
    api.mockResolvedValueOnce(state([lot(1, 2)]))
    await owned.load()
    expect(owned.entries.value).toHaveLength(1)
    cardId.value = "c2"
    await nextTick()
    expect(owned.entries.value).toEqual([])
    api.mockClear()
    expect(owned.decrement()).toBe(false)
    expect(api).not.toHaveBeenCalled()
  })

  it("changement de carte pendant un load : la réponse de l'ancienne carte est ignorée et le chargement s'arrête", async () => {
    const slow = deferred()
    api.mockReturnValueOnce(slow.promise)
    const cardId = ref("c1")
    const owned = useOwnedCopies(cardId, { autoload: false })
    const pending = owned.load()
    expect(owned.loading.value).toBe(true)
    cardId.value = "c2"
    await nextTick()
    expect(owned.loading.value).toBe(false)
    slow.resolve(state([lot(1, 4)]))
    await pending
    expect(owned.entries.value).toEqual([])
    expect(owned.error.value).toBe("")
  })

  it("changement de carte : l'erreur de la précédente est effacée", async () => {
    api.mockRejectedValueOnce(new Error("Hors ligne"))
    const cardId = ref("c1")
    const owned = useOwnedCopies(cardId, { autoload: false })
    await owned.load()
    expect(owned.error.value).toBe("Hors ligne")
    cardId.value = "c2"
    await nextTick()
    expect(owned.error.value).toBe("")
  })

  it("setLotQty ajuste un lot précis par PATCH, 0 le supprime", async () => {
    const onChange = vi.fn()
    const owned = useOwnedCopies(ref("c1"), { autoload: false, onChange })
    api.mockResolvedValueOnce(state([lot(7, 2), lot(8, 1, "PL", "EN")]))
    await owned.setLotQty(7, 2)
    expect(api).toHaveBeenLastCalledWith("/api/collection/entries/7", { method: "PATCH", body: { qty: 2 } })
    expect(onChange).toHaveBeenCalledWith({ id: "c1", owned_qty: 3 })
    api.mockResolvedValueOnce(state([lot(8, 1, "PL", "EN")]))
    await owned.setLotQty(7, 0)
    expect(owned.entries.value).toEqual([lot(8, 1, "PL", "EN")])
  })

  it("setLotQty est ignoré pendant une autre opération (busy)", async () => {
    const owned = useOwnedCopies(ref("c1"), { autoload: false })
    const slow = deferred()
    api.mockReturnValueOnce(slow.promise)
    const first = owned.increment()
    expect(await owned.setLotQty(7, 1)).toBe(false)
    expect(api).toHaveBeenCalledTimes(1)
    slow.resolve(state([lot(1, 1)]))
    await first
  })

  it("addLot et removeLot passent par POST et PATCH", async () => {
    const owned = useOwnedCopies(ref("c1"), { autoload: false })
    api.mockResolvedValueOnce(state([lot(2, 3, "GD", "DE")]))
    await owned.addLot({ qty: 3, condition: "GD", lang: "DE" })
    expect(api).toHaveBeenLastCalledWith("/api/collection/c1/entries", {
      method: "POST",
      body: { qty: 3, condition: "GD", lang: "DE" }
    })
    api.mockResolvedValueOnce(state([]))
    await owned.removeLot(owned.entries.value[0])
    expect(api).toHaveBeenLastCalledWith("/api/collection/entries/2", { method: "PATCH", body: { qty: 0 } })
    expect(owned.total.value).toBe(0)
  })
})
