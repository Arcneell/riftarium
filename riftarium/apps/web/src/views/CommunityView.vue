<script setup>
import { computed, onMounted, ref } from "vue"
import { useRouter } from "vue-router"
import { api, session } from "../api.js"
import { csvJoin, domainFilterOptions } from "../cardText.js"
import { useQuerySyncedFilters } from "../composables/useQuerySyncedFilters.js"
import { FORMAT_OPTIONS } from "../deckDisplay.js"
import { BANNERS } from "../banners.js"
import DeckBox from "../components/DeckBox.vue"
import FilterSelect from "../components/FilterSelect.vue"
import PageBanner from "../components/PageBanner.vue"

const SORTS = [
  { value: "likes", label: "Tendance" },
  { value: "views", label: "Plus vus" },
  { value: "recent", label: "Récents" }
]

const router = useRouter()
const size = 20

const { state, result, loading, error, activeCount, pageCount, setFilter, reset, load } = useQuerySyncedFilters(
  {
    q: { kind: "text" },
    legend: { kind: "list" },
    domain: { kind: "list" },
    format: { kind: "list" },
    /* Le tri n'est pas un filtre : hors compteur et épargné par la remise à zéro. */
    sort: { kind: "enum", values: SORTS.map((item) => item.value), default: "likes", reset: false },
    liked: { kind: "flag" },
    buildable: { kind: "flag" },
    page: { kind: "page" }
  },
  {
    fetcher: () => api(`/api/community/decks?${communityQuery()}`),
    pageSize: size
  }
)

const legends = ref([])

const domainOptions = computed(() => domainFilterOptions())
const legendOptions = computed(() =>
  legends.value.map((item) => ({ value: item.id, label: `${item.name} (${item.deck_count})` }))
)

function communityQuery() {
  const params = new URLSearchParams({ page: String(state.page), size: String(size), sort: state.sort })
  if (state.q) params.set("q", state.q)
  if (state.legend.length) params.set("legend", csvJoin(state.legend))
  if (state.domain.length) params.set("domain", csvJoin(state.domain))
  if (state.format.length) params.set("format", csvJoin(state.format))
  if (state.liked) params.set("liked", "1")
  if (state.buildable) params.set("buildable", "1")
  return params
}

function setSort(value) {
  setFilter("sort", value)
}

function toggleLiked() {
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: "/communaute?liked=1" } })
    return
  }
  setFilter("liked", !state.liked)
}

async function toggleLike(deck) {
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: "/communaute" } })
    return
  }
  try {
    const payload = await api(`/api/decks/${deck.id}/like`, { method: "POST" })
    deck.likes = payload.likes
    deck.liked_by_me = payload.liked_by_me
    if (state.liked && !payload.liked_by_me) {
      result.value.items = result.value.items.filter((item) => item.id !== deck.id)
      result.value.total = Math.max(0, result.value.total - 1)
    }
  } catch (e) {
    error.value = e.message
  }
}

onMounted(async () => {
  load()
  try {
    legends.value = await api("/api/community/legends")
  } catch {
    /* filtre légendes indisponible */
  }
})
</script>

<template>
  <PageBanner :art="BANNERS.community" title="Decks partagés" />

  <section>
    <div class="wrap">
      <div class="filter-board">
        <label class="search filter-search">
          <Icon name="search" :size="18" />
          <input
            type="search"
            inputmode="search"
            enterkeyhint="search"
            autocapitalize="off"
            autocorrect="off"
            spellcheck="false"
            v-model="state.q"
            placeholder="Nom, auteur, légende…"
            aria-label="Rechercher un deck"
          />
        </label>
        <div class="owned-seg" role="group" aria-label="Trier les decks">
          <button
            v-for="item in SORTS"
            :key="item.value"
            type="button"
            :class="{ on: state.sort === item.value }"
            @click="setSort(item.value)"
          >
            {{ item.label }}
          </button>
        </div>
        <FilterSelect
          label="Légendes"
          searchable
          :options="legendOptions"
          :model-value="state.legend"
          @update:model-value="setFilter('legend', $event)"
        />
        <FilterSelect
          label="Domaines"
          :options="domainOptions"
          :model-value="state.domain"
          @update:model-value="setFilter('domain', $event)"
        />
        <FilterSelect
          label="Format"
          :options="FORMAT_OPTIONS"
          :model-value="state.format"
          @update:model-value="setFilter('format', $event)"
        />
        <button type="button" class="btn btn-ghost btn-sm" :aria-pressed="state.liked" @click="toggleLiked">
          {{ state.liked ? "Mes likes" : "Aimés" }}
        </button>
        <!-- Réservé aux connectés : la comparaison se fait avec leur collection. -->
        <button
          v-if="session.token"
          type="button"
          class="filter buildable-filter"
          :aria-pressed="state.buildable"
          @click="setFilter('buildable', !state.buildable)"
        >
          Constructibles avec ma collection
        </button>
        <button v-if="activeCount" class="btn btn-ghost btn-sm" @click="reset">
          Réinitialiser ({{ activeCount }})
        </button>
      </div>

      <p class="muted mono" style="font-size: 0.82rem; margin-bottom: 18px">
        {{ result.total }} deck(s) <span v-if="loading">— chargement…</span>
      </p>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="deck-boxes">
        <DeckBox
          v-for="(deck, i) in result.items"
          :key="deck.id"
          v-reveal="i"
          community
          :deck="deck"
          :to="`/decks/${deck.id}`"
          @like="toggleLike"
        />
      </div>

      <div class="pager" v-if="pageCount > 1">
        <button class="btn btn-ghost btn-sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</button>
        <span>page {{ state.page }} / {{ pageCount }}</span>
        <button class="btn btn-ghost btn-sm" :disabled="state.page >= pageCount" @click="state.page++">
          Suivant →
        </button>
      </div>

      <p v-if="!result.items.length && !error && !loading" class="muted">
        Aucun deck publié ne correspond. Les decks se publient depuis <RouterLink to="/decks">l'éditeur</RouterLink>.
      </p>
    </div>
  </section>
</template>
