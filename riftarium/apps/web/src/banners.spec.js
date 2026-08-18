import { describe, expect, it } from "vitest"
import { BANNERS, bannerUrl } from "./banners.js"

describe("banners", () => {
  it("pointe uniquement vers le CDN officiel Riot", () => {
    expect(bannerUrl("abc-1600x900.jpg")).toBe(
      "https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/abc-1600x900.jpg?auto=format&w=1600"
    )
    for (const url of Object.values(BANNERS)) {
      expect(url).toMatch(/^https:\/\/cmsassets\.rgpub\.io\/sanity\/images\/dsfx7636\/news_live\//)
      expect(url).toContain("auto=format")
    }
  })

  it("donne une illustration distincte à chaque fonction de page", () => {
    expect(new Set([BANNERS.cards, BANNERS.decks, BANNERS.collection, BANNERS.community, BANNERS.rules]).size).toBe(5)
  })
})
