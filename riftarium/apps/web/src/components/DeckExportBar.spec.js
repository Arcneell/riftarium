import { flushPromises, mount } from "@vue/test-utils"
import { beforeEach, describe, expect, it, vi } from "vitest"
import DeckExportBar from "./DeckExportBar.vue"

const deck = {
  cards: [
    {
      qty: 1,
      card: { id: "l1", riftbound_id: "ogn-247-298", name: "Daughter of the Void", type: "Legend", tags: ["Ahri"] }
    }
  ]
}

describe("DeckExportBar", () => {
  beforeEach(() => {
    Object.assign(navigator, { clipboard: { writeText: vi.fn().mockResolvedValue() } })
  })

  it("copie une liste Rift Atlas", async () => {
    const wrapper = mount(DeckExportBar, { props: { deck } })
    await wrapper.get(".btn-gold").trigger("click")
    await flushPromises()
    expect(navigator.clipboard.writeText).toHaveBeenCalledWith(expect.stringContaining("~~Legend~~"))
    expect(wrapper.text()).toContain("Copié")
  })
})
