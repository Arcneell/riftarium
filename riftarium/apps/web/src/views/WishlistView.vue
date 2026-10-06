<script setup>
import { computed, onMounted, ref } from "vue"
import { api } from "../api.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import CollectionStats from "../collection/CollectionStats.vue"
import CardTile from "../ui/CardTile.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

/* Wishlist : la liste complète tient en une page (pas de pagination côté API).
   Après chaque modification, on recharge la liste : total et valeur restent
   ceux du serveur, sans recalcul approximatif côté client. */
const list = ref({ total: 0, value_eur: null, items: [] })
const loading = ref(true)
const error = ref("")
const busyId = ref(null)

async function refresh() {
  try {
    list.value = await api("/api/wishlist")
    error.value = ""
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

/* Le stepper reste dans les clous : de 1 à 99 exemplaires souhaités. */
function clampQty(value) {
  const qty = Math.round(Number(value))
  if (Number.isNaN(qty)) return 1
  return Math.min(99, Math.max(1, qty))
}

async function setQty(item, value, input = null) {
  const qty = clampQty(value)
  /* Champ non contrôlé (`:value`) : quand le clamp retombe sur la quantité
     courante, Vue ne rend rien et la saisie invalide resterait affichée. */
  if (input) input.value = String(qty)
  if (busyId.value) return
  busyId.value = item.card.id
  error.value = ""
  try {
    /* Pas d'affectation locale de `item.qty` : `refresh()` reprend la liste du
       serveur juste après, elle serait écrasée aussitôt. */
    await api(`/api/wishlist/${item.card.id}`, { method: "PUT", body: { qty } })
    await refresh()
  } catch (e) {
    error.value = e.message
  } finally {
    busyId.value = null
  }
}

async function removeItem(item) {
  if (busyId.value) return
  busyId.value = item.card.id
  error.value = ""
  try {
    await api(`/api/wishlist/${item.card.id}`, { method: "DELETE" })
    await refresh()
  } catch (e) {
    error.value = e.message
  } finally {
    busyId.value = null
  }
}

onMounted(refresh)

const stats = computed(() => [
  { label: "Cartes souhaitées", value: list.value.total },
  { label: "Valeur estimée", value: formatEur(list.value.value_eur) || null, title: PRICE_NOTE }
])
</script>

<template>
  <div class="wrap cards-wrap souhait-page">
    <h1 class="souhait-title">Ma wishlist</h1>

    <CollectionStats :items="stats" />

    <p v-if="error" class="error">{{ error }}</p>

    <div v-if="loading" class="souhait-grid">
      <RiftSkeleton v-for="n in 6" :key="n" block />
    </div>

    <div v-else-if="list.items.length" class="souhait-grid">
      <div v-for="item in list.items" :key="item.card.id" class="souhait-cell">
        <CardTile :card="item.card" :preview="false" />
        <div class="souhait-controls">
          <div class="souhait-stepper" role="group" :aria-label="`Quantité souhaitée de ${item.card.name}`">
            <RiftButton
              variant="ghost"
              size="sm"
              :disabled="Boolean(busyId) || item.qty <= 1"
              aria-label="Un exemplaire de moins"
              @click="setQty(item, item.qty - 1)"
            >
              −
            </RiftButton>
            <input
              type="number"
              class="souhait-qty"
              inputmode="numeric"
              min="1"
              max="99"
              :value="item.qty"
              :aria-label="`Quantité souhaitée de ${item.card.name}`"
              :disabled="Boolean(busyId)"
              @change="setQty(item, $event.target.value, $event.target)"
            />
            <RiftButton
              variant="ghost"
              size="sm"
              :disabled="Boolean(busyId) || item.qty >= 99"
              aria-label="Un exemplaire de plus"
              @click="setQty(item, item.qty + 1)"
            >
              +
            </RiftButton>
          </div>
          <RiftButton
            variant="ghost"
            size="sm"
            class="souhait-remove"
            :aria-label="`Retirer ${item.card.name} de ma liste de souhaits`"
            :disabled="Boolean(busyId)"
            @click="removeItem(item)"
          >
            Retirer
          </RiftButton>
        </div>
      </div>
    </div>

    <RiftEmpty v-else-if="!error" title="Votre wishlist est vide" text="Le cœur sur la fiche d'une carte l'ajoute ici.">
      <RiftButton to="/cartes">Parcourir les cartes</RiftButton>
    </RiftEmpty>
  </div>
</template>

<style scoped>
.souhait-page {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.souhait-title {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.souhait-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: var(--space-4);
}
.souhait-grid :deep(.rift-skeleton-block) {
  height: auto;
  aspect-ratio: 0.716;
}
.souhait-cell {
  display: grid;
  gap: var(--space-2);
  align-content: start;
  min-width: 0;
}
.souhait-controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
}
.souhait-stepper {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
}
/* main.css donne width:100% et un halo de focus aux input : largeur explicite, halo coupé. */
.souhait-qty {
  width: 56px;
  min-height: 36px;
  padding: 0 var(--space-1);
  text-align: center;
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  border-radius: var(--radius-s);
  color: var(--ink);
}
.souhait-qty:focus {
  border-color: var(--bronze-light);
  box-shadow: none;
  outline: none;
}
.souhait-qty:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
</style>
