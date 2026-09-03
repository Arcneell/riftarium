<script setup>
/*
  Graphique en colonnes SVG (série quotidienne), avec en option une seconde série
  superposée en ligne 2px — même unité, même axe Y (jamais de double axe).
  Survol : la bande verticale entière de chaque jour ouvre un tooltip HTML.
  Alternative texte : bouton « Voir les données » qui bascule sur un tableau.
*/
import { computed, ref, useId } from "vue"
import { formatDayLong, formatDayShort, niceScale, useMeasuredWidth } from "./chartUtils.js"

const props = defineProps({
  title: { type: String, required: true },
  days: { type: Array, required: true }, // jours ISO "YYYY-MM-DD"
  values: { type: Array, required: true }, // colonnes
  valueLabel: { type: String, required: true },
  color: { type: String, default: "var(--chart-gold)" },
  lineValues: { type: Array, default: null }, // ligne superposée (même unité)
  lineLabel: { type: String, default: "" },
  lineColor: { type: String, default: "var(--chart-teal)" }
})

const HEIGHT = 200
const PAD = { top: 24, right: 12, bottom: 24, left: 36 }

const host = ref(null)
const width = useMeasuredWidth(host)
const tableId = useId()
const showTable = ref(false)
const hovered = ref(-1)

const hasLine = computed(() => Array.isArray(props.lineValues) && props.lineValues.length > 0)
const scale = computed(() => niceScale(Math.max(0, ...props.values, ...(hasLine.value ? props.lineValues : []))))

const plotWidth = computed(() => Math.max(240, width.value))
const x0 = PAD.left
const x1 = computed(() => plotWidth.value - PAD.right)
const y0 = PAD.top
const y1 = HEIGHT - PAD.bottom

const slot = computed(() => (x1.value - x0) / Math.max(1, props.days.length))
const barWidth = computed(() => Math.max(2, Math.min(24, slot.value - 2)))
const round = (n) => Math.round(n * 100) / 100
const xCenter = (i) => round(x0 + slot.value * (i + 0.5))
const yFor = (value) => round(y1 - (value / scale.value.top) * (y1 - y0))

/* Colonne : sommet arrondi 4px, base carrée posée sur la ligne de base. */
function columnPath(index) {
  const value = props.values[index]
  if (!value || value <= 0) return ""
  const w = barWidth.value
  const x = round(xCenter(index) - w / 2)
  const top = yFor(value)
  const r = Math.min(4, w / 2, y1 - top)
  return [
    `M${x},${y1}`,
    `L${x},${round(top + r)}`,
    `Q${x},${top} ${round(x + r)},${top}`,
    `L${round(x + w - r)},${top}`,
    `Q${round(x + w)},${top} ${round(x + w)},${round(top + r)}`,
    `L${round(x + w)},${y1}`,
    "Z"
  ].join(" ")
}

/* Tout ce dont le template a besoin par jour, calculé une fois : appeler
   `columnPath(i)`, `xCenter(i)` et `xLabelAnchor(i)` depuis le template les
   réexécutait à chaque rendu, pour chacun des 30 jours. */
const columns = computed(() =>
  props.days.map((day, i) => ({
    day,
    d: columnPath(i),
    x: xCenter(i),
    label: formatDayShort(day),
    anchor: xLabelAnchor(i)
  }))
)

const linePoints = computed(() =>
  hasLine.value ? props.days.map((_, i) => `${xCenter(i)},${yFor(props.lineValues[i] || 0)}`).join(" ") : ""
)

/* Étiquette directe parcimonieuse : seulement le maximum de la série principale. */
const maxIndex = computed(() => {
  const max = Math.max(...props.values)
  return max > 0 ? props.values.indexOf(max) : -1
})
const maxLabelAnchor = computed(() => {
  if (maxIndex.value < 0) return "middle"
  const x = xCenter(maxIndex.value)
  if (x < x0 + 20) return "start"
  if (x > x1.value - 20) return "end"
  return "middle"
})

/* Axe X : ~1 étiquette sur 5 (plus espacées si étroit), la dernière journée toujours étiquetée. */
const labelStep = computed(() => {
  const maxLabels = Math.max(2, Math.floor((x1.value - x0) / 74))
  return Math.max(1, Math.ceil(props.days.length / maxLabels))
})
const labeledIndexes = computed(() =>
  props.days.map((_, i) => i).filter((i) => (props.days.length - 1 - i) % labelStep.value === 0)
)
const xLabelAnchor = (i) => {
  const x = xCenter(i)
  if (x < x0 + 24) return "start"
  if (x > x1.value - 24) return "end"
  return "middle"
}

