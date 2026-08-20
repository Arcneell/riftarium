import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import HBarChart from "./HBarChart.vue"

const rows = [
  { label: "Cartothèque", value: 120 },
  { label: "Accueil", value: 60 },
  { label: "Scan", value: 0 }
]
const baseProps = { title: "Rubriques les plus visitées (7 j)", rows, valueLabel: "Visites" }

describe("HBarChart", () => {
  it("rend une barre par rubrique avec libellé à gauche et valeur directe au bout", () => {
    const wrapper = mount(HBarChart, { props: baseProps })
    const bars = wrapper.findAll(".chart-bar")
    expect(bars).toHaveLength(3)
    expect(bars[0].attributes("d")).toBeTruthy()
    /* Valeur nulle : pas de tracé, mais la valeur directe reste affichée. */
    expect(bars[2].attributes("d")).toBe("")
    expect(wrapper.findAll(".chart-row-label").map((node) => node.text())).toEqual(["Cartothèque", "Accueil", "Scan"])
    expect(wrapper.findAll(".chart-value-text").map((node) => node.text())).toEqual(["120", "60", "0"])
  })

  it("montre un tooltip par barre au survol", async () => {
    const wrapper = mount(HBarChart, { props: baseProps })
    await wrapper.findAll(".chart-band")[1].trigger("mouseenter")
    const tooltip = wrapper.get(".chart-tooltip").text()
    expect(tooltip).toContain("Accueil — Visites")
    expect(tooltip).toContain("60")
  })

  it("bascule sur le tableau des données", async () => {
    const wrapper = mount(HBarChart, { props: baseProps })
    await wrapper.get(".chart-toggle").trigger("click")
    expect(wrapper.find("svg").exists()).toBe(false)
    const cells = wrapper.findAll(".chart-table tbody tr")
    expect(cells).toHaveLength(3)
    expect(cells[0].text()).toContain("Cartothèque")
    expect(cells[0].text()).toContain("120")
  })
})
