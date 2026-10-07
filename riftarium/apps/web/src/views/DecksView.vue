<script setup>
import { computed, nextTick, onMounted, ref } from "vue"
import { useRouter } from "vue-router"
import { api } from "../api.js"
import DeckCard from "../decks/DeckCard.vue"
import { usePlayStats } from "../composables/usePlayStats.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"
import RiftModal from "../ui/RiftModal.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

const router = useRouter()
/* Un seul GET /api/play/stats pour toute la session : chaque fiche y lit son W/L. */
const playStats = usePlayStats()
const decks = ref([])
const error = ref("")
/* Premier chargement (ou « Réessayer ») : un rechargement après suppression garde la grille. */
const loading = ref(true)

const FORMATS = [
  { value: "tournament", label: "Légal", title: "Règles officielles vérifiées" },
  { value: "free", label: "Illégal", title: "Format libre, non officiel" }
]

const showCreate = ref(false)
const creating = ref(false)
const generating = ref(false)
const createError = ref("")
const pendingDelete = ref(null)
const deleting = ref(false)
const deleteError = ref("")
const nameInput = ref(null)
const draft = ref({ name: "", description: "", format: "tournament", is_public: false })
const formatNote = computed(() => FORMATS.find((f) => f.value === draft.value.format)?.title || "")

