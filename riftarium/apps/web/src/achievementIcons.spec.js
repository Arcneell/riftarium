import { describe, expect, it } from "vitest"
import { achievementIconPaths } from "./achievementIcons.js"

/* Clés du catalogue de l'API (apps/api/app/achievements.py). */
const CATALOGUE_KEYS = [
  "first_blood",
  "veteran_10",
  "veteran_50",
  "veteran_200",
  "winner_10",
  "winner_50",
  "winner_100",
  "streak_3",
  "streak_5",
  "streak_10",
  "six_domains",
  "giant_slayer",
  "marathon",
  "collector_100",
  "collector_500",
  "collector_1000",
  "set_complete",
  "showcase_10",
  "architect_1",
  "architect_5",
  "architect_20",
  "crowd_favorite",
  "legal_eagle",
  "sociable_5",
  "regular"
]

describe("achievementIconPaths", () => {
  it("donne un dessin distinct à chaque haut fait du catalogue", () => {
    const drawings = CATALOGUE_KEYS.map((key) => JSON.stringify(achievementIconPaths(key, "")))
    expect(new Set(drawings).size).toBe(CATALOGUE_KEYS.length)
  })

  it("retombe sur le nom d'icône Material, puis sur l'étoile", () => {
    const byIcon = achievementIconPaths("haut_fait_inconnu", "shield")
    expect(byIcon).toEqual(achievementIconPaths("veteran_10", ""))
    const star = achievementIconPaths("haut_fait_inconnu", "icone_inconnue")
    expect(star).toHaveLength(1)
    expect(star[0]).toContain("M12 3.5")
  })
})
