<script setup>
import { nextTick, onMounted, ref } from "vue"
import { useRouter } from "vue-router"
import { api, cardThumb } from "../api.js"
import { DOMAIN_RUNE, RUNE_LABELS, glyphUrl } from "../cardText.js"
import ModalDialog from "../components/ModalDialog.vue"

const router = useRouter()
const decks = ref([])
const error = ref("")

const showCreate = ref(false)
const creating = ref(false)
const generating = ref(false)
const createError = ref("")
const nameInput = ref(null)
const draft = ref({ name: "", description: "", format: "tournament", is_public: false })

async function load() {
  try {
    decks.value = await api("/api/decks/mine")
  } catch (e) {
    error.value = e.message
  }
}

async function openCreate() {
  draft.value = { name: "", description: "", format: "tournament", is_public: false }
  createError.value = ""
  showCreate.value = true
  await nextTick()
  nameInput.value?.focus()
}

async function createDeck() {
  if (!draft.value.name.trim() || creating.value) return
  creating.value = true
  createError.value = ""
  try {
    const deck = await api("/api/decks", {
      method: "POST",
      body: { ...draft.value, name: draft.value.name.trim(), cards: [] }
    })
    router.push(`/decks/${deck.id}`)
  } catch (e) {
    createError.value = e.message
  } finally {
    creating.value = false
  }
}

async function createExample(mode) {
  if (generating.value) return
  generating.value = true
  createError.value = ""
  try {
    const deck = await api("/api/decks/example", { method: "POST", body: { mode } })
    router.push(`/decks/${deck.id}`)
  } catch (e) {
    createError.value = e.message
  } finally {
    generating.value = false
  }
}

async function removeDeck(deck) {
  if (!confirm(`Supprimer « ${deck.name} » ?`)) return
  await api(`/api/decks/${deck.id}`, { method: "DELETE" })
  await load()
}

const okCount = (deck) => deck.checks.filter((c) => c.ok).length

/* Boîte de deck : la légende en couverture, ses domaines en runes. */
const legendOf = (deck) => deck.cards.find((entry) => entry.card.type === "Legend")?.card || null

function runesOf(deck) {
  const legend = legendOf(deck)
  return (legend?.domains || [])
    .filter((domain) => domain !== "Colorless")
    .map((domain) => ({
      domain,
      label: RUNE_LABELS[DOMAIN_RUNE[domain]] || domain,
      src: glyphUrl(`rune_${DOMAIN_RUNE[domain]}`)
    }))
}

function coverStyle(deck) {
  const art = legendOf(deck)?.image_url || deck.cards[0]?.card.image_url
  return art ? { "--cover": `url(${cardThumb(art, 480)})` } : {}
}

onMounted(load)
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Deck builder</p>
      <h2>Mes decks</h2>
      <p class="lead">Construisez vos decks, vérifiez les règles de tournoi et listez les cartes qui vous manquent.</p>
    </div>
  </div>

  <section style="padding-top: 40px">
    <div class="wrap">
      <div class="toolbar">
        <button class="btn btn-gold" @click="openCreate">+ Nouveau deck</button>
      </div>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="deck-boxes">
        <article class="deck-box" v-for="(deck, i) in decks" :key="deck.id" v-reveal="i">
          <RouterLink
            class="deck-box-cover"
            :class="{ blank: !legendOf(deck) }"
            :to="`/decks/${deck.id}`"
            :style="coverStyle(deck)"
            :aria-label="`Ouvrir le deck ${deck.name}`"
          >
            <span v-if="!legendOf(deck)" class="deck-box-nolegend">Sans légende</span>
            <span class="deck-box-runes" v-if="runesOf(deck).length">
              <img
                v-for="rune in runesOf(deck)"
                :key="rune.domain"
                :src="rune.src"
                :alt="rune.label"
                :title="rune.label"
                width="24"
                height="24"
              />
            </span>
          </RouterLink>
          <div class="deck-box-plate">
            <h3>
              <RouterLink :to="`/decks/${deck.id}`">{{ deck.name }}</RouterLink>
            </h3>
            <p class="muted mono">
              {{ deck.card_count }} cartes · {{ deck.format === "tournament" ? "tournoi" : "libre" }} ·
              {{ okCount(deck) }}/{{ deck.checks.length }} règles · {{ deck.is_public ? "public" : "privé" }}
              <span v-if="deck.moderation_status === 'pending'" style="color: var(--order)"> · en modération</span>
            </p>
            <div class="deck-box-actions">
              <span class="chip" style="--chip: var(--chaos)">♥ {{ deck.likes }}</span>
              <RouterLink class="btn btn-ghost btn-sm" :to="`/decks/${deck.id}`">Ouvrir</RouterLink>
              <button class="btn btn-ghost btn-sm" @click="removeDeck(deck)">Supprimer</button>
            </div>
          </div>
        </article>
      </div>
      <p v-if="!decks.length" class="muted">
        Pas encore de deck. Cliquez sur « Nouveau deck », le reste se passe dans l'éditeur.
      </p>
    </div>
  </section>

  <ModalDialog v-if="showCreate" title="Nouveau deck" @close="showCreate = false">
    <form class="modal-form" @submit.prevent="createDeck">
      <label>
        Nom du deck
        <input
          ref="nameInput"
          type="text"
          v-model="draft.name"
          maxlength="80"
          placeholder="Fureur de Noxus…"
          required
        />
      </label>
      <label>
        Format
        <select v-model="draft.format">
          <option value="tournament">Mode tournoi — règles officielles vérifiées</option>
          <option value="free">Mode libre — aucune contrainte</option>
        </select>
      </label>
      <label>
        Description <span class="muted">(optionnel)</span>
        <textarea
          v-model="draft.description"
          maxlength="2000"
          placeholder="Plan de jeu, forces, faiblesses…"
        ></textarea>
      </label>
      <label class="switch"> <input type="checkbox" v-model="draft.is_public" /><i></i> Rendre ce deck public </label>
      <p v-if="createError" class="error">{{ createError }}</p>
      <div class="modal-actions">
        <button type="button" class="btn btn-ghost" @click="showCreate = false">Annuler</button>
        <button type="submit" class="btn btn-gold" :disabled="!draft.name.trim() || creating">
          {{ creating ? "Création…" : "Créer et ouvrir l'éditeur" }}
        </button>
      </div>
    </form>
    <div class="modal-sep">ou partez d'un deck d'exemple</div>
    <div class="example-actions">
      <button type="button" class="btn btn-ghost" :disabled="generating" @click="createExample('owned')">
        Avec ma collection
      </button>
      <button type="button" class="btn btn-ghost" :disabled="generating" @click="createExample('discover')">
        À compléter (liste d'achats)
      </button>
    </div>
    <p v-if="generating" class="muted" style="margin-top: 10px">Génération du deck…</p>
  </ModalDialog>
</template>
