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
  color: { type: String, default: "var(--chart-gold)" }
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
const maxValue = computed(() => Math.max(1, ...props.rows.map((row) => row.value)))
const round = (n) => Math.round(n * 100) / 100

const barLength = (row) => round((row.value / maxValue.value) * (plotWidth.value - gutter.value - PAD_RIGHT))

/* Libellés tronqués à la gouttière réelle : ancrés à droite, les noms longs
   sortaient du viewBox par la gauche sur un écran de 360 px (illisibles et
   rognés). Largeur moyenne d'un caractère du corps de texte à 12,5 px. */
const CHAR_PX = 6.4
const shownRows = computed(() => {
  const max = Math.floor((gutter.value - 12) / CHAR_PX)
  return props.rows.map((row) => {
    const clipped = row.label.length > max
    return { ...row, short: clipped ? `${row.label.slice(0, Math.max(1, max - 1))}…` : row.label, clipped }
  })
})
const rowTop = (index) => 4 + ROW_HEIGHT * index
const barTop = (index) => rowTop(index) + (ROW_HEIGHT - BAR_HEIGHT) / 2

/* Barre : bout arrondi 4px côté valeur, base carrée sur l'axe des libellés. */
function barPath(index) {
  const length = barLength(props.rows[index])
  if (length <= 0) return ""
  const x = gutter.value
  const y = barTop(index)
  const r = Math.min(4, length / 2)
  const end = round(x + length)
  return [
    `M${x},${y}`,
    `L${round(end - r)},${y}`,
    `Q${end},${y} ${end},${round(y + r)}`,
    `L${end},${round(y + BAR_HEIGHT - r)}`,
    `Q${end},${y + BAR_HEIGHT} ${round(end - r)},${y + BAR_HEIGHT}`,
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
  <figure ref="host" class="chart-figure">
    <figcaption class="chart-head">
      <h3>{{ title }}</h3>
      <button
        type="button"
        class="chart-toggle"
        :aria-expanded="showTable"
        :aria-controls="tableId"
        @click="showTable = !showTable"
      >
        {{ showTable ? "Voir le graphique" : "Voir les données" }}
      </button>
    </figcaption>

    <div v-if="!showTable" class="chart-plot" @mouseleave="hovered = -1">
      <svg
        :viewBox="`0 0 ${plotWidth} ${height}`"
        :height="height"
        role="img"
        :aria-label="`${title} — barres horizontales, bouton « Voir les données » pour le détail`"
      >
        <g v-for="(row, i) in shownRows" :key="row.label">
          <!-- Le nom entier reste accessible : <title> au survol, infobulle, tableau des données. -->
          <title v-if="row.clipped">{{ row.label }}</title>
          <text class="chart-row-label" :x="gutter - 10" :y="rowTop(i) + ROW_HEIGHT / 2 + 4" text-anchor="end">
            {{ row.short }}
          </text>
          <path class="chart-bar" :d="barPath(i)" :fill="color" />
          <text
            class="chart-value-text"
            :x="gutter + barLength(row) + 7"
            :y="rowTop(i) + ROW_HEIGHT / 2 + 4"
            text-anchor="start"
          >
            {{ row.value }}
          </text>
          <rect
            class="chart-band"
            :x="0"
            :y="rowTop(i)"
            :width="plotWidth"
            :height="ROW_HEIGHT"
            fill="transparent"
            @mouseenter="hovered = i"
          />
        </g>
      </svg>

      <div v-if="hovered >= 0" class="chart-tooltip" :style="tooltipStyle" role="status">
        <span class="chart-tooltip-row">
          <i class="chart-dot" :style="{ background: color }"></i>{{ rows[hovered].label }} — {{ valueLabel }}
          <b>{{ rows[hovered].value }}</b>
        </span>
      </div>
    </div>

    <div v-if="showTable" :id="tableId" class="chart-table">
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
