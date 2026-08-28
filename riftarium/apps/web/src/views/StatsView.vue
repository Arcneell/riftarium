<script setup>
import { computed, onMounted, ref } from "vue"
import { cardThumb } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import ColumnChart from "../components/charts/ColumnChart.vue"
import { lastDays, zeroFillDays } from "../components/charts/chartUtils.js"
import { formatLabel } from "../deckDisplay.js"
import { formatWinRate, getStats, modeLabel, winRatePercent } from "../play.js"

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
const byLegend = computed(() => stats.value?.by_legend || [])
const byOpponentLegend = computed(() => stats.value?.by_opponent_legend || [])
const byFormat = computed(() => stats.value?.by_format || [])

/* Le contrat ne chiffre le taux que par deck : ailleurs il se déduit de J / G. */
const rateOf = (row) => (row.played ? row.won / row.played : null)

/* `current_streak` peut être négatif (série de défaites) : on n'affiche que la
   valeur absolue, la nature de la série passe dans la légende sous le chiffre. */
const currentStreak = computed(() => Number(totals.value.current_streak || 0))

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
  <PageBanner :art="BANNERS.community" title="Mes statistiques" />

  <section>
    <div class="wrap play-page play-stats">
      <p v-if="error" class="error">{{ error }}</p>
      <p v-else-if="loading" class="muted">Chargement des statistiques…</p>

      <template v-else-if="!empty">
        <div class="stat-row">
          <div class="stat">
            Parties jouées
            <b>{{ totals.played }}</b>
          </div>
          <div class="stat">
            Victoires
            <b>{{ totals.won }}</b>
          </div>
          <div class="stat">
            Défaites
            <b>{{ totals.lost }}</b>
          </div>
          <div class="stat">
            Taux de victoire
            <b>{{ formatWinRate(totals.win_rate ?? rateOf(totals)) }}</b>
          </div>
          <div class="stat">
            Série en cours
            <b>{{ currentStreak ? Math.abs(currentStreak) : "—" }}</b>
            <span class="stat-delta">{{ currentStreak < 0 ? "défaites d'affilée" : "victoires d'affilée" }}</span>
          </div>
          <div class="stat">
            Meilleure série
            <b>{{ totals.best_streak || 0 }}</b>
            <span class="stat-delta">victoires d'affilée</span>
          </div>
        </div>

        <p class="muted play-note">
          Seules les parties confirmées par les deux joueurs (et les abandons) comptent ici : un résultat contesté reste
          dans l'<RouterLink to="/historique">historique</RouterLink> mais pas dans les statistiques.
        </p>

        <div class="panel chart-panel-wide">
          <ColumnChart
            title="Parties des 30 derniers jours"
            :days="chartDays"
            :values="playedValues"
            value-label="Parties"
            color="var(--chart-gold)"
            :line-values="wonValues"
            line-label="Victoires"
            line-color="var(--chart-teal)"
          />
        </div>

        <div v-if="byDeck.length" class="panel play-panel">
          <h3>Par deck</h3>
          <div class="play-table-scroll">
            <table class="play-table">
              <thead>
                <tr>
                  <th scope="col">Deck</th>
                  <th scope="col">Format</th>
                  <th scope="col" class="num">J</th>
                  <th scope="col" class="num">G</th>
                  <th scope="col" class="num">P</th>
                  <th scope="col">Taux de victoire</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in byDeck" :key="row.deck_id">
                  <td>
                    <RouterLink v-if="row.deck_id" :to="`/decks/${row.deck_id}`">{{ row.name }}</RouterLink>
                    <span v-else>{{ row.name }}</span>
                  </td>
                  <td class="mono">{{ formatLabel(row.format) }}</td>
                  <td class="num mono">{{ row.played }}</td>
                  <td class="num mono">{{ row.won }}</td>
                  <td class="num mono">{{ row.lost }}</td>
                  <td>
                    <span class="play-bar">
                      <span
                        class="play-bar-fill"
                        :style="{ width: `${winRatePercent(row.win_rate ?? rateOf(row))}%` }"
                      ></span>
                    </span>
                    <span class="mono play-bar-value">{{ formatWinRate(row.win_rate ?? rateOf(row)) }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="play-grid">
          <div v-if="byLegend.length" class="panel play-panel">
            <h3>Par légende</h3>
            <ul class="play-legend-list">
              <li v-for="row in byLegend" :key="row.card_id">
                <img
                  v-if="row.image_url"
                  class="play-legend-thumb"
                  :src="cardThumb(row.image_url, 72)"
                  :alt="`Légende : ${row.name}`"
                  width="72"
                  height="72"
                  loading="lazy"
                  decoding="async"
                />
                <span v-else class="play-legend-thumb empty" aria-hidden="true"></span>
                <span class="play-legend-name">{{ row.name }}</span>
                <span class="play-bar">
                  <span class="play-bar-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
                </span>
                <span class="mono play-legend-record">
                  {{ row.won }} V / {{ row.lost }} D · {{ formatWinRate(rateOf(row)) }}
                </span>
              </li>
            </ul>
          </div>

          <div v-if="byOpponentLegend.length" class="panel play-panel">
            <h3>Par légende adverse</h3>
            <ul class="play-legend-list">
              <li v-for="row in byOpponentLegend" :key="row.card_id">
                <img
                  v-if="row.image_url"
                  class="play-legend-thumb"
                  :src="cardThumb(row.image_url, 72)"
                  :alt="`Légende adverse : ${row.name}`"
                  width="72"
                  height="72"
                  loading="lazy"
                  decoding="async"
                />
                <span v-else class="play-legend-thumb empty" aria-hidden="true"></span>
                <span class="play-legend-name">{{ row.name }}</span>
                <span class="play-bar">
                  <span class="play-bar-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
                </span>
                <span class="mono play-legend-record">
                  {{ row.won }} V / {{ row.lost }} D · {{ formatWinRate(rateOf(row)) }}
                </span>
              </li>
            </ul>
          </div>
        </div>

        <div v-if="byFormat.length" class="panel play-panel">
          <h3>Par format</h3>
          <div class="play-table-scroll">
            <table class="play-table">
              <thead>
                <tr>
                  <th scope="col">Format</th>
                  <th scope="col" class="num">J</th>
                  <th scope="col" class="num">G</th>
                  <th scope="col" class="num">P</th>
                  <th scope="col">Taux de victoire</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="row in byFormat" :key="row.mode">
                  <td>{{ modeLabel(row.mode) }}</td>
                  <td class="num mono">{{ row.played }}</td>
                  <td class="num mono">{{ row.won }}</td>
                  <td class="num mono">{{ row.lost }}</td>
                  <td>
                    <span class="play-bar">
                      <span class="play-bar-fill" :style="{ width: `${winRatePercent(rateOf(row))}%` }"></span>
                    </span>
                    <span class="mono play-bar-value">{{ formatWinRate(rateOf(row)) }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </template>

      <div v-else class="panel play-empty">
        <h3>Pas encore de partie suivie</h3>
        <p class="muted">
          Le compteur vit sur le téléphone : ouvrez l'application Riftarium, choisissez « Jouer » puis « Partie suivie »
          pour créer un salon. Votre adversaire vous rejoint avec le code ou le lien partagé.
        </p>
        <p class="muted">
          Un code vous a été envoyé ? Ouvrez le <RouterLink to="/salon">salon</RouterLink> pour le saisir.
        </p>
        <RouterLink class="btn btn-gold" to="/salon">Rejoindre un salon</RouterLink>
      </div>
    </div>
  </section>
</template>
