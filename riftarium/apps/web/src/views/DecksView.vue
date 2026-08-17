<script setup>
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { api } from "../api.js";

const router = useRouter();
const decks = ref([]);
const error = ref("");
const newName = ref("");

async function load() {
  try {
    decks.value = await api("/api/decks/mine");
  } catch (e) {
    error.value = e.message;
  }
}

async function createDeck() {
  if (!newName.value.trim()) return;
  try {
    const deck = await api("/api/decks", {
      method: "POST",
      body: { name: newName.value.trim(), description: "", format: "tournament", is_public: false, cards: [] }
    });
    router.push(`/decks/${deck.id}`);
  } catch (e) {
    error.value = e.message;
  }
}

async function removeDeck(deck) {
  if (!confirm(`Supprimer le deck « ${deck.name} » ?`)) return;
  await api(`/api/decks/${deck.id}`, { method: "DELETE" });
  await load();
}

function okCount(deck) {
  return deck.checks.filter(c => c.ok).length;
}

onMounted(load);
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Deck builder</p>
      <h2>Mes decks</h2>
    </div>
  </div>
  <section>
    <div class="wrap">
      <div class="toolbar">
        <input type="text" v-model="newName" placeholder="Nom du nouveau deck…" style="max-width:320px"
               aria-label="Nom du nouveau deck" @keyup.enter="createDeck" />
        <button class="btn btn-gold" @click="createDeck">Créer un deck</button>
      </div>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="panel" v-for="deck in decks" :key="deck.id" style="margin-bottom:16px">
        <div style="display:flex; gap:14px; align-items:center; flex-wrap:wrap">
          <div style="flex:1">
            <h3><RouterLink :to="`/decks/${deck.id}`">{{ deck.name }}</RouterLink></h3>
            <p class="muted mono" style="font-size:.76rem">
              {{ deck.card_count }} cartes · {{ deck.format === "tournament" ? "mode tournoi" : "mode libre" }}
              · validation {{ okCount(deck) }}/{{ deck.checks.length }}
              · {{ deck.is_public ? "public" : "privé" }}
              <span v-if="deck.moderation_status === 'pending'" style="color:var(--order)"> · en attente de modération</span>
            </p>
          </div>
          <span class="chip" style="--chip:var(--chaos)">♥ {{ deck.likes }}</span>
          <RouterLink class="btn btn-ghost btn-sm" :to="`/decks/${deck.id}`">Modifier</RouterLink>
          <button class="btn btn-ghost btn-sm" @click="removeDeck(deck)">Supprimer</button>
        </div>
      </div>
      <p v-if="!decks.length" class="muted">Aucun deck pour l'instant — créez le premier ci-dessus.</p>
    </div>
  </section>
</template>
