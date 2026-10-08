import { beforeEach, describe, expect, it, vi } from "vitest"
import { readDefaults, writeDefaults } from "./collectionDefaults.js"

const KEY = "riftarium_collection_defaults"

describe("collectionDefaults", () => {
  beforeEach(() => {
    localStorage.clear()
    vi.restoreAllMocks()
  })

  it("renvoie NM / FR sans préférence", () => {
    expect(readDefaults()).toEqual({ condition: "NM", lang: "FR" })
  })

  it("persiste puis relit les préférences", () => {
    writeDefaults({ condition: "EX", lang: "EN" })
    expect(JSON.parse(localStorage.getItem(KEY))).toEqual({ condition: "EX", lang: "EN" })
    expect(readDefaults()).toEqual({ condition: "EX", lang: "EN" })
  })

  it("ignore les valeurs invalides champ par champ", () => {
    localStorage.setItem(KEY, JSON.stringify({ condition: "ZZ", lang: "DE" }))
    expect(readDefaults()).toEqual({ condition: "NM", lang: "DE" })
    localStorage.setItem(KEY, "pas du json")
    expect(readDefaults()).toEqual({ condition: "NM", lang: "FR" })
    localStorage.setItem(KEY, "null")
    expect(readDefaults()).toEqual({ condition: "NM", lang: "FR" })
  })

  it("reste silencieux quand le stockage est bloqué", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("bloqué")
    })
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("bloqué")
    })
    expect(readDefaults()).toEqual({ condition: "NM", lang: "FR" })
    expect(() => writeDefaults({ condition: "EX", lang: "EN" })).not.toThrow()
  })
})
