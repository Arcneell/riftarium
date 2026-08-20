import { beforeEach, describe, expect, it, vi } from "vitest"
import { cardmarketUrl, formatEur, resetPricesMeta, usePricesMeta, PRICE_NOTE } from "./prices.js"
import { api } from "./api.js"

vi.mock("./api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

/* Les espaces insécables (fines ou non) d'Intl varient selon l'ICU : on normalise. */
const plain = (value) => value.replace(/[\u202f\u00a0]/g, " ")

describe("formatEur", () => {
  it("formate en euros à la française", () => {
    expect(plain(formatEur(13.3))).toBe("13,30 €")
    expect(plain(formatEur(0))).toBe("0,00 €")
    expect(plain(formatEur(1234.5))).toBe("1 234,50 €")
    expect(plain(formatEur("2.5"))).toBe("2,50 €")
  })

  it("retourne null quand il n'y a pas de prix exploitable", () => {
    expect(formatEur(null)).toBeNull()
    expect(formatEur(undefined)).toBeNull()
    expect(formatEur("")).toBeNull()
    expect(formatEur("n/a")).toBeNull()
  })
})

describe("cardmarketUrl", () => {
  it("encode le nom de la carte dans la recherche Cardmarket", () => {
    expect(cardmarketUrl("Immortal Phoenix")).toBe(
      "https://www.cardmarket.com/fr/Riftbound/Products/Search?searchString=Immortal%20Phoenix"
    )
    expect(cardmarketUrl("Vi & Jinx ?")).toContain("searchString=Vi%20%26%20Jinx%20%3F")
  })
})

describe("usePricesMeta", () => {
  beforeEach(() => {
    api.mockReset()
    resetPricesMeta()
  })

  it("charge la méta une seule fois puis sert le cache module", async () => {
    api.mockResolvedValue({
      updated_day: "2026-08-19",
      rate: 0.92,
      rate_date: "2026-08-19",
      priced_cards: 512,
      source: "tcgplayer",
      currency_note: "Prix du marché US (TCGplayer), convertis en euros au taux BCE — estimation indicative."
    })
    const meta = usePricesMeta()
    expect(api).toHaveBeenCalledWith("/api/prices/meta")
    await vi.waitFor(() => expect(meta.loaded).toBe(true))
    expect(meta.updated_day).toBe("2026-08-19")

    usePricesMeta()
    usePricesMeta()
    expect(api).toHaveBeenCalledTimes(1)
  })

  it("reste muet si la méta est indisponible", async () => {
    api.mockRejectedValue(new Error("boom"))
    const meta = usePricesMeta()
    await Promise.resolve()
    expect(meta.loaded).toBe(false)
    expect(meta.currency_note).toBe("")
  })
})

describe("PRICE_NOTE", () => {
  it("mentionne la source US et l'absence de cote officielle, sans impliquer Cardmarket", () => {
    expect(PRICE_NOTE).toContain("TCGplayer")
    expect(PRICE_NOTE).toContain("taux BCE")
    expect(PRICE_NOTE).toContain("Ni cote officielle ni offre d'achat")
    expect(PRICE_NOTE).not.toContain("Cardmarket")
  })
})
