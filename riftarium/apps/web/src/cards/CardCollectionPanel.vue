<script setup>
import { computed, reactive, ref, watch } from "vue"
import { api, session, CONDITIONS, LANGS } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"

/* Panneau « collection et wishlist » de la fiche carte : lots possédés, ajout,
   bascule wishlist. Il ne modifie pas la carte : il émet `change(patch)` avec
   `owned_qty` / `wished_qty`, c'est le parent qui tient la fiche. */
const props = defineProps({
  card: { type: Object, required: true }
})
const emit = defineEmits(["change"])

const entries = ref([]) // lots possédés : [{ id, qty, condition, lang }]
const draft = reactive({ qty: 1, condition: "NM", lang: "EN" })
const busy = ref(false)
const saved = ref("")
const error = ref("")

const totalOwned = computed(() => entries.value.reduce((total, entry) => total + entry.qty, 0))

/* Jeton de séquence : un changement de carte rapproché lance deux chargements ;
   seul le dernier a le droit d'écrire dans l'état. */
let seq = 0

watch(
  () => props.card.id,
  async (id) => {
    const mine = ++seq
    entries.value = []
    saved.value = ""
    error.value = ""
    if (!session.token || !id) return
    /* Les lots ne conditionnent pas la fiche : un échec laisse simplement la liste vide. */
    try {
      const owned = await api(`/api/collection/${id}`)
      if (mine !== seq) return
      entries.value = owned.entries
    } catch {
      /* collection indisponible : le panneau reste utilisable, sans ses lots */
    }
  },
  { immediate: true }
)

/* Un lot se compte en entiers : `v-model.number` renvoie "" sur un champ vidé
   (et un décimal si l'on tape « 1,5 »), ce qu'il ne faut pas envoyer à l'API. */
function validQty(value, min = 0) {
  return Number.isInteger(value) && value >= min && value <= 999
}

function applyState(state, message) {
  entries.value = state.entries
  emit("change", { owned_qty: state.total_qty })
  saved.value = message
}

/* Retourne vrai si la mutation est passée : l'appelant ne réinitialise sa saisie
   qu'à cette condition (une erreur laissait auparavant le formulaire vidé). */
async function mutate(request, message) {
  if (busy.value) return false
  const cardId = props.card.id
  busy.value = true
  saved.value = ""
  error.value = ""
  try {
    const state = await request()
    /* Réponse tardive : la fiche a changé de carte entre-temps, on l'oublie. */
    if (props.card.id !== cardId) return false
    applyState(state, message)
    return true
  } catch (e) {
    error.value = e.message
    return false
  } finally {
    busy.value = false
  }
}

async function addEntry() {
  if (!validQty(draft.qty, 1)) return
  const done = await mutate(
    () =>
      api(`/api/collection/${props.card.id}/entries`, {
        method: "POST",
        body: { qty: draft.qty, condition: draft.condition, lang: draft.lang }
      }),
    "Lot ajouté."
  )
  if (done) draft.qty = 1
}

function saveEntry(entry) {
  if (!validQty(entry.qty)) return
  mutate(
    () =>
      api(`/api/collection/entries/${entry.id}`, {
        method: "PATCH",
        body: { qty: entry.qty, condition: entry.condition, lang: entry.lang }
      }),
    "Lot mis à jour."
  )
}

function removeEntry(entry) {
  mutate(() => api(`/api/collection/entries/${entry.id}`, { method: "PATCH", body: { qty: 0 } }), "Lot retiré.")
}

/* Wishlist : un seul clic bascule « je la veux » (qty 1) / retrait complet.
   La quantité fine se règle ensuite sur la page Ma wishlist. */
const wished = computed(() => (props.card.wished_qty ?? 0) > 0)
const wishBusy = ref(false)

async function toggleWish() {
  if (wishBusy.value) return
  wishBusy.value = true
  error.value = ""
  try {
    if (wished.value) {
      await api(`/api/wishlist/${props.card.id}`, { method: "DELETE" })
      emit("change", { wished_qty: 0 })
    } else {
      await api(`/api/wishlist/${props.card.id}`, { method: "PUT", body: { qty: 1 } })
      emit("change", { wished_qty: 1 })
    }
  } catch (e) {
    error.value = e.message
  } finally {
    wishBusy.value = false
  }
}
</script>

