import { describe, expect, it } from "vitest"
import { escapeHtml } from "./htmlText.js"

describe("escapeHtml", () => {
  it("échappe les caractères dangereux, apostrophe comprise", () => {
    expect(escapeHtml(`<img src=x onerror="alert('xss')"> & fin`)).toBe(
      "&lt;img src=x onerror=&quot;alert(&#39;xss&#39;)&quot;&gt; &amp; fin"
    )
  })

  it("laisse intact un texte sans caractère spécial", () => {
    expect(escapeHtml("Règle 101.2 — les runes.")).toBe("Règle 101.2 — les runes.")
  })

  it("accepte les valeurs non textuelles en les convertissant", () => {
    expect(escapeHtml(42)).toBe("42")
  })
})
