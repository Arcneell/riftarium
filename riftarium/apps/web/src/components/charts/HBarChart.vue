<script setup>
/*
  Barres horizontales SVG, série unique : libellé à gauche en texte normal,
  valeur directe au bout de chaque barre (encre du site, jamais la couleur de série).
  Survol : tooltip par barre. Alternative texte : tableau des valeurs.
*/
import { computed, ref, useId } from "vue"
import { useMeasuredWidth } from "./chartUtils.js"

const props = defineProps({
  title: { type: String, required: true },
  rows: { type: Array, required: true }, // [{ label, value }]
  valueLabel: { type: String, required: true },
  color: { type: String, default: "var(--bronze)" }
})

const ROW_HEIGHT = 30
const BAR_HEIGHT = 16
const PAD_RIGHT = 46

const host = ref(null)
const width = useMeasuredWidth(host)
const tableId = useId()
const showTable = ref(false)
const hovered = ref(-1)

const plotWidth = computed(() => Math.max(240, width.value))
const height = computed(() => props.rows.length * ROW_HEIGHT + 8)
const gutter = computed(() => Math.min(118, Math.max(88, Math.round(plotWidth.value * 0.3))))
const maxValue = computed(() => Math.max(1, ...props.rows.map((row) => num(row.value))))
const round = (n) => Math.round(n * 100) / 100
/* Valeur absente ou non numérique (charge utile partielle) : 0, jamais NaN dans le SVG. */
const num = (value) => (Number.isFinite(value) ? value : 0)

const barLength = (row) => round((num(row.value) / maxValue.value) * (plotWidth.value - gutter.value - PAD_RIGHT))

/* Libellés tronqués à la gouttière réelle : ancrés à droite, les noms longs
   sortaient du viewBox par la gauche sur un écran de 360 px (illisibles et
   rognés). Largeur moyenne d'un caractère du corps de texte à 12,5 px. */
const CHAR_PX = 6.4
/* Longueur et bout de barre inclus dans le computed : le template les demandait
   par appels de fonction (`barPath(i)`, `barLength(row)`), donc recalculés à
   chaque rendu pour chaque ligne. */
const shownRows = computed(() => {
  const max = Math.floor((gutter.value - 12) / CHAR_PX)
  return props.rows.map((row, i) => {
    const clipped = row.label.length > max
    const length = barLength(row)
    return {
      ...row,
      short: clipped ? `${row.label.slice(0, Math.max(1, max - 1))}…` : row.label,
      clipped,
      length,
      end: round(gutter.value + length),
      d: barPath(i),
      top: rowTop(i)
    }
  })
})
const rowTop = (index) => 4 + ROW_HEIGHT * index
const barTop = (index) => rowTop(index) + (ROW_HEIGHT - BAR_HEIGHT) / 2

/* Barre : bout aux angles coupés de 2px côté valeur, base carrée sur l'axe des libellés. */
function barPath(index) {
  const length = barLength(props.rows[index])
  if (length <= 0) return ""
  const x = gutter.value
  const y = barTop(index)
  const r = Math.min(2, length / 2)
  const end = round(x + length)
  return [
    `M${x},${y}`,
    `L${round(end - r)},${y}`,
    `L${end},${round(y + r)}`,
    `L${end},${round(y + BAR_HEIGHT - r)}`,
    `L${round(end - r)},${y + BAR_HEIGHT}`,
    `L${x},${y + BAR_HEIGHT}`,
    "Z"
  ].join(" ")
}

const tooltipStyle = computed(() => {
  if (hovered.value < 0) return {}
  const x = Math.min(Math.max(gutter.value + barLength(props.rows[hovered.value]), 86), plotWidth.value - 86)
  return { left: `${x}px`, top: `${Math.max(0, rowTop(hovered.value) - 34)}px` }
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
        :viewBox="`0 0 ${plotWidth} ${height}`"
        :height="height"
        role="img"
        :aria-label="`${title} — barres horizontales, bouton « Voir les données » pour le détail`"
      >
        <g v-for="(row, i) in shownRows" :key="row.label">
          <!-- Le nom entier reste accessible : <title> au survol, infobulle, tableau des données. -->
          <title v-if="row.clipped">{{ row.label }}</title>
          <text class="graphe-row-label" :x="gutter - 10" :y="row.top + ROW_HEIGHT / 2 + 4" text-anchor="end">
            {{ row.short }}
          </text>
          <!-- Barre et bande de survol (aussi points d'accroche des tests). -->
          <path class="graphe-bar" :d="row.d" :fill="color" />
          <text class="graphe-value-text" :x="row.end + 7" :y="row.top + ROW_HEIGHT / 2 + 4" text-anchor="start">
            {{ row.value }}
          </text>
          <rect
            class="graphe-band"
            :x="0"
            :y="row.top"
            :width="plotWidth"
            :height="ROW_HEIGHT"
            fill="transparent"
            @mouseenter="hovered = i"
          />
        </g>
      </svg>

      <!-- aria-hidden : infobulle de survol sans équivalent clavier, doublon du
           tableau « Voir les données » (voir ColumnChart). -->
      <div v-if="hovered >= 0" class="graphe-tooltip" :style="tooltipStyle" aria-hidden="true">
        <span class="graphe-tooltip-row">
          <i class="graphe-dot" :style="{ background: color }"></i>{{ rows[hovered].label }} — {{ valueLabel }}
          <b>{{ rows[hovered].value }}</b>
        </span>
      </div>
    </div>

    <div v-if="showTable" :id="tableId" class="graphe-table">
      <table>
        <thead>
          <tr>
            <th scope="col">Rubrique</th>
            <th scope="col" class="num">{{ valueLabel }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in rows" :key="row.label">
            <td>{{ row.label }}</td>
            <td class="num">{{ row.value }}</td>
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
.graphe-bar,
\n.graphe-band {
  transition: opacity var(--t-fast);
}
.graphe-band {
  cursor: crosshair;
}
</style>
