<script setup>
import { onMounted, ref } from "vue"
import { useRouter } from "vue-router"
import { api, cardThumb } from "../api.js"

const router = useRouter()
const decks = ref([])
const error = ref("")
const newName = ref("")

async function load() {
  try {
    decks.value = await api("/api/decks/mine")
  } catch (e) {
    error.value = e.message
  }
}

async function createDeck() {
  if (!newName.value.trim()) return
  try {
    const deck = await api("/api/decks", {
      method: "POST",
      body: { name: newName.value.trim(), description: "", format: "tournament", is_public: false, cards: [] }
    })
    router.push(`/decks/${deck.id}`)
  } catch (e) {
    error.value = e.message
  }
}

async function removeDeck(deck) {
  if (!confirm(`Supprimer « ${deck.name} » ?`)) return
  await api(`/api/decks/${deck.id}`, { method: "DELETE" })
  await load()
}

const preview = (deck) => deck.cards.slice(0, 6).map((entry) => entry.card)
const okCount = (deck) => deck.checks.filter((c) => c.ok).length

onMounted(load)
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Deck builder</p>
      <h2>Mes decks</h2>
      <p class="lead">Créez, testez, publiez. La validation tournoi vous suit à chaque carte.</p>
    </div>
  </div>

  <section style="padding-top: 40px">
    <div class="wrap">
      <div class="toolbar">
        <input
          type="text"
          v-model="newName"
          placeholder="Nom du nouveau deck…"
          style="max-width: 320px"
          aria-label="Nom du nouveau deck"
          @keyup.enter="createDeck"
        />
        <button class="btn btn-gold" @click="createDeck">Créer</button>
      </div>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="panel" v-for="(deck, i) in decks" :key="deck.id" v-reveal="i" style="margin-bottom: 22px">
        <div style="display: flex; gap: 18px; align-items: center; flex-wrap: wrap">
          <div style="flex: 1; min-width: 240px">
            <h3>
              <RouterLink :to="`/decks/${deck.id}`">{{ deck.name }}</RouterLink>
            </h3>
            <p class="muted mono" style="font-size: 0.74rem; margin-top: 4px">
              {{ deck.card_count }} cartes · {{ deck.format === "tournament" ? "tournoi" : "libre" }} · validation
              {{ okCount(deck) }}/{{ deck.checks.length }} · {{ deck.is_public ? "public" : "privé" }}
              <span v-if="deck.moderation_status === 'pending'" style="color: var(--order)"> · en modération</span>
            </p>
            <div class="deck-preview" v-if="deck.cards.length">
              <img
                v-for="card in preview(deck)"
                :key="card.id"
                :src="cardThumb(card.image_url, 140)"
                :alt="''"
                loading="lazy"
                decoding="async"
              />
            </div>
          </div>
          <span class="chip" style="--chip: var(--chaos)">♥ {{ deck.likes }}</span>
          <RouterLink class="btn btn-ghost btn-sm" :to="`/decks/${deck.id}`">Ouvrir</RouterLink>
          <button class="btn btn-ghost btn-sm" @click="removeDeck(deck)">Supprimer</button>
        </div>
      </div>
      <p v-if="!decks.length" class="muted">
        Pas encore de deck. Donnez-lui un nom ci-dessus, le reste se passe dans l'éditeur.
      </p>
    </div>
  </section>
</template>
