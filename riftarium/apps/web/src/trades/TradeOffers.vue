<script setup>
import { onMounted, ref } from "vue"
import { defaultsLabel } from "../collection/collectionDefaults.js"
import { getOffers, setOffer } from "../trades.js"
import CardTile from "../ui/CardTile.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import RiftStepper from "../ui/RiftStepper.vue"
import { de } from "../ui/french.js"

/* Ma liste « À échanger » : chaque offre se règle de 0 (retirée) à la quantité
   du lot. On ajoute une offre depuis le détail des exemplaires d'une fiche carte. */
const offers = ref([])
const loading = ref(true)
const error = ref("")
const busy = ref(false)

async function load() {
  try {
    offers.value = await getOffers()
    error.value = ""
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

async function change(item, qty) {
  if (busy.value) return
  busy.value = true
  error.value = ""
  try {
    await setOffer(item.entry_id, qty)
    if (qty === 0) offers.value = offers.value.filter((other) => other.id !== item.id)
    else item.qty = qty
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="offres">
    <p v-if="error" class="offres-erreur" role="alert">{{ error }}</p>
    <div v-if="loading" class="offres-liste">
      <RiftSkeleton v-for="n in 4" :key="n" block />
    </div>
    <ul v-else-if="offers.length" class="offres-liste">
      <li v-for="item in offers" :key="item.id" class="offres-item">
        <RouterLink :to="`/cartes/${item.card.id}`" class="offres-carte">
          <CardTile :card="item.card" :preview="false" />
        </RouterLink>
        <p class="offres-lot">{{ defaultsLabel(item) }} · {{ item.entry_qty }} en collection</p>
        <div class="offres-reglage">
          <span class="offres-label">À échanger</span>
          <RiftStepper
            size="sm"
            :value="item.qty"
            :max="item.entry_qty"
            :busy="busy"
            :increment-label="`Ajouter un exemplaire ${de(item.card.name)} à l'échange`"
            :decrement-label="`Retirer un exemplaire ${de(item.card.name)} de l'échange`"
            @increment="change(item, item.qty + 1)"
            @decrement="change(item, item.qty - 1)"
          />
        </div>
      </li>
    </ul>
    <RiftEmpty
      v-else-if="!error"
      title="Vous ne proposez encore rien"
      text="Ouvrez une carte de votre collection : dans le détail des exemplaires, réglez la quantité « À échanger » de chaque lot."
    >
      <RiftButton to="/collection" variant="secondary">Ma collection</RiftButton>
    </RiftEmpty>
  </div>
</template>

<style scoped>
.offres {
  display: grid;
  gap: var(--space-4);
}
.offres-erreur {
  margin: 0;
  font-size: 14px;
  color: var(--blood-text);
}
.offres-liste {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: var(--space-4);
  margin: 0;
  padding: 0;
  list-style: none;
}
.offres-liste :deep(.rift-skeleton-block) {
  height: auto;
  aspect-ratio: 0.716;
}
.offres-item {
  display: grid;
  gap: var(--space-2);
  align-content: start;
  min-width: 0;
}
.offres-carte {
  display: block;
}
.offres-lot {
  margin: 0;
  font-size: 14px;
  color: var(--ink-muted);
}
.offres-reglage {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-2);
}
.offres-label {
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
</style>
