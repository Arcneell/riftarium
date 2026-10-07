<script setup>
import { computed, onMounted, ref } from "vue"
import { cardThumb } from "../api.js"
import ColumnChart from "../components/charts/ColumnChart.vue"
import { lastDays, zeroFillDays } from "../components/charts/chartUtils.js"
import { formatLabel } from "../deckDisplay.js"
import { formatWinRate, getStats, modeLabel, winRatePercent } from "../play.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import RiftStat from "../ui/RiftStat.vue"

/* Libellé quand la légende a été supprimée du catalogue (nom absent). */
const LEGEND_FALLBACK = "Légende supprimée"

const stats = ref(null)
const loading = ref(true)
const error = ref("")

const totals = computed(() => stats.value?.totals || { played: 0, won: 0, lost: 0 })
const empty = computed(() => !loading.value && !error.value && !totals.value.played)

/* Axe de 30 jours zéro-rempli, calé sur le dernier jour renvoyé (l'API peut
   omettre les journées sans partie). */
const chartDays = computed(() => {
  const days = (stats.value?.recent || []).map((row) => row.day).filter(Boolean)
  days.sort()
  return lastDays(30, days.length ? days[days.length - 1] : new Date())
})
const series = computed(() => zeroFillDays(stats.value?.recent, chartDays.value, { played: 0, won: 0 }))
const playedValues = computed(() => series.value.map((row) => row.played || 0))
const wonValues = computed(() => series.value.map((row) => row.won || 0))

const byDeck = computed(() => stats.value?.by_deck || [])
const byFormat = computed(() => stats.value?.by_format || [])

/* Les deux listes de légendes partagent le même rendu ; une liste vide n'est pas affichée. */
const legendLists = computed(() =>
  [
    { key: "mine", title: "Par légende", altPrefix: "Légende", rows: stats.value?.by_legend || [] },
    {
      key: "opponent",
      title: "Par légende adverse",
      altPrefix: "Légende adverse",
      rows: stats.value?.by_opponent_legend || []
    }
  ].filter((list) => list.rows.length)
)

/* Le contrat ne chiffre le taux que par deck : ailleurs il se déduit de J / G. */
const rateOf = (row) => (row.played ? row.won / row.played : null)

/* Contrat (docs/suivi-des-matchs.md) : `current_streak` compte les victoires
   consécutives finissant au dernier match compté — jamais négatif. */
const currentStreak = computed(() => Math.max(0, Number(totals.value.current_streak || 0)))

