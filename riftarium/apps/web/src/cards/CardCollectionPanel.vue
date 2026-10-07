<script setup>
import { computed, ref, watch } from "vue"
import { api, session } from "../api.js"
import { conditionOptions, defaultsLabel, langOptions } from "../collection/collectionDefaults.js"
import { useOwnedCopies } from "../collection/useOwnedCopies.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftStepper from "../ui/RiftStepper.vue"

/* Panneau « collection et wishlist » de la fiche carte : compteur rapide, lots ajustables,
   ajout précis, bascule wishlist. Il ne modifie pas la carte : il émet `change({ id, ...patch })`
   avec `owned_qty` / `wished_qty` et l'id de la carte concernée (le parent ignore un patch
   qui ne vise plus la carte affichée), c'est le parent qui tient la fiche. */
const props = defineProps({
  card: { type: Object, required: true }
})
const emit = defineEmits(["change"])

const owned = useOwnedCopies(() => props.card.id, { onChange: (patch) => emit("change", patch) })
const { entries, total, busy, defaults, setDefaults } = owned

const saved = ref("")
const wishError = ref("")
/* Les lots ne conditionnent pas la fiche : l'échec de leur chargement reste silencieux,
   seules les erreurs de mutation (après une action de l'utilisateur) s'affichent. */
const acted = ref(false)
const error = computed(() => wishError.value || (acted.value ? owned.error.value : ""))

watch(
  () => props.card.id,
  () => {
    saved.value = ""
    wishError.value = ""
    acted.value = false
  }
)

const preference = computed(() => defaultsLabel(defaults))
const editingPref = ref(false)

const lotName = (entry) => defaultsLabel(entry)
const detailTitle = computed(() => {
  const count = entries.value.length
  return count ? `Détail des exemplaires (${count} ${count > 1 ? "lots" : "lot"})` : "Détail des exemplaires"
})

/* Lance une action du composable ; le message n'est posé que si elle est passée. */
async function run(action, message) {
  acted.value = true
  saved.value = ""
  wishError.value = ""
  const done = await action()
  if (done) saved.value = message
  return done
}

const increment = () => run(owned.increment, "Exemplaire ajouté.")
const decrement = () => run(owned.decrement, "Exemplaire retiré.")
/* Ajustement d'un lot de ±1 ; à 0, l'API supprime le lot. Le reclassement (état, langue) d'un lot
   n'existe pas ici : retrait puis ajout précis, ou l'Inventaire pour le reclassement de masse. */
const setLotQty = (entry, qty) =>
  run(() => owned.setLotQty(entry.id, qty), qty ? "Quantité du lot mise à jour." : "Lot retiré.")

/* Ajout précis : la quantité est locale (1 à 999) ; après un ajout réussi elle revient à 1,
   les choix d'état et de langue restent. */
const draft = ref({ qty: 1, condition: defaults.condition, lang: defaults.lang })
async function addLot() {
  const { qty, condition, lang } = draft.value
  if (await run(() => owned.addLot({ qty, condition, lang }), "Lot ajouté.")) draft.value.qty = 1
}

/* Wishlist : un seul clic bascule « je la veux » (qty 1) / retrait complet.
   La quantité fine se règle ensuite sur la page Ma wishlist. */
const wished = computed(() => (props.card.wished_qty ?? 0) > 0)
const wishBusy = ref(false)

