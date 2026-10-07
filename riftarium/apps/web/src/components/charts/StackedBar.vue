<script setup>
/*
  Barre empilée horizontale unique (part-à-tout) : segments séparés par un écart
  de 2px couleur de surface, angles extérieurs coupés de 2px, légende « pastille +
  libellé + compte » sous la barre. Survol : tooltip par segment.
  Le parent ne doit pas l'afficher si le total vaut 0.
*/
import "./graphe.css"
import { computed, ref, useId } from "vue"
import { useMeasuredWidth } from "./chartUtils.js"

const props = defineProps({
  title: { type: String, required: true },
  segments: { type: Array, required: true } // [{ label, value, color }]
})

const BAR_HEIGHT = 22
const BAR_TOP = 6
const HEIGHT = BAR_HEIGHT + BAR_TOP * 2
const GAP = 2

const host = ref(null)
const width = useMeasuredWidth(host)
const tableId = useId()
const clipId = useId()
const showTable = ref(false)
const hovered = ref(-1)

const plotWidth = computed(() => Math.max(240, width.value))
const total = computed(() => props.segments.reduce((sum, segment) => sum + num(segment.value), 0))
const round = (n) => Math.round(n * 100) / 100
/* Valeur absente ou non numérique (charge utile partielle) : 0, jamais NaN dans le SVG. */
const num = (value) => (Number.isFinite(value) ? value : 0)

/* Rectangles des segments non vides, écart de 2px entre voisins. */
const rects = computed(() => {
  const visible = props.segments.filter((segment) => num(segment.value) > 0)
  if (!visible.length || total.value <= 0) return []
  const available = plotWidth.value - GAP * (visible.length - 1)
  let x = 0
  return visible.map((segment) => {
    const w = round((segment.value / total.value) * available)
    const rect = { ...segment, x: round(x), width: w, share: Math.round((segment.value / total.value) * 100) }
    x += w + GAP
    return rect
  })
})

/* Barre aux quatre angles coupés de 2px, comme les colonnes. */
const clipPoints = computed(() => {
  const w = plotWidth.value
  const t = BAR_TOP
  const b = BAR_TOP + BAR_HEIGHT
  return `2,${t} ${w - 2},${t} ${w},${t + 2} ${w},${b - 2} ${w - 2},${b} 2,${b} 0,${b - 2} 0,${t + 2}`
})

const tooltipStyle = computed(() => {
  if (hovered.value < 0 || !rects.value[hovered.value]) return {}
  const rect = rects.value[hovered.value]
  const x = Math.min(Math.max(rect.x + rect.width / 2, 86), plotWidth.value - 86)
  return { left: `${x}px`, top: `${BAR_TOP + BAR_HEIGHT + 6}px` }
})
</script>

<template>
  <figure ref="host" class="graphe-figure">
    <figcaption class="graphe-head">
      <h3>{{ title }}</h3>
      <button
        type="button"
        class="graphe-toggle"
        :aria-expanded="showTable"
        :aria-controls="tableId"
        @click="showTable = !showTable"
      >
        {{ showTable ? "Voir le graphique" : "Voir les données" }}
      </button>
    </figcaption>

    <div v-if="!showTable" class="graphe-plot" @mouseleave="hovered = -1">
      <svg
        :viewBox="`0 0 ${plotWidth} ${HEIGHT}`"
        :height="HEIGHT"
        role="img"
        :aria-label="`${title} — barre empilée, bouton « Voir les données » pour le détail`"
      >
        <clipPath :id="clipId">
          <polygon :points="clipPoints" />
        </clipPath>
        <g :clip-path="`url(#${clipId})`">
          <!-- Segments (aussi point d'accroche des tests). -->
          <rect
            v-for="(rect, i) in rects"
            :key="rect.label"
            class="graphe-segment"
            :x="rect.x"
            :y="BAR_TOP"
            :width="rect.width"
            :height="BAR_HEIGHT"
            :fill="rect.color"
            @mouseenter="hovered = i"
          />
        </g>
      </svg>

      <!-- aria-hidden : infobulle de survol sans équivalent clavier, doublon du
           tableau « Voir les données » (voir ColumnChart). -->
      <div v-if="hovered >= 0 && rects[hovered]" class="graphe-tooltip" :style="tooltipStyle" aria-hidden="true">
        <span class="graphe-tooltip-row">
          <i class="graphe-dot" :style="{ background: rects[hovered].color }"></i>{{ rects[hovered].label }}
          <b>{{ rects[hovered].value }}</b> ({{ rects[hovered].share }} %)
        </span>
      </div>
    </div>

    <div v-if="!showTable" class="graphe-legend">
      <span v-for="segment in segments" :key="segment.label" class="graphe-key">
        <i :style="{ background: segment.color }"></i>{{ segment.label }} <b>{{ segment.value }}</b>
      </span>
    </div>

    <div v-if="showTable" :id="tableId" class="graphe-table">
      <table>
        <thead>
          <tr>
            <th scope="col">Statut</th>
            <th scope="col" class="num">Decks</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="segment in segments" :key="segment.label">
            <td>{{ segment.label }}</td>
            <td class="num">{{ segment.value }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </figure>
</template>

<style scoped>
/* Propre à ce graphique ; le reste est dans graphe.css. */
.graphe-segment {
  transition: opacity var(--t-fast);
}
</style>
