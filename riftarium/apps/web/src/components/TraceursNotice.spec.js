import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it } from "vitest"
import TraceursNotice from "./TraceursNotice.vue"
import { TRACEURS_ACK_KEY } from "../legal.js"

async function mountNotice() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/cookies", component: { template: "<div />" } }
    ]
  })
  router.push("/")
  await router.isReady()
  return mount(TraceursNotice, { global: { plugins: [router] } })
}

describe("TraceursNotice", () => {
  beforeEach(() => {
    localStorage.clear()
  })

  it("s'affiche tant que l'information n'a pas été lue", async () => {
    const wrapper = await mountNotice()
    expect(wrapper.find(".traceurs-notice").exists()).toBe(true)
    expect(wrapper.text()).toContain("strictement nécessaires")
    expect(wrapper.text()).toContain("statistiques de fréquentation anonymes et agrégées, sans cookie")
    expect(wrapper.get("a").attributes("href")).toBe("/cookies")
  })

  it("disparaît après J'ai compris et mémorise le choix", async () => {
    const wrapper = await mountNotice()
    await wrapper.get("button").trigger("click")
    expect(wrapper.find(".traceurs-notice").exists()).toBe(false)
    expect(localStorage.getItem(TRACEURS_ACK_KEY)).toBe("1")
  })
})
