<script setup>
/*
  Barre empilée horizontale unique (part-à-tout) : segments séparés par un écart
  de 2px couleur de surface, coins extérieurs arrondis, légende « pastille +
  libellé + compte » sous la barre. Survol : tooltip par segment.
  Le parent ne doit pas l'afficher si le total vaut 0.
*/
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
          <rect x="0" :y="BAR_TOP" :width="plotWidth" :height="BAR_HEIGHT" rx="2" />
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
/* Graphique rhabillé « Forge noxienne » : tout vient des tokens. Les classes
   graphe-* évitent les règles héritées de main.css (chart-*, table, th, h3). */
.graphe-figure {
  margin: 0;
}
.graphe-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  flex-wrap: wrap;
}
.graphe-head h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1rem;
  font-weight: 700;
  color: var(--ink);
}
.graphe-toggle {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  padding: 0 var(--space-2);
  background: none;
  border: none;
  cursor: pointer;
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--ink-muted);
  text-decoration: underline dotted;
  text-underline-offset: 3px;
}
.graphe-toggle:hover {
  color: var(--ink);
}
.graphe-toggle:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.graphe-plot {
  position: relative;
  margin-top: var(--space-3);
}
.graphe-plot svg {
  display: block;
  width: 100%;
  height: auto;
  overflow: visible;
}
.graphe-grid {
  stroke: var(--line);
  stroke-width: 1;
  shape-rendering: crispedges;
}
.graphe-line-dot {
  stroke: var(--bg-raised);
  stroke-width: 2;
}
/* Textes : toujours l'encre du site, jamais la couleur de série. */
.graphe-axis-text {
  fill: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 11.5px;
  letter-spacing: 0.04em;
}
.graphe-value-text {
  fill: var(--ink);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 700;
}
.graphe-row-label {
  fill: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.04em;
}
.graphe-legend {
  display: flex;
  flex-wrap: wrap;
  gap: 6px 18px;
  margin-top: var(--space-3);
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.graphe-key {
  display: inline-flex;
  align-items: center;
  gap: 7px;
}
.graphe-key i,
.graphe-dot {
  width: 10px;
  height: 10px;
  flex: none;
  clip-path: polygon(2px 0, 100% 0, 100% calc(100% - 2px), calc(100% - 2px) 100%, 0 100%, 0 2px);
}
.graphe-key b {
  font-weight: 700;
  color: var(--ink);
}
.graphe-tooltip {
  position: absolute;
  z-index: 3;
  pointer-events: none;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  gap: 1px;
  background: var(--bg-raised);
  border: 1px solid var(--line);
  padding: 6px 10px;
  box-shadow: var(--shadow-deep);
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.04em;
  line-height: 1.5;
  color: var(--ink);
  white-space: nowrap;
}
.graphe-tooltip-date {
  font-size: 12px;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.graphe-tooltip-row {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.graphe-tooltip-row b {
  font-weight: 700;
  color: var(--ink);
}
.graphe-tooltip-row .graphe-dot {
  display: inline-block;
  margin-right: 3px;
}
.graphe-table {
  margin-top: var(--space-3);
  max-height: 240px;
  overflow-y: auto;
  font-size: 0.85rem;
}
.graphe-table table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
}
.graphe-table th,
.graphe-table td {
  text-align: left;
  padding: 6px 8px;
  border-bottom: 1px solid var(--line);
  color: var(--ink);
}
.graphe-table th {
  position: sticky;
  top: 0;
  background: var(--bg-raised);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  color: var(--ink-muted);
}
.graphe-table .num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.graphe-segment {
  transition: opacity var(--t-fast);
}
</style>
