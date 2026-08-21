<script setup>
import { nextTick, onMounted, ref } from "vue"
import { useRouter } from "vue-router"
import { api } from "../api.js"
import { BANNERS } from "../banners.js"
import DeckBox from "../components/DeckBox.vue"
import ModalDialog from "../components/ModalDialog.vue"
import PageBanner from "../components/PageBanner.vue"

const router = useRouter()
const decks = ref([])
const error = ref("")

const showCreate = ref(false)
const creating = ref(false)
const generating = ref(false)
const createError = ref("")
const pendingDelete = ref(null)
const deleting = ref(false)
const deleteError = ref("")
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

function askRemove(deck) {
  pendingDelete.value = deck
  deleteError.value = ""
}

function cancelRemove() {
  if (deleting.value) return
  pendingDelete.value = null
  deleteError.value = ""
}

async function confirmRemove() {
  const deck = pendingDelete.value
  if (!deck || deleting.value) return
  deleting.value = true
  deleteError.value = ""
  try {
    await api(`/api/decks/${deck.id}`, { method: "DELETE" })
    pendingDelete.value = null
    await load()
  } catch (e) {
    deleteError.value = e.message
  } finally {
    deleting.value = false
  }
}

onMounted(load)
</script>

<template>
  <PageBanner :art="BANNERS.decks" eyebrow="Deck builder" title="Mes decks">
    Construisez vos decks, vérifiez les règles de tournoi et listez les cartes qui vous manquent.
  </PageBanner>

  <section style="padding-top: 40px">
    <div class="wrap">
      <div class="toolbar">
        <button class="btn btn-gold" @click="openCreate">+ Nouveau deck</button>
      </div>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="deck-boxes">
        <DeckBox
          v-for="(deck, i) in decks"
          :key="deck.id"
          v-reveal="i"
          v-tilt
          :deck="deck"
          :to="`/decks/${deck.id}`"
          @remove="askRemove"
        />
      </div>
      <p v-if="!decks.length" class="muted">
        Aucun deck pour l'instant — cliquez sur « Nouveau deck », le reste se passe dans l'éditeur.
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
          <option value="tournament">Légal — règles officielles vérifiées</option>
          <option value="free">Illégal — format libre, non officiel</option>
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

  <ModalDialog v-if="pendingDelete" title="Supprimer le deck" @close="cancelRemove">
    <p>
      Le deck <strong>{{ pendingDelete.name }}</strong> sera supprimé pour de bon — impossible de le récupérer ensuite.
    </p>
    <p v-if="deleteError" class="error">{{ deleteError }}</p>
    <div class="modal-actions">
      <button type="button" class="btn btn-ghost" :disabled="deleting" @click="cancelRemove">Annuler</button>
      <button type="button" class="btn btn-danger" :disabled="deleting" @click="confirmRemove">
        {{ deleting ? "Suppression…" : "Supprimer" }}
      </button>
    </div>
  </ModalDialog>
</template>
