import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import { useScrollMemory } from "./useScrollMemory.js"

const Grid = {
  template: "<div />",
  setup() {
    return useScrollMemory()
  }
}

const Blank = { template: "<div />" }

async function visitCards(fullPath = "/cartes?page=2") {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/cartes", component: Grid },
      { path: "/cartes/:id", component: Blank },
      { path: "/decks", component: Blank }
    ]
  })
  router.push(fullPath)
  await router.isReady()
  mount({ template: "<RouterView />" }, { global: { plugins: [router] } })
  await router.isReady()
  return router
}

describe("useScrollMemory", () => {
  beforeEach(() => {
    sessionStorage.clear()
    window.scrollY = 900
    vi.spyOn(window, "scrollTo").mockImplementation(() => {})
  })

  it("retient la position en partant vers une fiche carte", async () => {
    const router = await visitCards()
    await router.push("/cartes/ogn-037")
    expect(sessionStorage.getItem("scroll:/cartes?page=2")).toBe("900")
  })

  it("oublie la position en partant vers une autre rubrique", async () => {
    const router = await visitCards()
    await router.push("/decks")
    expect(sessionStorage.getItem("scroll:/cartes?page=2")).toBeNull()
  })
})
