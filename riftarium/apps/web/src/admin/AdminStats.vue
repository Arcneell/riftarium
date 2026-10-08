<script setup>
import "./console.css"
import { computed, onMounted, ref } from "vue"
import { api } from "../api.js"
import ColumnChart from "../components/charts/ColumnChart.vue"
import HBarChart from "../components/charts/HBarChart.vue"
import StackedBar from "../components/charts/StackedBar.vue"
import { lastDays, zeroFillDays } from "../components/charts/chartUtils.js"
import RiftChip from "../ui/RiftChip.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import { formatDate, moderationColor, moderationLabel } from "./useAdmin.js"

/* Libellés des rubriques du comptage de fréquentation anonyme (voir router.js). */
const SECTION_LABELS = {
  home: "Accueil",
  cartes: "Cartothèque",
  carte: "Fiche carte",
  regles: "Règles",
  decks: "Mes decks",
  deck: "Fiche deck",
  communaute: "Communauté",
  collection: "Collection",
  scan: "Scan",
  profil: "Profil",
  "profil-public": "Profil public",
  amis: "Amis",
  historique: "Historique",
  statistiques: "Statistiques",
  salon: "Salon de jeu",
  autre: "Autre"
}

/* Couleurs des graphiques, toutes en tokens : volume en bronze, deuxième série
   en sang, troisième en encre atténuée. */
const SERIES = { volume: "var(--bronze)", second: "var(--blood)", third: "var(--ink-muted)" }

const stats = ref(null)
const loading = ref(false)
const error = ref("")

/* Axe de 30 jours des graphiques : celui des séries serveur (zéro-remplies) pour éviter
   tout décalage de fuseau, sinon les 30 derniers jours locaux. */
const chartDays = computed(() => {
  const serverAxis = (stats.value?.series?.signups_daily || []).map((point) => point.day)
  return serverAxis.length ? serverAxis : lastDays(30)
})
/* visits.daily peut avoir des trous (jours sans visite) : zéro-remplissage côté client. */
const visitsDaily = computed(() => zeroFillDays(stats.value?.visits?.daily, chartDays.value, { hits: 0, uniques: 0 }))
const visitHits = computed(() => visitsDaily.value.map((day) => day.hits))
const visitUniques = computed(() => visitsDaily.value.map((day) => day.uniques))
const signupCounts = computed(() => (stats.value?.series?.signups_daily || []).map((point) => point.count))
const deckDays = computed(() => (stats.value?.series?.decks_daily || []).map((point) => point.day))
const deckCounts = computed(() => (stats.value?.series?.decks_daily || []).map((point) => point.count))
/* Delta 7 jours des decks : somme des 7 derniers points de la série quotidienne. */
const decksNew7d = computed(() =>
  (stats.value?.series?.decks_daily || []).slice(-7).reduce((sum, point) => sum + point.count, 0)
)
const sectionRows = computed(() =>
  (stats.value?.visits?.sections_7d || []).map((row) => ({
    label: SECTION_LABELS[row.section] || row.section,
    value: row.hits
  }))
)
/* Barre empilée des statuts de modération : ok bronze clair, attente encre, ko sang. */
const moderationSegments = computed(() => [
  { label: "Publiés", value: stats.value?.decks?.published ?? 0, color: "var(--bronze-light)" },
  { label: "En attente", value: stats.value?.decks?.pending ?? 0, color: "var(--ink-muted)" },
  { label: "Rejetés", value: stats.value?.decks?.rejected ?? 0, color: "var(--blood)" }
])
const moderationTotal = computed(() => moderationSegments.value.reduce((sum, segment) => sum + segment.value, 0))

/* Tuiles de chiffres clés, groupées par rubrique. `delta` : variation sur 7 jours. */
const groups = computed(() => {
  const s = stats.value
  if (!s) return []
  const list = [
    {
      title: "Utilisateurs",
      items: [
        { label: "Total", value: s.users.total, delta: s.users.new_7d },
        { label: "Nouveaux (7 j)", value: s.users.new_7d },
        { label: "Nouveaux (30 j)", value: s.users.new_30d },
        { label: "Suspendus", value: s.users.suspended },
        { label: "E-mails vérifiés", value: s.users.verified }
      ]
    },
    {
      title: "Decks",
      items: [
        { label: "Total", value: s.decks.total, delta: s.series ? decksNew7d.value : null },
        { label: "Publics", value: s.decks.public },
        { label: "En attente", value: s.decks.pending },
        { label: "Likes", value: s.decks.likes_total },
        { label: "Vues", value: s.decks.views_total }
      ]
    },
    {
      title: "Collection & cartothèque",
      items: [
        { label: "Entrées de collection", value: s.collection?.entries_total ?? 0 },
        { label: "Exemplaires", value: s.collection?.cards_total ?? 0 },
        { label: "Cartes référencées", value: s.cards?.total ?? 0 },
        { label: "Sets", value: s.cards?.sets ?? 0 }
      ]
    }
  ]
  if (s.visits) {
    list.push({
      title: "Fréquentation",
      items: [
        { label: "Visites aujourd'hui", value: s.visits.today_hits },
        { label: "Visites (7 j)", value: s.visits.hits_7d },
        { label: "Visites (30 j)", value: s.visits.hits_30d },
        { label: "Uniques aujourd'hui", value: s.visits.uniques_today },
        { label: "Uniques (7 j)", value: s.visits.uniques_7d }
      ]
    })
  }
  return list
})