async function load() {
  loading.value = true
  error.value = ""
  try {
    stats.value = await getStats()
  } catch (e) {
    error.value = e.message
    stats.value = null
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="wrap cards-wrap stats">
    <h1 class="stats-title">Mes statistiques</h1>

    <p v-if="error" class="stats-error" role="alert">{{ error }}</p>

    <div v-else-if="loading" class="stats-squelette" role="status">
      <span class="stats-sr">Chargement des statistiques…</span>
      <RiftSkeleton block />
      <RiftSkeleton :lines="4" />
    </div>

    <template v-else-if="!empty">
      <div class="stats-kpis">
        <div class="stats-kpi"><RiftStat label="Parties jouées" :value="totals.played" /></div>
        <div class="stats-kpi"><RiftStat label="Victoires" :value="totals.won" /></div>
        <div class="stats-kpi"><RiftStat label="Défaites" :value="totals.lost" /></div>
        <div class="stats-kpi">
          <RiftStat label="Taux de victoire" :value="formatWinRate(totals.win_rate ?? rateOf(totals))" />
        </div>
        <div class="stats-kpi">
          <RiftStat label="Série en cours" :value="currentStreak || '—'" />
          <span class="stats-kpi-note">victoires d'affilée</span>
        </div>
        <div class="stats-kpi">
          <RiftStat label="Meilleure série" :value="totals.best_streak || 0" />
          <span class="stats-kpi-note">victoires d'affilée</span>
        </div>
      </div>

      <p class="stats-note">
        Seules les parties confirmées par les deux joueurs (et les abandons) comptent ici : un résultat contesté reste
        dans l'<RouterLink class="stats-link" to="/historique">historique</RouterLink> mais pas dans les statistiques.
      </p>

      <RiftPanel class="stats-chart" tag="div">
        <ColumnChart
          title="Parties des 30 derniers jours"
          :days="chartDays"
          :values="playedValues"
          value-label="Parties"
          color="var(--bronze)"
          :line-values="wonValues"
          line-label="Victoires"
          line-color="var(--blood)"
        />
      </RiftPanel>

      <RiftPanel v-if="byDeck.length" class="stats-panel" title="Par deck">
        <div class="stats-scroll">
          <table class="stats-table">
            <thead>
              <tr>
                <th scope="col">Deck</th>
                <th scope="col">Format</th>
                <th scope="col" class="stats-num">J</th>
                <th scope="col" class="stats-num">G</th>
                <th scope="col" class="stats-num">P</th>
                <th scope="col">Taux de victoire</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in byDeck" :key="row.deck_id ?? `x${index}`">
                <td>
                  <RouterLink v-if="row.deck_id" class="stats-link" :to="`/decks/${row.deck_id}`">
                    {{ row.name }}
                  </RouterLink>
                  <span v-else>{{ row.name }}</span>
                </td>
                <td>{{ formatLabel(row.format) }}</td>
                <td class="stats-num">{{ row.played }}</td>
                <td class="stats-num">{{ row.won }}</td>
                <td class="stats-num">{{ row.lost }}</td>
                <td>
                  <div class="stats-taux">
                    <span class="stats-jauge" aria-hidden="true">
                      <span
                        class="stats-jauge-fill"
                        :style="{ width: `${winRatePercent(row.win_rate ?? rateOf(row))}%` }"
                      ></span>
                    </span>
                    <span class="stats-taux-valeur">{{ formatWinRate(row.win_rate ?? rateOf(row)) }}</span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </RiftPanel>

      <div v-if="legendLists.length" class="stats-grid">
        <RiftPanel v-for="list in legendLists" :key="list.key" class="stats-panel" :title="list.title">
          <ul class="stats-legends">
            <li v-for="(row, index) in list.rows" :key="row.card_id ?? `x${index}`" class="stats-legend">
              <img
                v-if="row.image_url"
                class="stats-thumb"
                :src="cardThumb(row.image_url, 72)"
                :alt="`${list.altPrefix} : ${row.name || LEGEND_FALLBACK}`"
                width="36"
                height="36"
                loading="lazy"
                decoding="async"
              />
              <span v-else class="stats-thumb" aria-hidden="true"></span>
              <span class="stats-legend-nom" :class="{ 'stats-faint': !row.name }">
                {{ row.name || LEGEND_FALLBACK }}
              </span>
              <span class="stats-legend-bilan">{{ row.won }} V / {{ row.lost }} D</span>
              <span class="stats-taux stats-legend-taux">
                <span class="stats-jauge" aria-hidden="true">
                  <span class="stats-jauge-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
                </span>
                <span class="stats-taux-valeur">{{ formatWinRate(rateOf(row)) }}</span>
              </span>
            </li>
          </ul>
        </RiftPanel>
      </div>

      <RiftPanel v-if="byFormat.length" class="stats-panel" title="Par format">
        <div class="stats-scroll">
          <table class="stats-table">
            <thead>
              <tr>
                <th scope="col">Format</th>
                <th scope="col" class="stats-num">J</th>
                <th scope="col" class="stats-num">G</th>
                <th scope="col" class="stats-num">P</th>
                <th scope="col">Taux de victoire</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in byFormat" :key="row.mode">
                <td>{{ modeLabel(row.mode) }}</td>
                <td class="stats-num">{{ row.played }}</td>
                <td class="stats-num">{{ row.won }}</td>
                <td class="stats-num">{{ row.lost }}</td>
                <td>
                  <div class="stats-taux">
                    <span class="stats-jauge" aria-hidden="true">
                      <span class="stats-jauge-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
                    </span>
                    <span class="stats-taux-valeur">{{ formatWinRate(rateOf(row)) }}</span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </RiftPanel>
    </template>

    <RiftEmpty
      v-else
      class="stats-empty"
      title="Aucune partie suivie"
      text="Les parties suivies se créent depuis l'application mobile (« Jouer », puis « Partie suivie »). Un code reçu se saisit dans le salon."
    >
      <RiftButton variant="primary" to="/salon">Rejoindre un salon</RiftButton>
    </RiftEmpty>
  </div>
</template>

<style scoped>
.stats {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
.stats p {
  margin: 0;
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.stats-title {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.stats-error {
  color: var(--blood-text);
}
.stats-note,
.stats-faint {
  color: var(--ink-muted);
}
.stats-link {
  color: var(--bronze-light);
}
.stats-link:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.stats-squelette {
  display: grid;
  gap: var(--space-3);
}
.stats-squelette :deep(.rift-skeleton-block) {
  height: 96px;
}
.stats-sr {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip-path: inset(50%);
  white-space: nowrap;
}

/* ---------- Chiffres clés ---------- */
.stats-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: var(--space-3);
}
.stats-kpi {
  display: grid;
  align-content: start;
  gap: var(--space-1);
}
.stats-kpi-note {
  font-size: 13px;
  color: var(--ink-muted);
}

/* ---------- Blocs ---------- */
.stats-empty {
  margin-top: var(--space-4);
}
.stats-panel {
  min-width: 0;
}
.stats-chart {
  width: 100%;
}
.stats-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-items: start;
  gap: var(--space-4);
}

/* ---------- Tableaux (neutralise les règles table / th / td de main.css) ---------- */
.stats-scroll {
  overflow-x: auto;
}
.stats-table {
  width: 100%;
  min-width: 520px;
  border-collapse: collapse;
  font-size: 15px;
}
.stats-table th,
.stats-table td {
  padding: var(--space-2) var(--space-3);
  border-bottom: 1px solid var(--line);
  text-align: left;
  vertical-align: middle;
  color: var(--ink);
}
.stats-table th {
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.stats-table .stats-num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}

/* ---------- Jauge de taux de victoire ---------- */
.stats-taux {
  display: flex;
  align-items: center;
  gap: var(--space-2);
}
.stats-jauge {
  flex: 1 1 auto;
  min-width: 56px;
  height: 8px;
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
}
.stats-jauge-fill {
  display: block;
  height: 100%;
  background: var(--bronze-light);
}
.stats-taux-valeur {
  flex: none;
  min-width: 3.5em;
  text-align: right;
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}

/* ---------- Par légende ---------- */
.stats-legends {
  display: grid;
  gap: var(--space-3);
  margin: 0;
  padding: 0;
  list-style: none;
}
.stats-legend {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr) minmax(120px, 40%);
  grid-template-areas:
    "thumb nom taux"
    "thumb bilan taux";
  align-items: center;
  column-gap: var(--space-3);
}
.stats-thumb {
  grid-area: thumb;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  object-fit: cover;
  background: var(--bg-sunken);
}
.stats-legend-nom {
  grid-area: nom;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--ink);
}
.stats-legend-bilan {
  grid-area: bilan;
  font-size: 13px;
  color: var(--ink-muted);
}
.stats-legend-taux {
  grid-area: taux;
}

@media (max-width: 1023px) {
  .stats-grid {
    grid-template-columns: minmax(0, 1fr);
  }
}
@media (max-width: 559px) {
  .stats-legend {
    grid-template-columns: 36px minmax(0, 1fr);
    grid-template-areas:
      "thumb nom"
      "thumb bilan"
      "taux taux";
    row-gap: var(--space-1);
  }
}
</style>
