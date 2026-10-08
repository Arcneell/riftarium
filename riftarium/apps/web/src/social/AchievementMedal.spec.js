import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import AchievementMedal from "./AchievementMedal.vue"

describe("AchievementMedal", () => {
  it("rend une médaille de rang, avec le tracé du haut fait", () => {
    const wrapper = mount(AchievementMedal, { props: { achievementKey: "first_blood", tier: "silver" } })
    expect(wrapper.classes()).toContain("trophee-silver")
    expect(wrapper.classes()).not.toContain("trophee-verrouille")
    /* Débloquée : décorative, le rang est écrit à côté. */
    expect(wrapper.attributes("aria-hidden")).toBe("true")
    expect(wrapper.attributes("role")).toBeUndefined()
    expect(wrapper.attributes("aria-label")).toBeUndefined()
    expect(wrapper.findAll("svg path").length).toBeGreaterThan(0)
  })

  it("rang inconnu ou absent : retombe sur le bronze", () => {
    expect(mount(AchievementMedal).classes()).toContain("trophee-bronze")
    expect(mount(AchievementMedal, { props: { tier: "mythique" } }).classes()).toContain("trophee-bronze")
  })

  it("médaille verrouillée : classe et aria-label", () => {
    const wrapper = mount(AchievementMedal, { props: { achievementKey: "first_blood", tier: "gold", locked: true } })
    expect(wrapper.classes()).toContain("trophee-verrouille")
    expect(wrapper.classes()).toContain("trophee-gold")
    expect(wrapper.attributes("role")).toBe("img")
    expect(wrapper.attributes("aria-hidden")).toBeUndefined()
    expect(wrapper.attributes("aria-label")).toBe("Médaille or, verrouillée")
  })
})
