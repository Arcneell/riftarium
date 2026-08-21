import { computed, toValue } from "vue"
import { DOMAIN_RUNE, RUNE_LABELS, copyFamily, glyphUrl } from "../cardText.js"
import { DECK_ZONES, groupDeck, zoneOf } from "../deckDisplay.js"

/* Plafond d'exemplaires par carte pour un deck légal (12 = limite du schéma pour un deck illégal). */
export const TOURNAMENT_CAPS = { Legend: 1, Battlefield: 1, Rune: 12, main: 3 }

/* Règles de construction d'un deck : zones, plafonds de copies, identité de domaines fixée
   par la légende. Logique métier pure — les retours visuels passent par les callbacks :

   - canEdit          : ref, getter ou booléen (true par défaut, pratique pour les tests)
   - onLimit(message, cardId) : ajout refusé (secousse de la tuile + message)
   - onNotice(message)        : information sans refus (légende remplacée)
   - onAdded(card)            : carte ajoutée avec succès (flash de la ligne) */
export function useDeckRules(
  deck,
  { canEdit = true, onLimit = () => {}, onNotice = () => {}, onAdded = () => {} } = {}
) {
  const editable = () => Boolean(toValue(canEdit))

  const ZONES = DECK_ZONES

  /* La légende est affichée en vitrine : les listes ne montrent que les autres zones. */
  const LIST_ZONES = ZONES.filter((zone) => zone.key !== "Legend")

  const grouped = computed(() => groupDeck(deck.value))

  const zoneCounts = computed(() => {
    const counts = {}
    for (const zone of ZONES) counts[zone.key] = grouped.value[zone.key].reduce((total, entry) => total + entry.qty, 0)
    return counts
  })

  /* Quantités par nom de jeu : reprints et variantes comptent comme la même carte. */
  const familyQty = computed(() => {
    const map = new Map()
    for (const entry of deck.value?.cards || []) {
      const family = copyFamily(entry.card)
      map.set(family, (map.get(family) || 0) + entry.qty)
    }
    return map
  })

  const inDeckQty = (card) => familyQty.value.get(copyFamily(card)) || 0

  /* ---------- Légende d'abord : elle fixe l'identité de domaines du deck ---------- */

  const legendEntry = computed(() => grouped.value.Legend[0] || null)
  const legendDomains = computed(
    () => new Set((legendEntry.value?.card.domains || []).filter((domain) => domain !== "Colorless"))
  )
  const legendRunes = computed(() =>
    [...legendDomains.value].map((domain) => ({
      domain,
      label: RUNE_LABELS[DOMAIN_RUNE[domain]] || domain,
      src: glyphUrl(`rune_${DOMAIN_RUNE[domain]}`)
    }))
  )

  /* Hors identité : ne concerne que le deck principal et les runes (champs de bataille libres). */
  function offDomain(card) {
    if (!legendEntry.value || card.type === "Legend" || card.type === "Battlefield") return false
    return (card.domains || []).some((domain) => domain !== "Colorless" && !legendDomains.value.has(domain))
  }

  function addCard(card) {
    if (!editable() || !deck.value) return false
    const zone = zoneOf(card)
    if (deck.value.format === "tournament") {
      const cap = TOURNAMENT_CAPS[zone]
      if (zone === "Legend") {
        const current = legendEntry.value
        if (current && current.card.id === card.id) {
          onLimit("Cette légende est déjà dans le deck.", card.id)
          return false
        }
        if (current) {
          deck.value.cards.splice(deck.value.cards.indexOf(current), 1)
          onNotice(`Légende remplacée par ${card.name}.`)
        }
      } else if (!legendEntry.value) {
        onLimit("Choisissez d'abord votre légende : elle fixe les domaines du deck.", card.id)
        return false
      }
      if (offDomain(card)) {
        onLimit(`${card.name} est hors des domaines de votre légende.`, card.id)
        return false
      }
      if (zone === "Battlefield" && zoneCounts.value.Battlefield >= 3 && inDeckQty(card) === 0) {
        onLimit("3 champs de bataille maximum.", card.id)
        return false
      }
      if (zone !== "Legend" && inDeckQty(card) >= cap) {
        onLimit(
          zone === "main" ? `Maximum 3 exemplaires de ${card.name}.` : `Maximum ${cap} exemplaire(s) de ${card.name}.`,
          card.id
        )
        return false
      }
    } else if (inDeckQty(card) >= 12) {
      onLimit("12 exemplaires maximum.", card.id)
      return false
    }
    const existing = deck.value.cards.find((entry) => entry.card.id === card.id)
    if (existing) existing.qty += 1
    else deck.value.cards.push({ card, qty: 1 })
    onAdded(card)
    return true
  }

  function setQty(entry, delta) {
    if (!editable()) return
    if (delta > 0) {
      addCard(entry.card)
      return
    }
    entry.qty += delta
    if (entry.qty <= 0) deck.value.cards.splice(deck.value.cards.indexOf(entry), 1)
  }

  function removeOne(cardId) {
    const entry = deck.value?.cards.find((item) => item.card.id === cardId)
    if (entry) setQty(entry, -1)
  }

  return {
    ZONES,
    LIST_ZONES,
    grouped,
    zoneCounts,
    familyQty,
    inDeckQty,
    legendEntry,
    legendDomains,
    legendRunes,
    offDomain,
    addCard,
    setQty,
    removeOne
  }
}
