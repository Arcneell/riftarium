import { mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { describe, expect, it } from "vitest"
import DeckMissingModal from "./DeckMissingModal.vue"

function missingCard(index, priceEur) {
  return {
    card: {
      id: `card-${index}`,
      riftbound_id: `ogn-00${index}-298`,
      name: `Carte ${index}`,
      image_url: `https://cdn.example/${index}.png`,
      price_eur: priceEur
    },
    needed: 3,
    owned: 1,
    missing: 2
  }
}

async function mountModal(props) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: "/cartes/:id", component: { template: "<div />" } }]
  })
  router.push("/cartes/card-1")
  await router.isReady()
  const wrapper = mount(DeckMissingModal, {
    props,
    global: { plugins: [router] },
    attachTo: document.body
  })
  return wrapper
}

const modal = () => document.body.querySelector(".modal")

describe("DeckMissingModal", () => {
  it("affiche le prix unitaire de chaque carte manquante et le coût pour compléter", async () => {
    const wrapper = await mountModal({
      missing: { items: [missingCard(1, 4.5), missingCard(2, null)], missing_total: 4, deck_total: 40 },
      missingEur: 9
    })
    const cells = [...modal().querySelectorAll("tbody .price-cell")]
    expect(cells).toHaveLength(2)
    expect(cells[0].textContent).toContain("4,50")
    expect(cells[1].textContent.trim()).toBe("—")

    const total = modal().querySelector(".price-missing")
    expect(total.textContent).toContain("Coût pour compléter :")
    expect(total.textContent).toContain("9,00")
    expect(total.getAttribute("title")).toContain("TCGplayer")
    wrapper.unmount()
  })

  it("sans prix agrégé : pas de ligne « coût pour compléter »", async () => {
    const wrapper = await mountModal({
      missing: { items: [missingCard(1, null)], missing_total: 2, deck_total: 40 },
      missingEur: null
    })
    expect(modal().querySelector(".price-missing")).toBeNull()
    expect(modal().textContent).toContain("Il vous manque")
    wrapper.unmount()
  })
})
