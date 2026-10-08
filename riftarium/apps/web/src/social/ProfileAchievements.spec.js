import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import ProfileAchievements from "./ProfileAchievements.vue"
import { groupAchievements } from "../social.js"

const groups = groupAchievements([
  { key: "a", family: "duels", title: "A", description: "", tier: "bronze", unlocked_at: "2026-08-01T10:00:00Z" },
  { key: "b", family: "duels", title: "B", description: "", tier: "bronze", threshold: 3, current: 1 }
])

describe("ProfileAchievements", () => {
  it("affiche « débloqués / total » par défaut, dans le titre et dans les familles", () => {
    const wrapper = mount(ProfileAchievements, { props: { groups } })
    const counts = wrapper.findAll(".profil-hf-compte").map((el) => el.text())
    expect(counts).toEqual(["1 / 2", "1 / 2"])
  })

  it("showTotals à faux : seul le nombre de débloqués", () => {
    const wrapper = mount(ProfileAchievements, { props: { groups, showTotals: false } })
    const counts = wrapper.findAll(".profil-hf-compte").map((el) => el.text())
    expect(counts).toEqual(["1", "1"])
  })
})
