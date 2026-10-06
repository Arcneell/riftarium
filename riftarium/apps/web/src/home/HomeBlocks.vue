<script setup>
import { computed, onBeforeUnmount, ref, watch } from "vue"
import { session } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import { loadMemberSummary, outcomeLabel } from "./homeData.js"

/* Trois blocs Forgés. Visiteur : les trois piliers du site. Membre : sa collection,
   son dernier deck, son dernier match ; un bloc sans donnée garde sa version visiteur. */
const summary = ref(null)
const loading = ref(false)
let controller = null

async function load() {
  controller?.abort()
  summary.value = null
  if (!session.token) {
    loading.value = false
    return
  }
  const current = new AbortController()
  controller = current
  loading.value = true
  const result = await loadMemberSummary({ signal: current.signal })
  if (controller !== current) return
  summary.value = result
  loading.value = false
}

watch(() => session.token, load, { immediate: true })
onBeforeUnmount(() => {
  controller?.abort()
  controller = null
})

const member = computed(() => Boolean(session.token))
const collection = computed(() => summary.value?.collection ?? null)
const deck = computed(() => summary.value?.deck ?? null)
const deckSize = computed(() => {
  const count = deck.value?.card_count
  if (!count) return "Deck vide : ajoutez vos premières cartes"
  return count === 1 ? "1 carte" : `${count} cartes`
})
const match = computed(() => summary.value?.match ?? null)
</script>

<template>
  <div class="blocks">
    <!-- Bloc 1 : Collection (membre) ou Decks (visiteur) -->
    <RiftPanel v-if="member" title="Collection" accent="var(--body)">
      <RiftSkeleton v-if="loading" />
      <template v-else-if="collection">
        <p class="block-figure">{{ collection.percent }} %</p>
        <p class="block-text">{{ collection.owned }} / {{ collection.total }} cartes du jeu</p>
        <RiftButton to="/collection" size="sm">Voir ma collection</RiftButton>
      </template>
      <template v-else>
        <p class="block-text">Notez vos exemplaires et suivez la complétion de chaque set.</p>
        <RiftButton to="/collection" size="sm">Suivre ma collection</RiftButton>
      </template>
    </RiftPanel>
    <RiftPanel v-else title="Decks" accent="var(--fury)">
      <p class="block-text">Le deck builder vérifie les règles officielles à mesure que vous construisez.</p>
      <div class="block-actions">
        <RiftButton to="/decks" size="sm">Construire un deck</RiftButton>
        <RiftButton to="/communaute" size="sm" variant="secondary">Decks de la communauté</RiftButton>
      </div>
    </RiftPanel>

    <!-- Bloc 2 : dernier deck (membre) ou Collection (visiteur) -->
    <RiftPanel v-if="member && (loading || deck)" title="Mon dernier deck" accent="var(--fury)">
      <RiftSkeleton v-if="loading" />
      <template v-else>
        <p class="block-name">{{ deck.name }}</p>
        <p class="block-text">{{ deckSize }}</p>
        <RiftButton :to="`/decks/${deck.id}`" size="sm">Reprendre</RiftButton>
      </template>
    </RiftPanel>
    <RiftPanel v-else-if="member" title="Decks" accent="var(--fury)">
      <p class="block-text">Construisez votre premier deck : les règles sont vérifiées en direct.</p>
      <RiftButton to="/decks" size="sm">Construire un deck</RiftButton>
    </RiftPanel>
    <RiftPanel v-else title="Collection" accent="var(--body)">
      <p class="block-text">Quantité, état, langue : votre inventaire et ce qu'il vous manque, set par set.</p>
      <RiftButton to="/collection" size="sm">Suivre ma collection</RiftButton>
    </RiftPanel>

    <!-- Bloc 3 : dernier match (membre) ou Règles -->
    <RiftPanel v-if="member && (loading || match)" title="Dernier match" accent="var(--mind)">
      <RiftSkeleton v-if="loading" />
      <template v-else>
        <p class="block-figure">{{ outcomeLabel(match.outcome) }}</p>
        <p v-if="match.opponent?.handle" class="block-text">contre {{ match.opponent.handle }}</p>
        <RiftButton to="/historique" size="sm">Historique</RiftButton>
      </template>
    </RiftPanel>
    <RiftPanel v-else title="Règles" accent="var(--order)">
      <p class="block-text">Guide en chapitres, aide avancée et texte officiel, consultables même hors ligne.</p>
      <RiftButton to="/regles" size="sm">Ouvrir les règles</RiftButton>
    </RiftPanel>
  </div>
</template>

<style scoped>
.blocks {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: var(--space-5);
  padding: var(--space-7) var(--space-6);
}
.block-figure {
  font-family: var(--font-display);
  font-size: 34px;
  font-weight: 900;
  line-height: 1;
  color: var(--ink);
}
.block-name {
  font-family: var(--font-display);
  font-size: 20px;
  font-weight: 700;
  color: var(--ink);
}
.block-text {
  margin: var(--space-2) 0 var(--space-4);
  color: var(--ink-muted);
}
.block-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
@media (max-width: 767px) {
  .blocks {
    padding: var(--space-6) var(--space-4);
  }
}
</style>
