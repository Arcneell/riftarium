<script setup>
import { computed, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { api, cardThumb, DOMAINS } from "../api.js";

const route = useRoute();
const deck = ref(null);
const error = ref("");
const saved = ref("");
const searchQuery = ref("");
const searchResults = ref([]);
let timer = null;

const ZONES = [
  { key: "Legend", label: "Légende" },
  { key: "Battlefield", label: "Champs de bataille" },
  { key: "Rune", label: "Runes" },
  { key: "main", label: "Deck principal" }
];

const grouped = computed(() => {
  const groups = { Legend: [], Battlefield: [], Rune: [], main: [] };
  for (const entry of deck.value?.cards || []) {
    const zone = groups[entry.card.type] ? entry.card.type : "main";
    groups[zone].push(entry);
  }
  return groups;
});

/* Courbe d'énergie du deck principal (0 à 7+) */
const curve = computed(() => {
  const buckets = Array(8).fill(0);
  for (const entry of grouped.value.main) {
    const cost = Math.min(entry.card.energy ?? 0, 7);
    buckets[cost] += entry.qty;
  }
  const max = Math.max(...buckets, 1);
  return buckets.map((count, cost) => ({ cost, count, height: (count / max) * 100 }));
});

/* Répartition par domaine */
const domainSpread = computed(() => {
  const counts = {};
  for (const entry of deck.value?.cards || []) {
    for (const domain of entry.card.domains || []) {
      if (domain === "Colorless") continue;
      counts[domain] = (counts[domain] || 0) + entry.qty;
    }
  }
  return Object.entries(counts).sort((a, b) => b[1] - a[1]);
});

async function load() {
  try {
    deck.value = await api(`/api/decks/${route.params.id}`);
  } catch (e) {
    error.value = e.message;
  }
}

function onSearch() {
  clearTimeout(timer);
  timer = setTimeout(async () => {
    if (searchQuery.value.trim().length < 2) { searchResults.value = []; return; }
    const params = new URLSearchParams({ q: searchQuery.value.trim(), size: 18 });
    searchResults.value = (await api(`/api/cards?${params}`)).items;
  }, 250);
}

function setQty(cardId, delta, card = null) {
  const cards = deck.value.cards;
  const existing = cards.find(entry => entry.card.id === cardId);
  if (existing) {
    existing.qty += delta;
    if (existing.qty <= 0) cards.splice(cards.indexOf(existing), 1);
  } else if (delta > 0 && card) {
    cards.push({ card, qty: 1 });
  }
}

async function save() {
  error.value = "";
  saved.value = "";
  try {
    deck.value = await api(`/api/decks/${deck.value.id}`, {
      method: "PUT",
      body: {
        name: deck.value.name,
        description: deck.value.description,
        format: deck.value.format,
        is_public: deck.value.is_public,
        cards: deck.value.cards.map(entry => ({ card_id: entry.card.id, qty: entry.qty }))
      }
    });
    saved.value = "Enregistré.";
    setTimeout(() => (saved.value = ""), 2200);
  } catch (e) {
    error.value = e.message;
  }
}

watch(() => route.params.id, load, { immediate: true });
</script>

<template>
  <section style="padding-top:44px" v-if="deck">
    <div class="wrap">
      <p style="margin-bottom:22px"><RouterLink to="/decks">← Mes decks</RouterLink></p>

      <div class="toolbar">
        <input type="text" v-model="deck.name" style="max-width:340px; font-size:1.05rem" aria-label="Nom du deck" />
        <select v-model="deck.format" style="max-width:180px" aria-label="Format">
          <option value="tournament">Mode tournoi</option>
          <option value="free">Mode libre</option>
        </select>
        <label class="switch">
          <input type="checkbox" v-model="deck.is_public" /><i></i> Public
        </label>
        <button class="btn btn-gold" @click="save">Enregistrer</button>
        <span v-if="saved" class="success">{{ saved }}</span>
        <span v-if="error" class="error">{{ error }}</span>
      </div>
      <p v-if="deck.moderation_status === 'pending'" class="error" style="margin-bottom:16px">
        En attente de modération : ce deck n'est pas visible publiquement.
      </p>

      <div class="builder">
        <div>
          <template v-for="zone in ZONES" :key="zone.key">
            <p class="zone-title">{{ zone.label }}
              <small>{{ grouped[zone.key].reduce((total, entry) => total + entry.qty, 0) }} carte(s)</small>
            </p>
            <div class="deck-grid" v-if="grouped[zone.key].length">
              <div class="dcard" v-tilt
                   v-for="entry in grouped[zone.key]" :key="entry.card.id"
                   :class="{ landscape: entry.card.orientation === 'landscape' }">
                <RouterLink :to="`/cartes/${entry.card.id}`">
                  <img :src="cardThumb(entry.card.image_url, 240)" :alt="`Carte Riftbound : ${entry.card.name}`" loading="lazy" decoding="async" />
                </RouterLink>
                <span class="dqty">{{ entry.qty }}×</span>
                <div class="dcard-actions">
                  <button @click="setQty(entry.card.id, -1)" :aria-label="`Retirer un exemplaire de ${entry.card.name}`">−</button>
                  <button @click="setQty(entry.card.id, 1)" :aria-label="`Ajouter un exemplaire de ${entry.card.name}`">+</button>
                </div>
              </div>
            </div>
            <p v-else class="muted" style="font-size:.85rem">Rien pour l'instant — cherchez une carte à droite.</p>
          </template>

          <div class="panel" style="margin-top:36px">
            <h3 style="margin-bottom:6px">Courbe d'énergie</h3>
            <div class="curve" role="img" aria-label="Répartition des coûts en énergie du deck principal">
              <div class="bar" v-for="bucket in curve" :key="bucket.cost">
                <i :style="{ height: bucket.height + '%' }" :title="`${bucket.count} carte(s) à ${bucket.cost}`"></i>
                <small>{{ bucket.cost }}{{ bucket.cost === 7 ? "+" : "" }}</small>
              </div>
            </div>
            <div style="display:flex; gap:10px; flex-wrap:wrap; margin-top:18px" v-if="domainSpread.length">
              <span class="chip" v-for="[domain, count] in domainSpread" :key="domain"
                    :style="{ '--chip': DOMAINS[domain]?.color }">
                {{ DOMAINS[domain]?.label || domain }} · {{ count }}
              </span>
            </div>
          </div>
        </div>

        <div class="builder-side">
          <div class="panel">
            <h3 style="margin-bottom:14px">Ajouter des cartes</h3>
            <label class="search" style="margin-bottom:16px">
              <Icon name="search" :size="18" />
              <input type="search" v-model="searchQuery" @input="onSearch" placeholder="Nom, code, texte…" aria-label="Rechercher une carte à ajouter" />
            </label>
            <div class="hits-grid" v-if="searchResults.length">
              <button class="hit-card" v-for="card in searchResults" :key="card.id"
                      @click="setQty(card.id, 1, card)" :aria-label="`Ajouter ${card.name} au deck`">
                <img :src="cardThumb(card.image_url, 180)" :alt="''" loading="lazy" decoding="async" />
                <span>{{ card.name }}</span>
              </button>
            </div>
            <p v-else-if="searchQuery.length >= 2" class="muted" style="font-size:.85rem">Aucun résultat.</p>
            <p v-else class="muted" style="font-size:.85rem">Un clic sur une carte l'ajoute au deck.</p>
          </div>

          <div class="panel">
            <h3 style="margin-bottom:14px">
              Validation <span class="muted" style="font-size:.75rem">{{ deck.format === "tournament" ? "règles de tournoi" : "mode libre, à titre indicatif" }}</span>
            </h3>
            <ul class="validator">
              <li v-for="checkItem in deck.checks" :key="checkItem.rule" :class="checkItem.ok ? 'v-ok' : 'v-ko'">
                {{ checkItem.message }}
              </li>
            </ul>
          </div>

          <div class="panel">
            <h3 style="margin-bottom:10px">Description</h3>
            <textarea v-model="deck.description" placeholder="Plan de jeu, forces, faiblesses…" aria-label="Description du deck"></textarea>
          </div>
        </div>
      </div>
    </div>
  </section>
  <section v-else><div class="wrap"><p v-if="error" class="error">{{ error }}</p></div></section>
</template>