async function load() {
  error.value = ""
  try {
    decks.value = await api("/api/decks/mine")
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

function retry() {
  loading.value = true
  load()
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

/* La modale ne se ferme pas sous une création en cours (Échap, clic sur le fond) :
   la requête est partie, la navigation vers l'éditeur suivra. */
function closeCreate() {
  if (creating.value || generating.value) return
  showCreate.value = false
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
  <div class="wrap cards-wrap mesdecks">
    <header class="mesdecks-head">
      <h1 class="mesdecks-title">Mes decks</h1>
      <p v-if="!loading && !error" class="mesdecks-count">{{ decks.length }} deck(s)</p>
      <RiftButton class="mesdecks-new" variant="primary" @click="openCreate">Nouveau deck</RiftButton>
    </header>

    <div v-if="loading" class="mesdecks-grid">
      <RiftSkeleton v-for="n in 6" :key="n" class="mesdecks-skeleton" block />
    </div>

    <template v-else>
      <div v-if="error" class="mesdecks-fail">
        <p class="mesdecks-error" role="alert">{{ error }}</p>
        <RiftButton variant="secondary" @click="retry">Réessayer</RiftButton>
      </div>

      <div v-if="decks.length" class="mesdecks-grid">
        <DeckCard
          v-for="deck in decks"
          :key="deck.id"
          :deck="deck"
          :record="playStats.byDeck[deck.id] || null"
          :to="`/decks/${deck.id}`"
          @remove="askRemove"
        />
      </div>
      <!-- Un échec de chargement n'est pas une collection vide : un seul message à la fois. -->
      <RiftEmpty
        v-else-if="!error"
        title="Forgez votre premier deck"
        text="Partez de zéro ou d'un deck d'exemple, construit avec votre collection ou à compléter."
      >
        <RiftButton variant="primary" @click="openCreate">Nouveau deck</RiftButton>
        <RiftButton variant="secondary" :disabled="generating" @click="createExample('owned')">
          Exemple avec ma collection
        </RiftButton>
        <RiftButton variant="secondary" :disabled="generating" @click="createExample('discover')">
          Exemple à compléter
        </RiftButton>
      </RiftEmpty>
    </template>
  </div>

  <RiftModal v-if="showCreate" title="Nouveau deck" @close="closeCreate">
    <form class="mesdecks-form" @submit.prevent="createDeck">
      <RiftField
        ref="nameInput"
        v-model="draft.name"
        label="Nom du deck"
        maxlength="80"
        placeholder="Fureur de Noxus…"
        required
      />
      <div class="mesdecks-format">
        <RiftChoice v-model="draft.format" label="Format" :options="FORMATS" />
        <p class="mesdecks-format-note">{{ formatNote }}</p>
      </div>
      <label class="mesdecks-label">
        <span class="mesdecks-label-text">Description (optionnel)</span>
        <textarea
          v-model="draft.description"
          class="mesdecks-textarea"
          maxlength="2000"
          placeholder="Plan de jeu, forces, faiblesses…"
        ></textarea>
      </label>
      <div>
        <RiftChip
          label="Rendre ce deck public"
          :selected="draft.is_public"
          @toggle="draft.is_public = !draft.is_public"
        />
      </div>
      <p v-if="createError" class="mesdecks-error" role="alert">{{ createError }}</p>
      <div class="mesdecks-actions">
        <RiftButton variant="ghost" :disabled="creating || generating" @click="closeCreate">Annuler</RiftButton>
        <RiftButton type="submit" variant="primary" :disabled="!draft.name.trim() || creating">
          {{ creating ? "Création…" : "Créer et ouvrir l'éditeur" }}
        </RiftButton>
      </div>
    </form>
    <div class="mesdecks-sep">ou partez d'un deck d'exemple</div>
    <div class="mesdecks-examples">
      <RiftButton variant="secondary" :disabled="generating" @click="createExample('owned')">
        Avec ma collection
      </RiftButton>
      <RiftButton variant="secondary" :disabled="generating" @click="createExample('discover')">
        À compléter (liste d'achats)
      </RiftButton>
    </div>
    <p v-if="generating" class="mesdecks-hint" role="status">Génération du deck…</p>
  </RiftModal>

  <RiftModal v-if="pendingDelete" title="Supprimer le deck" @close="cancelRemove">
    <p>
      Le deck <strong>{{ pendingDelete.name }}</strong> sera supprimé pour de bon — impossible de le récupérer ensuite.
    </p>
    <p v-if="deleteError" class="mesdecks-error" role="alert">{{ deleteError }}</p>
    <div class="mesdecks-actions">
      <RiftButton variant="ghost" :disabled="deleting" @click="cancelRemove">Annuler</RiftButton>
      <RiftButton variant="primary" :disabled="deleting" @click="confirmRemove">
        {{ deleting ? "Suppression…" : "Supprimer" }}
      </RiftButton>
    </div>
  </RiftModal>
</template>

<style scoped>
.mesdecks {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
.mesdecks-head {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: var(--space-2) var(--space-4);
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.mesdecks-title {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.mesdecks-count {
  margin: 0;
  font-family: var(--font-label);
  letter-spacing: 0.08em;
  color: var(--ink-muted);
}
.mesdecks-new {
  margin-left: auto;
  align-self: center;
}
.mesdecks-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: var(--space-4);
}
@media (max-width: 560px) {
  .mesdecks-grid {
    grid-template-columns: repeat(2, minmax(150px, 1fr));
  }
}
.mesdecks-skeleton :deep(.rift-skeleton-block) {
  height: auto;
  aspect-ratio: 5 / 7;
}
.mesdecks-fail {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.mesdecks-error {
  margin: 0;
  color: var(--blood-text);
}
.mesdecks-form {
  display: grid;
  gap: var(--space-4);
}
.mesdecks-format {
  display: grid;
  gap: var(--space-2);
}
.mesdecks-format-note {
  margin: 0;
  font-size: 13px;
  color: var(--ink-muted);
}
.mesdecks-label {
  display: grid;
  gap: var(--space-1);
}
.mesdecks-label-text {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
/* main.css style `textarea` globalement : on reprend le champ de la Forge. */
.mesdecks-textarea {
  min-height: 96px;
  padding: var(--space-2) var(--space-3);
  resize: vertical;
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  border-radius: 0;
  color: var(--ink);
  font: inherit;
  box-shadow: none;
}
.mesdecks-textarea:focus {
  outline: none;
  box-shadow: none;
  border-color: var(--bronze-light);
}
.mesdecks-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: var(--space-2);
  margin-top: var(--space-4);
}
.mesdecks-form .mesdecks-actions {
  margin-top: 0;
}
.mesdecks-sep {
  margin: var(--space-4) 0 var(--space-3);
  text-align: center;
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.mesdecks-examples {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--space-2);
}
.mesdecks-hint {
  margin: var(--space-3) 0 0;
  color: var(--ink-muted);
}
</style>
