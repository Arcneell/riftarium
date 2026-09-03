import { computed, toValue } from "vue"
import { zoneOf } from "../deckDisplay.js"

/* Statistiques d'un deck, partagées entre l'éditeur et la consultation publique.
   `cards` : liste d'entrées { card, qty } (ref, getter ou tableau brut). */
export function useDeckStats(cards) {
  /* Seul le deck principal compte pour la courbe et le coût total. */
  const mainEntries = computed(() => toValue(cards).filter((entry) => zoneOf(entry.card) === "main"))

  /* Courbe d'énergie : 8 paniers, les coûts ≥ 7 regroupés dans « 7+ ». */
  const curve = computed(() => {
    const buckets = Array(8).fill(0)
    /* Borné des deux côtés : une énergie négative ou aberrante dans les données
       source sortirait du tableau (buckets[-1] devient une propriété fantôme). */
    for (const entry of mainEntries.value) {
      buckets[Math.min(Math.max(entry.card.energy ?? 0, 0), 7)] += entry.qty
    }
    const max = Math.max(...buckets, 1)
    return buckets.map((count, cost) => ({ cost, count, height: (count / max) * 100 }))
  })

  /* Libellé compact « 1 : 4 · 2 : 6 » de la courbe : au doigt les infobulles des
     barres ne s'ouvrent jamais, la répartition doit se lire sous le graphique.
     Les paniers vides sont écartés, ils n'apprennent rien. */
  const curveLabel = computed(() =>
    curve.value
      .filter((bucket) => bucket.count)
      .map((bucket) => `${bucket.cost}${bucket.cost === 7 ? "+" : ""} : ${bucket.count}`)
      .join(" · ")
  )

  const energyTotal = computed(() =>
    mainEntries.value.reduce((sum, entry) => sum + (entry.card.energy ?? 0) * entry.qty, 0)
  )

  /* Répartition des domaines (Colorless exclu), du plus présent au moins présent. */
  const domainSpread = computed(() => {
    const counts = {}
    for (const entry of toValue(cards)) {
      for (const domain of entry.card.domains || []) {
        if (domain === "Colorless") continue
        counts[domain] = (counts[domain] || 0) + entry.qty
      }
    }
    return Object.entries(counts).sort((a, b) => b[1] - a[1])
  })

  return { curve, curveLabel, energyTotal, domainSpread }
}
