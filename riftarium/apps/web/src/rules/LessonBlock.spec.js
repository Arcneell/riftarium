import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import LessonBlock from "./LessonBlock.vue"
import Icon from "../components/Icon.vue"

const mountBlock = (block) => mount(LessonBlock, { props: { block }, global: { components: { Icon } } })

describe("LessonBlock", () => {
  it("chaque type de bloc rend son contenu", () => {
    const list = mountBlock({ type: "ul", items: ["Un", "Deux"] })
    expect(list.findAll("li").map((li) => li.text())).toEqual(["Un", "Deux"])

    const table = mountBlock({ type: "table", headers: ["A", "B"], rows: [["x", "y"]] })
    expect(table.findAll("th").map((th) => th.text())).toEqual(["A", "B"])
    expect(table.findAll("td").map((td) => td.text())).toEqual(["x", "y"])

    const note = mountBlock({ type: "note", kind: "warn", title: "Attention", text: "Danger" })
    expect(note.classes()).toContain("lecon-note--warn")
    expect(note.text()).toContain("Attention")
    expect(note.text()).toContain("Danger")

    const compare = mountBlock({
      type: "compare",
      left: { title: "Énergie", kicker: "Épuiser", text: "t1", recover: "Faible" },
      right: { title: "Essence", kicker: "Recycler", text: "t2", recover: "Élevé" }
    })
    expect(compare.text()).toContain("Énergie")
    expect(compare.text()).toContain("Essence")
    expect(compare.text()).toContain("Élevé")

    const types = mountBlock({
      type: "types",
      items: [
        { key: "a", card: { name: "A", img: "https://cdn.example/a.png" }, title: "Légende", text: "Texte a" },
        { key: "b", card: { name: "B", img: "https://cdn.example/b.png" }, title: "Unité", text: "Texte b" }
      ]
    })
    expect(types.findAll(".lecon-type")).toHaveLength(2)
  })

  it("types : la sélection est interne, le bouton Agrandir émet zoom", async () => {
    const card = { name: "B", img: "https://cdn.example/b.png" }
    const wrapper = mountBlock({
      type: "types",
      items: [
        { key: "a", card: { name: "A", img: "https://cdn.example/a.png" }, title: "Légende", text: "Texte a" },
        { key: "b", card, title: "Unité", text: "Texte b" }
      ]
    })
    await wrapper.findAll(".lecon-type")[1].trigger("click")
    const copies = wrapper.findAll(".lecon-type-copy")
    expect(copies[0].isVisible()).toBe(false)
    expect(copies[1].isVisible()).toBe(true)
    await copies[1].get(".lecon-enlarge").trigger("click")
    expect(wrapper.emitted("zoom")[0]).toEqual([card])
    expect(wrapper.findAll(".lecon-type")[1].attributes("aria-label")).not.toContain("Double-cliquer")
    await wrapper.findAll(".lecon-type")[1].trigger("dblclick")
    expect(wrapper.emitted("zoom")).toHaveLength(2)
  })
})
