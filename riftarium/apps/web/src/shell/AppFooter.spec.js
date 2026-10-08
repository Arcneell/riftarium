import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import { LEGAL_NAV, RIOT_DISCLAIMER_EN, RIOT_GENERAL_DISCLAIMER_EN } from "../legal.js"
import { makeRouter } from "../test/makeRouter.js"
import AppFooter from "./AppFooter.vue"

describe("AppFooter", () => {
  it("reprend les mentions Riot obligatoires et les liens légaux, sans dupliquer la navigation", async () => {
    const router = await makeRouter("/")
    const wrapper = mount(AppFooter, { global: { plugins: [router] } })
    expect(wrapper.text()).toContain(RIOT_DISCLAIMER_EN)
    expect(wrapper.text()).toContain(RIOT_GENERAL_DISCLAIMER_EN)
    for (const item of LEGAL_NAV) expect(wrapper.text()).toContain(item.label)
    expect(wrapper.find("a[href='/cartes']").exists()).toBe(false)
    expect(wrapper.find("a[href='/scan']").exists()).toBe(false)
  })
})