async function load() {
  loading.value = true
  error.value = ""
  try {
    stats.value = await api("/api/admin/stats")
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

/* Chaque activation de l'onglet remonte le composant : les chiffres restent frais. */
onMounted(load)
</script>

<template>
  <div class="console-stats">
    <p v-if="error" class="console-error" role="alert">{{ error }}</p>
    <div v-else-if="loading && !stats" role="status">
      <span class="sr-only">Chargement des statistiques…</span>
      <RiftSkeleton :lines="4" />
    </div>

    <template v-if="stats">
      <section v-for="group in groups" :key="group.title" class="console-group">
        <h2 class="console-heading">{{ group.title }}</h2>
        <dl class="console-kpis">
          <div v-for="item in group.items" :key="item.label" class="console-kpi">
            <dt class="console-kpi-label">{{ item.label }}</dt>
            <dd class="console-kpi-value">
              {{ item.value }}
              <span
                v-if="item.delta !== undefined && item.delta !== null"
                class="console-delta"
                :class="{ 'is-up': item.delta > 0 }"
              >
                +{{ item.delta }} (7 j)
              </span>
            </dd>
          </div>
        </dl>
      </section>

      <RiftPanel v-if="stats.visits" tag="div" class="console-chart">
        <ColumnChart
          title="Fréquentation (30 jours)"
          :days="chartDays"
          :values="visitHits"
          value-label="Visites"
          :color="SERIES.volume"
          :line-values="visitUniques"
          line-label="Visiteurs uniques"
          :line-color="SERIES.second"
        />
      </RiftPanel>

      <div v-if="stats.series" class="console-grid">
        <RiftPanel tag="div" class="console-chart">
          <ColumnChart
            title="Inscriptions (30 jours)"
            :days="chartDays"
            :values="signupCounts"
            value-label="Inscriptions"
            :color="SERIES.second"
          />
        </RiftPanel>
        <RiftPanel tag="div" class="console-chart">
          <ColumnChart
            title="Decks créés (30 jours)"
            :days="deckDays"
            :values="deckCounts"
            value-label="Decks créés"
            :color="SERIES.third"
          />
        </RiftPanel>
      </div>

      <div v-if="stats.visits || moderationTotal > 0" class="console-grid">
        <RiftPanel
          v-if="stats.visits"
          tag="div"
          class="console-chart"
          :title="sectionRows.length ? '' : 'Rubriques les plus visitées (7 j)'"
        >
          <HBarChart
            v-if="sectionRows.length"
            title="Rubriques les plus visitées (7 j)"
            :rows="sectionRows"
            value-label="Visites"
            :color="SERIES.volume"
          />
          <p v-else class="console-muted">Pas encore de données.</p>
        </RiftPanel>
        <RiftPanel v-if="moderationTotal > 0" tag="div" class="console-chart">
          <StackedBar title="Statuts de modération" :segments="moderationSegments" />
        </RiftPanel>
      </div>

      <div class="console-grid">
        <RiftPanel title="Dernières inscriptions" accent="var(--bronze)">
          <ul class="console-recent">
            <li v-for="signup in stats.recent?.signups ?? []" :key="signup.handle + signup.created_at">
              <b class="console-recent-name">{{ signup.handle }}</b>
              <span class="console-mono">{{ formatDate(signup.created_at) }}</span>
            </li>
            <li v-if="!stats.recent?.signups?.length" class="console-muted">Aucune inscription récente.</li>
          </ul>
        </RiftPanel>
        <RiftPanel title="Derniers decks" accent="var(--bronze)">
          <ul class="console-recent">
            <li v-for="deck in stats.recent?.decks ?? []" :key="deck.id">
              <RouterLink class="console-link console-recent-name" :to="`/decks/${deck.id}`">{{
                deck.name
              }}</RouterLink>
              <span class="console-muted">par {{ deck.owner }}</span>
              <RiftChip
                static
                selected
                :label="moderationLabel(deck.moderation_status)"
                :color="moderationColor(deck.moderation_status)"
              />
              <span class="console-mono">{{ formatDate(deck.created_at) }}</span>
            </li>
            <li v-if="!stats.recent?.decks?.length" class="console-muted">Aucun deck récent.</li>
          </ul>
        </RiftPanel>
      </div>
    </template>
  </div>
</template>

<style scoped>
.console-stats {
  display: grid;
  gap: var(--space-4);
}
/* `section` hérite des marges de main.css : on les neutralise. */
.console-group {
  margin: 0;
  padding: 0;
}
.console-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 1px;
  margin: 0;
  background: var(--line);
  border: 1px solid var(--line);
}
.console-kpi {
  display: grid;
  align-content: start;
  gap: 2px;
  padding: var(--space-2) var(--space-3);
  background: var(--bg-raised);
}
.console-kpi-label {
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.console-kpi-value {
  display: flex;
  align-items: baseline;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin: 0;
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  color: var(--ink);
}
.console-delta {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.console-delta.is-up {
  color: var(--bronze-light);
}
.console-chart {
  min-width: 0;
  padding: var(--space-4);
}
.console-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-items: start;
  gap: var(--space-4);
}
.console-recent {
  display: grid;
  margin: 0;
  padding: 0;
  list-style: none;
}
.console-recent li {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--space-1) var(--space-3);
  min-height: 40px;
  padding: var(--space-1) 0;
  border-bottom: 1px solid var(--line);
}
.console-recent li:last-child {
  border-bottom: 0;
}
.console-recent-name {
  font-weight: 600;
  color: var(--ink);
}
.console-recent .console-mono {
  margin-left: auto;
}
@media (max-width: 1023px) {
  .console-grid {
    grid-template-columns: minmax(0, 1fr);
  }
}
</style>
