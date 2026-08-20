import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import ColumnChart from "./ColumnChart.vue"
import { formatDayLong, lastDays } from "./chartUtils.js"

const days = lastDays(30, "2026-08-19")
/* Série synthétique : pic de 40 le dernier jour, quelques jours à zéro. */
const values = days.map((_, i) => (i === 29 ? 40 : i % 5))
const lineValues = days.map((_, i) => (i === 29 ? 22 : i % 3))

const baseProps = { title: "Fréquentation (30 jours)", days, values, valueLabel: "Visites" }

describe("ColumnChart", () => {
  it("rend une colonne et une bande de survol par jour, sans légende en série unique", () => {
    const wrapper = mount(ColumnChart, { props: baseProps })
    expect(wrapper.findAll(".chart-col")).toHaveLength(30)
    expect(wrapper.findAll(".chart-band")).toHaveLength(30)
    expect(wrapper.find("polyline").exists()).toBe(false)
    expect(wrapper.find(".chart-legend").exists()).toBe(false)
    expect(wrapper.get("figcaption h3").text()).toBe("Fréquentation (30 jours)")
  })

  it("trace des ticks Y arrondis et étiquette uniquement le maximum", () => {
    const wrapper = mount(ColumnChart, { props: baseProps })
    const axisTexts = wrapper.findAll(".chart-axis-text").map((node) => node.text())
    expect(axisTexts).toContain("0")
    expect(axisTexts).toContain("20")
    expect(axisTexts).toContain("40")
    const directLabels = wrapper.findAll(".chart-value-text")
    expect(directLabels).toHaveLength(1)
    expect(directLabels[0].text()).toBe("40")
  })

  it("superpose la seconde série en ligne 2px avec une légende à deux entrées", () => {
    const wrapper = mount(ColumnChart, {
      props: { ...baseProps, lineValues, lineLabel: "Visiteurs uniques" }
    })
    const line = wrapper.get("polyline")
    expect(line.attributes("stroke-width")).toBe("2")
    expect(line.attributes("points").split(" ")).toHaveLength(30)
    const keys = wrapper.findAll(".chart-legend .chart-key")
    expect(keys.map((key) => key.text())).toEqual(["Visites", "Visiteurs uniques"])
  })

  it("affiche un tooltip daté en français au survol de la bande du jour", async () => {
    const wrapper = mount(ColumnChart, {
      props: { ...baseProps, lineValues, lineLabel: "Visiteurs uniques" }
    })
    expect(wrapper.find(".chart-tooltip").exists()).toBe(false)
    await wrapper.findAll(".chart-band")[29].trigger("mouseenter")
    const tooltip = wrapper.get(".chart-tooltip")
    expect(tooltip.text()).toContain(formatDayLong("2026-08-19"))
    expect(tooltip.text()).toContain("Visites 40")
    expect(tooltip.text()).toContain("Visiteurs uniques 22")
    /* Point de survol de la ligne : marqueur ≥ 8px avec anneau de surface. */
    expect(wrapper.find(".chart-line-dot").exists()).toBe(true)
    await wrapper.get(".chart-plot").trigger("mouseleave")
    expect(wrapper.find(".chart-tooltip").exists()).toBe(false)
  })

  it("bascule sur le tableau des données et revient au graphique", async () => {
    const wrapper = mount(ColumnChart, {
      props: { ...baseProps, lineValues, lineLabel: "Visiteurs uniques" }
    })
    const toggle = wrapper.get(".chart-toggle")
    expect(toggle.attributes("aria-expanded")).toBe("false")
    await toggle.trigger("click")
    expect(toggle.attributes("aria-expanded")).toBe("true")
    expect(wrapper.find("svg").exists()).toBe(false)
    const rows = wrapper.findAll(".chart-table tbody tr")
    expect(rows).toHaveLength(30)
    expect(rows[29].text()).toContain("40")
    expect(rows[29].text()).toContain("22")
    await toggle.trigger("click")
    expect(wrapper.find("svg").exists()).toBe(true)
    expect(wrapper.find(".chart-table").exists()).toBe(false)
  })
})
