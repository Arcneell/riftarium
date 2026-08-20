/* Utilitaires partagés des graphiques SVG maison (tableau de bord admin). */
import { onBeforeUnmount, onMounted, ref } from "vue"

/* Échelle Y « propre » : 3 ou 4 ticks arrondis à des valeurs rondes (0/5/10, 0/50/100…). */
export function niceScale(maxValue) {
  const max = Math.max(1, Math.ceil(maxValue))
  let best = null
  for (let power = 0; power <= 9; power++) {
    for (const mantissa of [1, 2, 5]) {
      const step = mantissa * 10 ** power
      for (const divisions of [2, 3]) {
        const top = step * divisions
        if (top >= max && (!best || top < best.top)) best = { step, divisions, top }
      }
    }
  }
  return { top: best.top, ticks: Array.from({ length: best.divisions + 1 }, (_, i) => i * best.step) }
}

/* « 12 août » (axe X) et « mardi 12 août » (tooltips / tableaux). T00:00:00 : minuit local, pas UTC. */
export const formatDayShort = (iso) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString("fr-FR", { day: "numeric", month: "short" })
export const formatDayLong = (iso) =>
  new Date(`${iso}T00:00:00`).toLocaleDateString("fr-FR", { weekday: "long", day: "numeric", month: "long" })

const toIsoDay = (date) =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`

/* Les `count` derniers jours (ISO), le dernier étant `end` (Date ou "YYYY-MM-DD", défaut aujourd'hui). */
export function lastDays(count, end = new Date()) {
  const last = end instanceof Date ? end : new Date(`${end}T00:00:00`)
  return Array.from({ length: count }, (_, i) => {
    const day = new Date(last)
    day.setDate(last.getDate() - (count - 1 - i))
    return toIsoDay(day)
  })
}

/* Projette des entrées éparses ({day, …}) sur un axe de jours complet, trous remplis par `empty`. */
export function zeroFillDays(entries, axisDays, empty = {}) {
  const byDay = new Map((entries || []).map((entry) => [entry.day, entry]))
  return axisDays.map((day) => byDay.get(day) || { day, ...empty })
}

/* Largeur mesurée d'un élément (SVG responsive : viewBox = largeur CSS, texte à taille réelle). */
export function useMeasuredWidth(elementRef, fallback = 640) {
  const width = ref(fallback)
  let observer = null
  onMounted(() => {
    if (!elementRef.value || typeof ResizeObserver === "undefined") return
    observer = new ResizeObserver((entries) => {
      const measured = entries[0]?.contentRect?.width
      if (measured) width.value = measured
    })
    observer.observe(elementRef.value)
  })
  onBeforeUnmount(() => observer?.disconnect())
  return width
}
