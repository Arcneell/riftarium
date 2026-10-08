import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import DeckMissingModal from "./DeckMissingModal.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

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

const modal = () => document.body.querySelector(".rift-modal")
const actionButtons = () => [...modal().querySelectorAll(".atelier-missing-actions button")]
const wishButton = () =>
  actionButtons().find((b) => b.textContent.includes("wishlist") || b.textContent.includes("ajoutée"))

describe("DeckMissingModal", () => {
  beforeEach(() => {
    session.token = null
    session.handle = null
    api.mockReset()
  })

  it("affiche le prix unitaire de chaque carte manquante et le coût pour compléter", async () => {
    const wrapper = await mountModal({
      missing: { items: [missingCard(1, 4.5), missingCard(2, null)], missing_total: 4, deck_total: 40 },
      missingEur: 9
    })
    expect(modal().querySelector(".rift-modal-head").textContent).toContain("Cartes manquantes")
    const items = [...modal().querySelectorAll(".atelier-missing-list .atelier-missing-item")]
    expect(items).toHaveLength(2)
    expect(items[0].querySelector(".atelier-missing-thumb")).not.toBeNull()
    expect(items[0].querySelector(".atelier-missing-name").textContent).toBe("Carte 1")
    expect(items[0].querySelector(".atelier-missing-qty").textContent).toBe("×2 manquante(s)")

    const cells = [...modal().querySelectorAll(".atelier-missing-price")]
    expect(cells).toHaveLength(2)
    expect(cells[0].textContent).toContain("4,50")
    expect(cells[1].textContent.trim()).toBe("—")

    const total = modal().querySelector(".atelier-missing-cost")
    expect(total.textContent).toContain("Coût pour compléter :")
    expect(total.textContent).toContain("9,00")
    expect(total.getAttribute("title")).toContain("TCGplayer")
    wrapper.unmount()
  })

  it("connecté : « ajouter les manquantes à ma wishlist » appelle from-deck et confirme", async () => {
    session.token = "jeton"
    api.mockResolvedValue({ added: 2 })
    const wrapper = await mountModal({
      missing: { items: [missingCard(1, 4.5), missingCard(2, null)], missing_total: 4, deck_total: 40 },
      missingEur: 9,
      deckId: 7
    })
    /* « Copier la liste » (secondaire) d'abord, puis l'ajout à la wishlist (principal). */
    const [copy, wish] = actionButtons()
    expect(copy.textContent).toContain("Copier la liste")
    expect(copy.classList).toContain("rift-btn--secondary")
    expect(wish.textContent).toContain("Ajouter les manquantes à ma wishlist")
    expect(wish.classList).toContain("rift-btn--primary")
    wish.click()
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/wishlist/from-deck/7", { method: "POST" })
    expect(wishButton().textContent).toContain("2 ajoutée(s)")
    wrapper.unmount()
  })

  it("sans deckId ou hors connexion : le bouton wishlist n'apparaît pas", async () => {
    const wrapper = await mountModal({
      missing: { items: [missingCard(1, 4.5)], missing_total: 2, deck_total: 40 },
      missingEur: 9,
      deckId: 7
    })
    expect(wishButton()).toBeUndefined()
    wrapper.unmount()
  })

  it("sans prix agrégé : pas de ligne « coût pour compléter »", async () => {
    const wrapper = await mountModal({
      missing: { items: [missingCard(1, null)], missing_total: 2, deck_total: 40 },
      missingEur: null
    })
    expect(modal().querySelector(".atelier-missing-cost")).toBeNull()
    expect(modal().textContent).toContain("Il vous manque")
    wrapper.unmount()
  })

  it("chargement : squelette ; erreur : alerte", async () => {
    const wrapper = await mountModal({ missing: null })
    expect(modal().querySelector(".rift-skeleton")).not.toBeNull()
    await wrapper.setProps({ error: "Analyse impossible" })
    const alert = modal().querySelector('[role="alert"]')
    expect(alert.textContent).toBe("Analyse impossible")
    expect(modal().querySelector(".rift-skeleton")).toBeNull()
    wrapper.unmount()
  })

  it("le survol de la vignette ou du nom émet preview", async () => {
    const wrapper = await mountModal({
      missing: { items: [missingCard(1, 4.5)], missing_total: 2, deck_total: 40 },
      missingEur: null
    })
    modal().querySelector(".atelier-missing-thumb").dispatchEvent(new MouseEvent("mouseenter"))
    modal().querySelector(".atelier-missing-copy").dispatchEvent(new MouseEvent("mouseenter"))
    modal().querySelector(".atelier-missing-copy").dispatchEvent(new MouseEvent("mouseleave"))
    const previews = wrapper.emitted("preview")
    expect(previews).toHaveLength(2)
    expect(previews[0][0].id).toBe("card-1")
    expect(previews[0][2]).toBe(400)
    expect(wrapper.emitted("hide-preview")).toHaveLength(1)
    wrapper.unmount()
  })
})