const tooltipStyle = computed(() => {
  if (hovered.value < 0) return {}
  const x = Math.min(Math.max(xCenter(hovered.value), 86), plotWidth.value - 86)
  return { left: `${x}px`, top: "2px" }
})
const tooltipRows = computed(() => {
  if (hovered.value < 0) return []
  const rows = [{ label: props.valueLabel, value: props.values[hovered.value], color: props.color }]
  if (hasLine.value)
    rows.push({ label: props.lineLabel, value: props.lineValues[hovered.value], color: props.lineColor })
  return rows
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
        :viewBox="`0 0 ${plotWidth} ${HEIGHT}`"
        :height="HEIGHT"
        role="img"
        :aria-label="`${title} — graphique en colonnes, bouton « Voir les données » pour le détail`"
      >
        <!-- Grille horizontale hairline + ticks Y arrondis -->
        <g v-for="tick in scale.ticks" :key="tick">
          <line class="chart-grid" :x1="x0" :x2="x1" :y1="yFor(tick)" :y2="yFor(tick)" />
          <text class="chart-axis-text" :x="x0 - 8" :y="yFor(tick) + 3.5" text-anchor="end">{{ tick }}</text>
        </g>

        <!-- Colonnes. `chart-col` et `chart-band` n'ont aucune règle CSS : ces deux
             classes servent de point d'accroche aux tests du composant. -->
        <path v-for="column in columns" :key="column.day" class="chart-col" :d="column.d" :fill="color" />

        <!-- Ligne superposée (même axe) -->
        <polyline
          v-if="hasLine"
          :points="linePoints"
          fill="none"
          :stroke="lineColor"
          stroke-width="2"
          stroke-linejoin="round"
          stroke-linecap="round"
        />
        <!-- Point de survol de la ligne : ≥ 8px, anneau 2px couleur de surface -->
        <circle
          v-if="hasLine && hovered >= 0"
          class="chart-line-dot"
          :cx="xCenter(hovered)"
          :cy="yFor(lineValues[hovered] || 0)"
          r="4.5"
          :fill="lineColor"
        />

        <!-- Étiquette directe du maximum de la série principale -->
        <text
          v-if="maxIndex >= 0 && hovered !== maxIndex"
          class="chart-value-text"
          :x="xCenter(maxIndex)"
          :y="yFor(values[maxIndex]) - 7"
          :text-anchor="maxLabelAnchor"
        >
          {{ values[maxIndex] }}
        </text>

        <!-- Étiquettes de dates espacées -->
        <text
          v-for="i in labeledIndexes"
          :key="`x-${columns[i].day}`"
          class="chart-axis-text"
          :x="columns[i].x"
          :y="HEIGHT - 7"
          :text-anchor="columns[i].anchor"
        >
          {{ columns[i].label }}
        </text>

        <!-- Cibles de survol : toute la bande verticale du jour -->
        <rect
          v-for="(day, i) in days"
          :key="`band-${day}`"
          class="chart-band"
          :x="x0 + slot * i"
          :y="0"
          :width="slot"
          :height="HEIGHT"
          fill="transparent"
          @mouseenter="hovered = i"
        />
      </svg>

      <!-- Infobulle de survol : aria-hidden, pas role="status". Elle change à chaque
           mouvement de souris et n'a pas d'équivalent clavier : annoncée, elle noyait
           le lecteur d'écran, qui dispose du tableau « Voir les données ». -->
      <div v-if="hovered >= 0" class="chart-tooltip" :style="tooltipStyle" aria-hidden="true">
        <span class="chart-tooltip-date">{{ formatDayLong(days[hovered]) }}</span>
        <span v-for="row in tooltipRows" :key="row.label" class="chart-tooltip-row">
          <i class="chart-dot" :style="{ background: row.color }"></i>{{ row.label }} <b>{{ row.value }}</b>
        </span>
      </div>
    </div>

    <div v-if="hasLine && !showTable" class="chart-legend">
      <span class="chart-key"><i :style="{ background: color }"></i>{{ valueLabel }}</span>
      <span class="chart-key"><i :style="{ background: lineColor }"></i>{{ lineLabel }}</span>
    </div>

    <div v-if="showTable" :id="tableId" class="chart-table">
      <table>
        <thead>
          <tr>
            <th scope="col">Date</th>
            <th scope="col" class="num">{{ valueLabel }}</th>
            <th v-if="hasLine" scope="col" class="num">{{ lineLabel }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(day, i) in days" :key="day">
            <td>{{ formatDayShort(day) }}</td>
            <td class="num">{{ values[i] }}</td>
            <td v-if="hasLine" class="num">{{ lineValues[i] }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </figure>
</template>
