import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import StackedBar from "./StackedBar.vue"

const segments = [
  { label: "Publiés", value: 12, color: "#2f7340" },
  { label: "En attente", value: 2, color: "#cf9200" },
  { label: "Rejetés", value: 0, color: "#ad2417" }
]

describe("StackedBar", () => {
  it("rend un segment par statut non nul et une légende comptée pour tous", () => {
    const wrapper = mount(StackedBar, { props: { title: "Statuts de modération", segments } })
    /* Le segment à zéro n'est pas dessiné, mais reste dans la légende. */
    expect(wrapper.findAll(".chart-segment")).toHaveLength(2)
    const keys = wrapper.findAll(".chart-legend .chart-key").map((key) => key.text())
    expect(keys).toEqual(["Publiés 12", "En attente 2", "Rejetés 0"])
  })

  it("montre un tooltip par segment avec valeur et part", async () => {
    const wrapper = mount(StackedBar, { props: { title: "Statuts de modération", segments } })
    await wrapper.findAll(".chart-segment")[0].trigger("mouseenter")
    const tooltip = wrapper.get(".chart-tooltip")
    expect(tooltip.text()).toContain("Publiés")
    expect(tooltip.text()).toContain("12")
    expect(tooltip.text()).toContain("86 %")
  })

  it("bascule sur le tableau des données", async () => {
    const wrapper = mount(StackedBar, { props: { title: "Statuts de modération", segments } })
    await wrapper.get(".chart-toggle").trigger("click")
    expect(wrapper.find("svg").exists()).toBe(false)
    expect(wrapper.findAll(".chart-table tbody tr")).toHaveLength(3)
    expect(wrapper.get(".chart-table").text()).toContain("Rejetés")
  })
})
