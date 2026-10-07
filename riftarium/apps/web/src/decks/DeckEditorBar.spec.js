import { flushPromises, mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import Icon from "../components/Icon.vue"
import { makeRouter } from "../test/makeRouter.js"
import DeckEditorBar from "./DeckEditorBar.vue"
import barSource from "./DeckEditorBar.vue?raw"

const baseDeck = {
  id: 1,
  name: "Fureur",
  format: "tournament",
  is_public: false,
  moderation_status: "published",
  likes: 2,
  liked_by_me: false,
  views: 5
}

async function mountBar(props = {}) {
  const router = await makeRouter("/decks/1/edit")
  const wrapper = mount(DeckEditorBar, {
    props: { deck: baseDeck, canEdit: true, saveState: "", error: "", likeBusy: false, ...props },
    global: { plugins: [router], components: { Icon } }
  })
  await flushPromises()
  return wrapper
}

const publicChip = (wrapper) => wrapper.findAll("button").find((b) => b.text() === "Public")

describe("DeckEditorBar", () => {
  it("format : RiftChoice émet update:format", async () => {
    const wrapper = await mountBar()
    const radios = wrapper.findAll('[role="radio"]')
    expect(radios.map((r) => r.text())).toEqual(["Légal", "Illégal"])
    expect(radios[0].attributes("aria-checked")).toBe("true")
    await radios[1].trigger("click")
    expect(wrapper.emitted("update:format")[0]).toEqual(["free"])
  })

  it("Public : aria-pressed et update:public", async () => {
    const wrapper = await mountBar()
    expect(publicChip(wrapper).attributes("aria-pressed")).toBe("false")
    await publicChip(wrapper).trigger("click")
    expect(wrapper.emitted("update:public")[0]).toEqual([true])

    await wrapper.setProps({ deck: { ...baseDeck, is_public: true } })
    expect(publicChip(wrapper).attributes("aria-pressed")).toBe("true")
  })

  it("état de sauvegarde annoncé", async () => {
    const wrapper = await mountBar()
    const save = wrapper.get(".atelier-save")
    expect(save.attributes("role")).toBe("status")
    expect(save.classes()).toContain("idle")
    expect(save.text()).toBe("")
    await wrapper.setProps({ saveState: "saving" })
    expect(save.text()).toBe("Enregistrement…")
    expect(save.classes()).not.toContain("idle")
    await wrapper.setProps({ saveState: "saved" })
    expect(save.text()).toBe("Enregistré")
    await wrapper.setProps({ saveState: "error" })
    expect(save.text()).toBe("Erreur de sauvegarde")
    expect(save.classes()).toContain("error")
  })

  it("nom long : input avec min-width 0 (classe)", async () => {
    const long = "A".repeat(80)
    const wrapper = await mountBar({ deck: { ...baseDeck, name: long } })
    const input = wrapper.get("input.atelier-name")
    expect(input.attributes("maxlength")).toBe("80")
    expect(input.attributes("aria-label")).toBe("Nom du deck")
    expect(input.element.value).toBe(long)
    await input.setValue("Nouveau nom")
    expect(wrapper.emitted("update:name")[0]).toEqual(["Nouveau nom"])
    /* jsdom ne calcule pas la mise en page : on vérifie la règle de la classe. */
    expect(barSource).toMatch(/\.atelier-name\s*\{[^}]*min-width:\s*0/)
  })

  it("toast de sauvegarde : une seule fois la barre d'onglets, juste sous les modales", () => {
    const toast = barSource.match(/\.atelier-save:not\(\.idle\)\s*\{([^}]*)\}/)[1]
    /* --shell-bottom contient déjà --tabbar-h et la zone de sécurité. */
    expect(toast).toMatch(
      /bottom:\s*calc\(var\(--shell-bottom, env\(safe-area-inset-bottom, 0px\)\) \+ var\(--space-3\)\)/
    )
    expect(toast).not.toMatch(/72px|tabbar-h/)
    expect(toast).toMatch(/z-index:\s*calc\(var\(--z-overlay\) - 1\)/)
  })

  it("pas de titre en lecture seule : la barre ne sert qu'en édition", () => {
    expect(barSource).not.toMatch(/<h2/)
  })
})
