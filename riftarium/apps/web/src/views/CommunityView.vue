<script setup>
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session } from "../api.js"
import { csvJoin, csvSplit, domainFilterOptions } from "../cardText.js"
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

const route = useRoute()
const router = useRouter()

function fromQuery(query) {
  return {
    q: query.q || "",
    legend: csvSplit(query.legend),
    domain: csvSplit(query.domain),
    format: csvSplit(query.format),
    sort: SORTS.some((item) => item.value === query.sort) ? query.sort : "likes",
    liked: query.liked === "1",
    page: Math.max(1, Number(query.page) || 1)
  }
}

const state = reactive(fromQuery(route.query))
const result = ref({ total: 0, items: [] })
const legends = ref([])
const loading = ref(false)
const error = ref("")
const size = 20
let timer = null

const domainOptions = computed(() => domainFilterOptions())
const legendOptions = computed(() =>
  legends.value.map((item) => ({ value: item.id, label: `${item.name} (${item.deck_count})` }))
)
const pageCount = computed(() => Math.max(1, Math.ceil(result.value.total / size)))
const activeCount = computed(
  () => (state.q ? 1 : 0) + state.legend.length + state.domain.length + state.format.length + (state.liked ? 1 : 0)
)

function toQuery() {
  const query = {}
  if (state.q) query.q = state.q
  if (state.legend.length) query.legend = csvJoin(state.legend)
  if (state.domain.length) query.domain = csvJoin(state.domain)
  if (state.format.length) query.format = csvJoin(state.format)
  if (state.sort !== "likes") query.sort = state.sort
  if (state.liked) query.liked = "1"
  if (state.page > 1) query.page = String(state.page)
  return query
}

function communityQuery() {
  const params = new URLSearchParams({ page: String(state.page), size: String(size), sort: state.sort })
  if (state.q) params.set("q", state.q)
  if (state.legend.length) params.set("legend", csvJoin(state.legend))
  if (state.domain.length) params.set("domain", csvJoin(state.domain))
  if (state.format.length) params.set("format", csvJoin(state.format))
  if (state.liked) params.set("liked", "1")
  return params
}

async function load() {
  loading.value = true
  error.value = ""
  try {
    result.value = await api(`/api/community/decks?${communityQuery()}`)
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

function scheduleLoad() {
  clearTimeout(timer)
  timer = setTimeout(load, 180)
}

function setFilter(key, values) {
  state[key] = values
  state.page = 1
}

function setSort(value) {
  state.sort = value
  state.page = 1
}

function toggleLiked() {
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: "/communaute?liked=1" } })
    return
  }
  state.liked = !state.liked
  state.page = 1
}

function reset() {
  state.q = ""
  state.legend = []
  state.domain = []
  state.format = []
  state.liked = false
  state.page = 1
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

watch(
  () => [state.q, state.legend.join(), state.domain.join(), state.format.join(), state.sort, state.liked, state.page],
  () => {
    const query = toQuery()
    if (JSON.stringify(route.query) !== JSON.stringify(query)) router.replace({ query })
    scheduleLoad()
  }
)

watch(
  () => route.query,
  (query) => {
    const next = fromQuery(query)
    if (
      next.q === state.q &&
      next.page === state.page &&
      next.sort === state.sort &&
      next.liked === state.liked &&
      next.legend.join() === state.legend.join() &&
      next.domain.join() === state.domain.join() &&
      next.format.join() === state.format.join()
    ) {
      return
    }
    Object.assign(state, next)
  }
)

onMounted(async () => {
  load()
  try {
    legends.value = await api("/api/community/legends")
  } catch {
    /* filtre légendes indisponible */
  }
})

onBeforeUnmount(() => clearTimeout(timer))
</script>

<template>
  <PageBanner :art="BANNERS.community" eyebrow="Communauté" title="Decks partagés">
    Parcourez les decks publiés, filtrez par légende, domaine ou format — officiel ou non officiel.
  </PageBanner>

  <section style="padding-top: 40px">
    <div class="wrap">
      <div class="filter-board">
        <label class="search filter-search">
          <Icon name="search" :size="18" />
          <input type="search" v-model="state.q" placeholder="Nom, auteur, légende…" aria-label="Rechercher un deck" />
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
          v-if="legendOptions.length"
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
        Rien ici pour l'instant. Le premier deck publié depuis <RouterLink to="/decks">l'éditeur</RouterLink> ouvrira le
        bal.
      </p>
    </div>
  </section>
</template>