<template>
  <section class="collection-panel" aria-label="Collection et wishlist">
    <p v-if="!session.token" class="panel-login">
      <RouterLink to="/connexion">Connectez-vous</RouterLink> pour suivre vos exemplaires et votre wishlist.
    </p>

    <template v-else>
      <RiftButton
        variant="secondary"
        class="panel-wish"
        :class="{ on: wished }"
        :aria-pressed="wished"
        :disabled="wishBusy"
        @click="toggleWish"
      >
        <Icon :name="wished ? 'heart' : 'heart-line'" :size="15" />
        {{ wished ? "Dans ma wishlist" : "Ajouter à la wishlist" }}
      </RiftButton>

      <h2 class="panel-title">
        Dans ma collection
        <span v-if="totalOwned" class="panel-total">— {{ totalOwned }} exemplaire(s)</span>
      </h2>

      <div v-for="entry in entries" :key="entry.id" class="panel-lot">
        <div class="panel-fields">
          <input
            type="number"
            inputmode="numeric"
            min="0"
            max="999"
            v-model.number="entry.qty"
            :aria-label="`Quantité du lot ${entry.condition} ${entry.lang}`"
          />
          <select v-model="entry.condition" aria-label="État du lot">
            <option v-for="(label, code) in CONDITIONS" :key="code" :value="code">{{ code }} · {{ label }}</option>
          </select>
          <select v-model="entry.lang" aria-label="Langue du lot">
            <option v-for="(label, code) in LANGS" :key="code" :value="code">{{ code }} · {{ label }}</option>
          </select>
        </div>
        <div class="panel-actions">
          <RiftButton size="sm" :disabled="busy || !validQty(entry.qty)" @click="saveEntry(entry)">
            Enregistrer
          </RiftButton>
          <RiftButton size="sm" variant="ghost" :disabled="busy" @click="removeEntry(entry)">Retirer</RiftButton>
        </div>
      </div>
      <p v-if="!entries.length" class="panel-empty">Aucun exemplaire pour l'instant.</p>

      <div class="panel-lot panel-add">
        <div class="panel-fields">
          <input
            type="number"
            inputmode="numeric"
            min="1"
            max="999"
            v-model.number="draft.qty"
            aria-label="Quantité à ajouter"
          />
          <select v-model="draft.condition" aria-label="État du nouveau lot">
            <option v-for="(label, code) in CONDITIONS" :key="code" :value="code">{{ code }} · {{ label }}</option>
          </select>
          <select v-model="draft.lang" aria-label="Langue du nouveau lot">
            <option v-for="(label, code) in LANGS" :key="code" :value="code">{{ code }} · {{ label }}</option>
          </select>
        </div>
        <div class="panel-actions">
          <RiftButton size="sm" variant="secondary" :disabled="busy || !validQty(draft.qty, 1)" @click="addEntry">
            + Ajouter un lot
          </RiftButton>
        </div>
      </div>

      <p v-if="saved" class="panel-saved" role="status">{{ saved }}</p>
      <p v-if="error" class="panel-error" role="alert">{{ error }}</p>
    </template>
  </section>
</template>

<style scoped>
.collection-panel {
  display: grid;
  gap: var(--space-3);
  padding: 0;
}
.panel-login,
.panel-empty {
  margin: 0;
  color: var(--ink-muted);
}
.panel-login a {
  color: var(--blood-text);
}
.panel-title {
  margin: var(--space-3) 0 0;
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink);
}
.panel-total {
  color: var(--ink-muted);
  text-transform: none;
  letter-spacing: 0;
}
/* Deux rangées : les champs d'abord, les actions dessous (la colonne de la fiche fait 400 px au plus). */
.panel-lot {
  display: grid;
  gap: var(--space-2);
}
.panel-fields {
  display: grid;
  grid-template-columns: 90px minmax(0, 1fr) minmax(0, 1fr);
  gap: var(--space-2);
  align-items: center;
}
.panel-lot input,
.panel-lot select {
  min-height: 40px;
  min-width: 0;
  padding: 0 var(--space-2);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  border-radius: 0;
  color: var(--ink);
  font-family: var(--font-body);
  font-size: 14px;
}
.panel-wish.on {
  border-color: var(--blood-text);
  color: var(--blood-text);
}
.panel-lot input:focus,
.panel-lot select:focus,
.panel-lot input:focus-visible,
.panel-lot select:focus-visible {
  box-shadow: none;
  border-color: var(--bronze-light);
  outline: 2px solid var(--bronze-light);
  outline-offset: 1px;
}
.panel-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: var(--space-2);
}
.panel-saved {
  margin: 0;
  color: var(--bronze-light);
}
.panel-error {
  margin: 0;
  color: var(--blood-text);
}
@media (max-width: 480px) {
  .panel-fields {
    grid-template-columns: 1fr;
  }
}
</style>
