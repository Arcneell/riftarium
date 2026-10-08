import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it } from "vitest"
import { session } from "../api.js"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import AppTopbar from "./AppTopbar.vue"
import { clearPageCrumb, setPageCrumb } from "./pageCrumb.js"

async function mountBar(path, props = {}) {
  const router = await makeRouter(path)
  return mount(AppTopbar, { props, global: { plugins: [router], components: { Icon } } })
}

describe("AppTopbar", () => {
  afterEach(() => {
    clearPageCrumb()
    Object.assign(session, { token: null, handle: null })
  })

  it("bureau : fil d'Ariane, dernier maillon non cliquable", async () => {
    setPageCrumb("Ahri")
    const wrapper = await mountBar("/cartes/ogn-001")
    const items = wrapper.findAll(".crumbs li")
    expect(items.map((li) => li.text())).toEqual(["Cartes", "Ahri"])
    expect(items[0].find("a").exists()).toBe(true)
    expect(items[1].get("[aria-current=page]").text()).toBe("Ahri")
  })

  it("bureau : le déclencheur de recherche émet search", async () => {
    const wrapper = await mountBar("/")
    await wrapper.get(".search-trigger").trigger("click")
    expect(wrapper.emitted("search")).toHaveLength(1)
  })

  it("téléphone : logo, loupe et compte ; plus de fil d'Ariane", async () => {
    const wrapper = await mountBar("/decks", { mobile: true })
    expect(wrapper.find(".crumbs").exists()).toBe(false)
    await wrapper.get("[aria-label=Rechercher]").trigger("click")
    await wrapper.get(".topbar-account").trigger("click")
    expect(wrapper.emitted("search")).toHaveLength(1)
    expect(wrapper.emitted("account")).toHaveLength(1)
  })
})
