<script setup>
import "./console.css"
import { reactive, watch } from "vue"
import { api } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"
import RiftModal from "../ui/RiftModal.vue"
import { buildQuery, formatDate, moderationColor, moderationLabel, usePagedList, useRowAction } from "./useAdmin.js"

const DECK_STATUSES = [
  { value: "pending", label: "En attente" },
  { value: "published", label: "Publiés" },
  { value: "rejected", label: "Rejetés" },
  { value: "", label: "Tous" }
]

const {
  state: decks,
  load: loadDecks,
  schedule: scheduleDecks,
  pageCount
} = usePagedList((s) => `/api/admin/decks?${buildQuery({ status: s.status, q: s.q.trim(), page: s.page })}`, {
  status: "pending",
  q: ""
})
const { busyKey, rowError, run } = useRowAction()

function setDeckStatus(status) {
  if (decks.status === status) return
  decks.status = status
  /* La remise à la page 1 réveille le watch : on passe par le même minuteur que
     lui (`scheduleDecks`) pour ne déclencher qu'un seul chargement, pas deux. */
  decks.page = 1
  scheduleDecks()
}

watch(
  () => decks.q,
  () => {
    decks.page = 1
    scheduleDecks()
  }
)
watch(() => decks.page, scheduleDecks)

/* Chaque activation de l'onglet remonte le composant : la file de modération reste fraîche. */
loadDecks()

/* En échec, l'erreur s'affiche sur la ligne et la liste n'est pas rechargée : le statut reste. */
function moderateDeck(deck, status) {
  run(
    `deck:${deck.id}`,
    () => api(`/api/admin/decks/${deck.id}/moderation`, { method: "POST", body: { status } }),
    loadDecks
  )
}

/* --- Modale de suppression d'un deck --- */
const deckRemoval = reactive({ deck: null, busy: false, error: "" })

function openDeckRemoval(deck) {
  deckRemoval.deck = deck
  deckRemoval.error = ""
}

async function submitDeckRemoval() {
  if (deckRemoval.busy || !deckRemoval.deck) return
  deckRemoval.busy = true
  deckRemoval.error = ""
  try {
    await api(`/api/admin/decks/${deckRemoval.deck.id}`, { method: "DELETE" })
    deckRemoval.deck = null
    await loadDecks()
  } catch (e) {
    deckRemoval.error = e.message
  } finally {
    deckRemoval.busy = false
  }
}
</script>

<template>
  <div>
    <div class="console-toolbar">
      <div class="console-filters" role="group" aria-label="Statut de modération">
        <RiftChip
          v-for="status in DECK_STATUSES"
          :key="status.value"
          :label="status.label"
          :selected="decks.status === status.value"
          @toggle="setDeckStatus(status.value)"
        />
      </div>
      <RiftField
        v-model="decks.q"
        class="console-search"
        label="Rechercher un deck"
        hide-label
        search
        placeholder="Nom du deck…"
        inputmode="search"
        enterkeyhint="search"
        autocapitalize="off"
        autocorrect="off"
        spellcheck="false"
      />
      <span class="console-mono console-count" aria-live="polite">
        {{ decks.total }} deck(s) <span v-if="decks.loading">— chargement…</span>
      </span>
    </div>
    <p v-if="decks.error" class="console-error" role="alert">{{ decks.error }}</p>

    <table v-if="decks.items.length" class="console-table">
      <thead>
        <tr>
          <th scope="col">Deck</th>
          <th scope="col">Statut</th>
          <th scope="col">Activité</th>
          <th scope="col">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="deck in decks.items" :key="deck.id" class="console-row">
          <td class="console-id-cell" data-label="Deck">
            <div class="console-id">
              <RouterLink :to="`/decks/${deck.id}`" class="console-link console-id-name console-deck-name">
                {{ deck.name }}
              </RouterLink>
              <span class="console-mono">par {{ deck.owner }}</span>
              <span class="console-mono">mis à jour le {{ formatDate(deck.updated_at) }}</span>
            </div>
          </td>
          <td data-label="Statut">
            <div class="console-chips">
              <RiftChip
                static
                selected
                :label="moderationLabel(deck.moderation_status)"
                :color="moderationColor(deck.moderation_status)"
              />
              <RiftChip v-if="deck.is_public" static label="Public" />
            </div>
          </td>
          <td class="console-mono" data-label="Activité">{{ deck.likes_count }} likes · {{ deck.views_count }} vues</td>
          <td class="console-actions-cell" data-label="Actions">
            <div class="console-actions">
              <RiftButton
                v-if="deck.moderation_status !== 'published' && deck.moderation_status !== 'approved'"
                variant="secondary"
                size="sm"
                :disabled="Boolean(busyKey)"
                @click="moderateDeck(deck, 'approved')"
              >
                Approuver
              </RiftButton>
              <RiftButton
                v-if="deck.moderation_status !== 'rejected'"
                variant="ghost"
                size="sm"
                :disabled="Boolean(busyKey)"
                @click="moderateDeck(deck, 'rejected')"
              >
                Rejeter
              </RiftButton>
              <RiftButton
                variant="ghost"
                size="sm"
                class="console-danger"
                :disabled="Boolean(busyKey)"
                @click="openDeckRemoval(deck)"
              >
                Supprimer
              </RiftButton>
            </div>
            <p v-if="rowError.key === `deck:${deck.id}`" class="console-row-error" role="alert">
              {{ rowError.message }}
            </p>
          </td>
        </tr>
      </tbody>
    </table>
    <RiftEmpty
      v-if="!decks.loading && !decks.items.length && !decks.error"
      :title="decks.status === 'pending' ? 'Aucun deck en attente de modération.' : 'Aucun deck ne correspond.'"
    />

    <nav v-if="pageCount > 1" class="console-pager" aria-label="Pages des decks">
      <RiftButton variant="secondary" size="sm" :disabled="decks.page <= 1" @click="decks.page--">
        ← Précédent
      </RiftButton>
      <span class="console-mono">page {{ decks.page }} / {{ pageCount }}</span>
      <RiftButton variant="secondary" size="sm" :disabled="decks.page >= pageCount" @click="decks.page++">
        Suivant →
      </RiftButton>
    </nav>

    <RiftModal v-if="deckRemoval.deck" title="Supprimer le deck" @close="deckRemoval.deck = null">
      <div class="console-form">
        <p>
          Le deck <strong>{{ deckRemoval.deck.name }}</strong> de {{ deckRemoval.deck.owner }} sera supprimé
          définitivement.
        </p>
        <p v-if="deckRemoval.error" class="console-error" role="alert">{{ deckRemoval.error }}</p>
        <div class="console-modal-actions">
          <RiftButton variant="ghost" :disabled="deckRemoval.busy" @click="deckRemoval.deck = null">Annuler</RiftButton>
          <RiftButton :disabled="deckRemoval.busy" @click="submitDeckRemoval">
            {{ deckRemoval.busy ? "Suppression…" : "Supprimer" }}
          </RiftButton>
        </div>
      </div>
    </RiftModal>
  </div>
</template>