async function toggleWish() {
  if (wishBusy.value) return
  const cardId = props.card.id
  wishBusy.value = true
  wishError.value = ""
  try {
    if (wished.value) {
      await api(`/api/wishlist/${cardId}`, { method: "DELETE" })
      emit("change", { id: cardId, wished_qty: 0 })
    } else {
      await api(`/api/wishlist/${cardId}`, { method: "PUT", body: { qty: 1 } })
      emit("change", { id: cardId, wished_qty: 1 })
    }
  } catch (e) {
    wishError.value = e.message
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

      <div class="panel-count">
        <h2 class="panel-title">Dans ma collection</h2>
        <RiftStepper
          :value="total"
          :busy="busy"
          :label="card.name ?? 'cette carte'"
          @increment="increment"
          @decrement="decrement"
        />
      </div>

      <div class="panel-pref">
        <p class="panel-pref-line">
          Ajouté en {{ preference }} ·
          <button
            type="button"
            class="panel-pref-change"
            :aria-expanded="editingPref"
            @click="editingPref = !editingPref"
          >
            changer
          </button>
        </p>
        <div v-if="editingPref" class="panel-pref-edit">
          <RiftChoice
            label="État par défaut"
            :model-value="defaults.condition"
            :options="conditionOptions"
            @update:model-value="setDefaults({ condition: $event })"
          />
          <RiftChoice
            label="Langue par défaut"
            :model-value="defaults.lang"
            :options="langOptions"
            @update:model-value="setDefaults({ lang: $event })"
          />
        </div>
      </div>

      <details class="panel-detail">
        <summary class="panel-detail-title">
          <span class="panel-detail-chevron" aria-hidden="true"></span>{{ detailTitle }}
        </summary>
        <ul v-if="entries.length" class="panel-lots">
          <li v-for="entry in entries" :key="entry.id" class="panel-lot">
            <span class="panel-lot-name">{{ lotName(entry) }}</span>
            <RiftStepper
              :value="entry.qty"
              :busy="busy"
              :label="`ce lot ${lotName(entry)}`"
              @increment="setLotQty(entry, entry.qty + 1)"
              @decrement="setLotQty(entry, entry.qty - 1)"
            />
          </li>
        </ul>
        <div class="panel-add">
          <p class="panel-add-title">Ajouter un lot précis</p>
          <RiftStepper
            :value="draft.qty"
            :min="1"
            :max="999"
            label="ce lot"
            @increment="draft.qty += 1"
            @decrement="draft.qty -= 1"
          />
          <RiftChoice v-model="draft.condition" label="État" :options="conditionOptions" />
          <RiftChoice v-model="draft.lang" label="Langue" :options="langOptions" />
          <RiftButton class="panel-add-submit" variant="secondary" :disabled="busy" @click="addLot">
            Ajouter
          </RiftButton>
        </div>
      </details>

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
.panel-login {
  margin: 0;
  color: var(--ink-muted);
}
.panel-login a {
  color: var(--blood-text);
}
.panel-count {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}
.panel-title {
  margin: 0;
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink);
}
.panel-pref {
  display: grid;
}
.panel-detail {
  display: block;
}
.panel-add-submit {
  min-width: 44px;
}
.panel-pref-line {
  margin: 0;
  color: var(--ink-muted);
  font-size: 14px;
}
/* Bouton neutralisé localement : main.css stylise `button` globalement. */
.panel-pref-change {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  padding: 0 var(--space-1);
  border: 0;
  background: none;
  color: var(--bronze-light);
  font: inherit;
  text-decoration: underline;
  cursor: pointer;
}
.panel-pref-change:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.panel-pref-edit {
  display: grid;
  gap: var(--space-2);
  margin-top: var(--space-2);
}
.panel-detail-title {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  list-style: none;
  min-height: 44px;
  cursor: pointer;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.panel-detail-title::-webkit-details-marker {
  display: none;
}
.panel-detail-chevron {
  width: 8px;
  height: 8px;
  flex: none;
  border-right: 2px solid currentColor;
  border-bottom: 2px solid currentColor;
  transform: rotate(-45deg);
  transition: transform 0.15s ease;
}
.panel-detail[open] > .panel-detail-title .panel-detail-chevron {
  transform: rotate(45deg);
}
@media (prefers-reduced-motion: reduce) {
  .panel-detail-chevron {
    transition: none;
  }
}
/* Liste neutralisée localement : le navigateur pose puces et marges sur ul/li. */
.panel-lots {
  display: grid;
  gap: var(--space-2);
  margin: 0 0 var(--space-3);
  padding: 0;
  list-style: none;
}
.panel-lot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  min-height: 44px;
  margin: 0;
  padding: 0;
}
.panel-lot-name {
  color: var(--ink);
  font-size: 14px;
}
.panel-add {
  display: grid;
  justify-items: start;
  gap: var(--space-2);
}
.panel-add-title {
  margin: 0;
  color: var(--ink);
  font-size: 14px;
}
.panel-wish.on {
  border-color: var(--blood-text);
  color: var(--blood-text);
}
.panel-saved {
  margin: 0;
  color: var(--bronze-light);
}
.panel-error {
  margin: 0;
  color: var(--blood-text);
}
</style>
