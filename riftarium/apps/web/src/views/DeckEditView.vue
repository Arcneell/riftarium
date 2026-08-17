<script setup>
import { computed, onMounted, ref } from "vue";
import { useRoute } from "vue-router";
import { api, TYPES, DOMAINS } from "../api.js";

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
    const params = new URLSearchParams({ q: searchQuery.value.trim(), size: 12 });
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
    saved.value = "Deck enregistré.";
    setTimeout(() => (saved.value = ""), 2500);
  } catch (e) {
    error.value = e.message;
  }
}

onMounted(load);
</script>

<template>
  <section>
    <div class="wrap" v-if="deck">
      <p style="margin-bottom:18px"><RouterLink to="/decks">← Mes decks</RouterLink></p>

      <div class="toolbar">
        <input type="text" v-model="deck.name" style="max-width:340px; font-size:1.1rem" aria-label="Nom du deck" />
        <select v-model="deck.format" style="max-width:170px" aria-label="Format">
          <option value="tournament">Mode tournoi</option>
          <option value="free">Mode libre</option>
        </select>
        <label style="display:flex; gap:8px; align-items:center; font-size:.88rem">
          <input type="checkbox" v-model="deck.is_public" style="width:auto" /> Public
        </label>
        <button class="btn btn-gold" @click="save">Enregistrer</button>
        <span v-if="saved" class="success">{{ saved }}</span>
        <span v-if="error" class="error">{{ error }}</span>
      </div>
      <p v-if="deck.moderation_status === 'pending'" class="error" style="margin-bottom:14px">
        Contenu en attente de modération : ce deck n'est pas visible publiquement.
      </p>

      <div class="cols-2">
        <div>
          <div class="panel">
            <h3 style="margin-bottom:10px">Liste ({{ deck.card_count }} cartes)</h3>
            <div class="deck-zone" v-for="zone in ZONES" :key="zone.key">
              <h4>{{ zone.label }} — {{ grouped[zone.key].reduce((total, entry) => total + entry.qty, 0) }}</h4>
              <div class="deck-line" v-for="entry in grouped[zone.key]" :key="entry.card.id"
                   :style="{ '--chip': DOMAINS[entry.card.domains?.[0]]?.color }">
                <span class="qty">{{ entry.qty }}×</span>
                <RouterLink :to="`/cartes/${entry.card.id}`">{{ entry.card.name }}</RouterLink>
                <small>{{ entry.card.riftbound_id.toUpperCase() }}</small>
                <button class="btn btn-ghost btn-sm" @click="setQty(entry.card.id, 1)" aria-label="Ajouter">+</button>
                <button class="btn btn-ghost btn-sm" @click="setQty(entry.card.id, -1)" aria-label="Retirer">−</button>
              </div>
              <p v-if="!grouped[zone.key].length" class="muted" style="font-size:.8rem">Vide</p>
            </div>
          </div>

          <div class="panel" style="margin-top:20px">
            <h3 style="margin-bottom:12px">
              Validation {{ deck.format === "tournament" ? "(règles officielles)" : "(indicative — mode libre)" }}
            </h3>
            <ul class="validator">
              <li v-for="checkItem in deck.checks" :key="checkItem.rule" :class="checkItem.ok ? 'v-ok' : 'v-ko'">
                {{ checkItem.message }}
              </li>
            </ul>
            <p class="muted" style="font-size:.78rem; margin-top:10px">
              Les contrôles sont recalculés à chaque enregistrement.
            </p>
          </div>
        </div>

        <div class="panel">
          <h3 style="margin-bottom:12px">Ajouter des cartes</h3>
          <label class="search" style="margin-bottom:14px">
            🔍 <input type="search" v-model="searchQuery" @input="onSearch" placeholder="Rechercher une carte…" aria-label="Rechercher une carte à ajouter" />
          </label>
          <div class="deck-line" v-for="card in searchResults" :key="card.id"
               :style="{ '--chip': DOMAINS[card.domains?.[0]]?.color }">
            <span class="muted" style="font-size:.72rem; min-width:88px">{{ TYPES[card.type] || card.type }}</span>
            <span>{{ card.name }}</span>
            <small>{{ card.riftbound_id.toUpperCase() }}</small>
            <button class="btn btn-gold btn-sm" @click="setQty(card.id, 1, card)">+ Ajouter</button>
          </div>
          <p v-if="searchQuery.length >= 2 && !searchResults.length" class="muted" style="font-size:.84rem">Aucun résultat.</p>
          <textarea v-model="deck.description" placeholder="Description du deck (plan de jeu, conseils…)"
                    style="margin-top:16px" aria-label="Description du deck"></textarea>
        </div>
      </div>
    </div>
    <div class="wrap" v-else><p v-if="error" class="error">{{ error }}</p></div>
  </section>
</template>
