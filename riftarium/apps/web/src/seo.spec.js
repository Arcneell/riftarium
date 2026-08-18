import { beforeEach, describe, expect, it } from "vitest"
import { applySeo, DEFAULT_DESCRIPTION, SITE_NAME } from "./seo.js"

describe("applySeo", () => {
  beforeEach(() => {
    document.head.innerHTML = ""
    document.title = ""
  })

  it("renseigne titre, description, canonical et Open Graph", () => {
    applySeo({
      title: "Cartes Riftbound",
      description: "Toutes les cartes.",
      path: "/cartes"
    })
    expect(document.title).toBe(`Cartes Riftbound · ${SITE_NAME}`)
    expect(document.head.querySelector('meta[name="description"]').content).toBe("Toutes les cartes.")
    expect(document.head.querySelector('link[rel="canonical"]').href).toMatch(/\/cartes$/)
    expect(document.head.querySelector('meta[property="og:title"]').content).toContain("Cartes Riftbound")
    expect(document.head.querySelector('meta[name="robots"]').content).toBe("index, follow")
  })

  it("marque les pages privées en noindex", () => {
    applySeo({ title: "Profil", path: "/profil", noindex: true })
    expect(document.head.querySelector('meta[name="robots"]').content).toBe("noindex, nofollow")
    expect(document.head.querySelector('meta[name="description"]').content).toBe(DEFAULT_DESCRIPTION)
  })
})
