<script setup>
import { onMounted, reactive, ref, watch } from "vue";
import { api, DOMAINS, TYPES } from "../api.js";
import CardTile from "../components/CardTile.vue";

const state = reactive({ q: "", set_id: "", type: "", domain: "", page: 1 });
const result = ref({ total: 0, items: [] });
const sets = ref([]);
const loading = ref(false);
const error = ref("");
const SIZE = 30;

let timer = null;

async function load() {
  loading.value = true;
  error.value = "";
  try {
    const params = new URLSearchParams({ page: state.page, size: SIZE });
    for (const key of ["q", "set_id", "type", "domain"]) {
      if (state[key]) params.set(key, state[key]);
    }
    result.value = await api(`/api/cards?${params}`);
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

watch(() => [state.set_id, state.type, state.domain], () => { state.page = 1; load(); });
watch(() => state.page, load);
watch(() => state.q, () => {
  clearTimeout(timer);
  timer = setTimeout(() => { state.page = 1; load(); }, 250);
});

function toggle(key, value) {
  state[key] = state[key] === value ? "" : value;
}

onMounted(async () => {
  load();
  try { sets.value = await api("/api/sets"); } catch { /* filtre sets indisponible */ }
});
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Cartothèque</p>
      <h2>Toutes les cartes du jeu</h2>
      <p class="lead">Cherchez par nom, code ou texte. Filtrez par domaine, type ou set.</p>
    </div>
  </div>

  <section style="padding-top:40px">
    <div class="wrap">
      <div class="toolbar">
        <label class="search">
          <Icon name="search" :size="18" />
          <input type="search" v-model="state.q" placeholder="Jinx, ogn-202, reaction…" aria-label="Rechercher une carte" />
        </label>
        <select v-model="state.set_id" style="max-width:230px" aria-label="Filtrer par set">
          <option value="">Tous les sets</option>
          <option v-for="s in sets" :key="s.set_id" :value="s.set_id">{{ s.name }} ({{ s.card_count }})</option>
        </select>
      </div>

      <div class="toolbar">
        <div class="filters" role="group" aria-label="Filtrer par domaine">
          <button v-for="(d, key) in DOMAINS" :key="key" v-show="key !== 'Colorless'"
                  class="filter" :style="{ '--chip': d.color }"
                  :aria-pressed="state.domain === key" @click="toggle('domain', key)">
            {{ d.label }}
          </button>
        </div>
        <div class="filters" role="group" aria-label="Filtrer par type">
          <button v-for="(label, key) in TYPES" :key="key" class="filter"
                  :aria-pressed="state.type === key" @click="toggle('type', key)">
            {{ label }}
          </button>
        </div>
      </div>

      <p class="muted mono" style="font-size:.82rem; margin-bottom:24px">
        {{ result.total }} carte(s) <span v-if="loading">— chargement…</span>
      </p>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="grid-cards">
        <CardTile v-for="card in result.items" :key="card.id" :card="card" />
      </div>

      <div class="pager" v-if="result.total > SIZE">
        <button class="btn btn-ghost btn-sm" :disabled="state.page <= 1" @click="state.page--">← Précédent</button>
        <span>page {{ state.page }} / {{ Math.ceil(result.total / SIZE) }}</span>
        <button class="btn btn-ghost btn-sm" :disabled="state.page >= Math.ceil(result.total / SIZE)" @click="state.page++">Suivant →</button>
      </div>
    </div>
  </section>
</template>
