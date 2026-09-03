import { onBeforeUnmount, onMounted, ref } from "vue"

/* Réglages de la grille standard des pages cartes/collection : seuils 560/900/1400. */
const DEFAULTS = {
  tileMin: 190, // largeur de tuile initiale, avant la première mesure
  size: 30, // taille de page initiale, avant la première mesure
  maxSize: 100,
  tileFloor: 132,
  debounce: 180,
  gap: (viewport) => (viewport < 560 ? 12 : viewport < 900 ? 16 : 24),
  minCol: (viewport) => (viewport < 560 ? 148 : viewport < 900 ? 160 : viewport < 1400 ? 176 : 188),
  rows: (height) => (height >= 1100 ? 6 : height >= 820 ? 5 : 4),
  fallbackWidth: (viewport) => Math.max(280, viewport - 56)
}

/* Mesure d'une grille de cartes : largeur de tuile qui tient vraiment dans le conteneur
   (sinon minmax déborde et les cartes sont coupées) et taille de page en colonnes × rangées.
   Les options permettent d'ajuster les seuils (galerie compacte de l'éditeur de deck). */
export function useGridMeasure(gridRef, options = {}) {
  const config = { ...DEFAULTS, ...options }
  const tileMin = ref(config.tileMin)
  const size = ref(config.size)
  let timer = null
  let observer = null
  /* Nœud réellement observé : la grille peut être remplacée (v-if de la galerie,
     changement de route réutilisant le composant) et l'observer suivrait l'ancien. */
  let observed = null

  function measure() {
    const viewport = window.innerWidth || 1280
    const height = window.innerHeight || 800
    const width = gridRef.value?.clientWidth || config.fallbackWidth(viewport)
    const gap = config.gap(viewport)
    const minCol = config.minCol(viewport)
    const columns = Math.max(2, Math.floor((width + gap) / (minCol + gap)))
    tileMin.value = Math.max(config.tileFloor, Math.floor((width - gap * (columns - 1)) / columns) - 1)
    size.value = Math.min(config.maxSize, columns * config.rows(height))
  }

  function scheduleMeasure() {
    clearTimeout(timer)
    timer = setTimeout(measure, config.debounce)
  }

  /* À rappeler si la grille apparaît après le montage (galerie affichée quand on devient éditeur).
     Si le nœud a changé depuis la dernière fois, on se rebranche dessus. */
  function observe() {
    if (typeof ResizeObserver === "undefined") return
    const node = gridRef.value
    if (!node || node === observed) return
    observer?.disconnect()
    observer = new ResizeObserver(scheduleMeasure)
    observer.observe(node)
    observed = node
  }

  onMounted(() => {
    measure()
    window.addEventListener("resize", scheduleMeasure)
    observe()
  })

  onBeforeUnmount(() => {
    clearTimeout(timer)
    window.removeEventListener("resize", scheduleMeasure)
    observer?.disconnect()
    observed = null
  })

  return { tileMin, size, measure, scheduleMeasure, observe }
}
