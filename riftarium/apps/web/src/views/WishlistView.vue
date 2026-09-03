<script setup>
import { onMounted, ref } from "vue"
import { api } from "../api.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import { BANNERS } from "../banners.js"
import CardTile from "../components/CardTile.vue"
import PageBanner from "../components/PageBanner.vue"

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
</script>

<template>
  <PageBanner :art="BANNERS.collection" title="Ma wishlist" />

  <section>
    <div class="wrap cards-wrap">
      <div class="stat-row">
        <div class="stat" v-reveal>
          Cartes souhaitées<b>{{ list.total }}</b>
        </div>
        <div class="stat" v-reveal="1" :title="PRICE_NOTE">
          Valeur estimée<b>{{ formatEur(list.value_eur) || "—" }}</b>
        </div>
      </div>

      <p v-if="error" class="error">{{ error }}</p>
      <p v-if="loading" class="muted mono" style="font-size: 0.82rem">Chargement de votre wishlist…</p>

      <div v-if="list.items.length" class="grid-cards">
        <div v-for="item in list.items" :key="item.card.id" class="wish-cell">
          <CardTile :card="item.card" :preview="false" />
          <div class="wish-controls">
            <div class="wish-stepper" role="group" :aria-label="`Quantité souhaitée de ${item.card.name}`">
              <button
                type="button"
                :disabled="Boolean(busyId) || item.qty <= 1"
                aria-label="Un exemplaire de moins"
                @click="setQty(item, item.qty - 1)"
              >
                −
              </button>
              <input
                type="number"
                inputmode="numeric"
                min="1"
                max="99"
                :value="item.qty"
                :aria-label="`Quantité souhaitée de ${item.card.name}`"
                :disabled="Boolean(busyId)"
                @change="setQty(item, $event.target.value, $event.target)"
              />
              <button
                type="button"
                :disabled="Boolean(busyId) || item.qty >= 99"
                aria-label="Un exemplaire de plus"
                @click="setQty(item, item.qty + 1)"
              >
                +
              </button>
            </div>
            <button
              type="button"
              class="wish-remove"
              :aria-label="`Retirer ${item.card.name} de ma liste de souhaits`"
              :disabled="Boolean(busyId)"
              @click="removeItem(item)"
            >
              Retirer
            </button>
          </div>
        </div>
      </div>

      <p v-else-if="!loading && !error" class="muted wish-empty">
        Votre wishlist est vide. Le cœur sur la fiche d'une carte de la
        <RouterLink to="/cartes">cartothèque</RouterLink> l'ajoute ici.
      </p>
    </div>
  </section>
</template>
