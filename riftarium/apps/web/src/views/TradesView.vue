<script setup>
import { computed, onMounted, ref } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api } from "../api.js"
import TradeActivate from "../trades/TradeActivate.vue"
import TradeMatches from "../trades/TradeMatches.vue"
import TradeOffers from "../trades/TradeOffers.vue"
import TradeRequests from "../trades/TradeRequests.vue"
import { tradeBadge, zoneLabel } from "../trades.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftSegments from "../ui/RiftSegments.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

/* Échanges entre joueurs (docs/echanges.md) : activation, puis trois segments
   — correspondances, mes offres, demandes. Le segment vit dans `?onglet=` pour
   que les liens des e-mails ouvrent directement les demandes. */
const route = useRoute()
const router = useRouter()

const me = ref(null)
const loading = ref(true)
const error = ref("")

const TABS = ["correspondances", "offres", "demandes"]
const tab = computed({
  get: () => (TABS.includes(route.query.onglet) ? route.query.onglet : "correspondances"),
  set: (value) => router.replace({ query: { onglet: value } })
})
const segments = computed(() => [
  { value: "correspondances", label: "Correspondances" },
  { value: "offres", label: "Mes offres" },
  { value: "demandes", label: "Demandes", badge: tradeBadge.incoming || undefined }
])
const target = computed(() => Number(route.query.id) || null)

async function load() {
  try {
    me.value = await api("/api/auth/me")
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="wrap cards-wrap echanges-page">
    <header class="echanges-tete">
      <h1 class="echanges-titre">Échanges</h1>
      <p v-if="me?.trade_enabled" class="echanges-zone">
        Zone {{ zoneLabel(me.trade_zone) }} · contact « {{ me.trade_contact }} »
        <RiftButton to="/profil" variant="ghost" size="sm">Modifier</RiftButton>
      </p>
    </header>

    <p v-if="error" class="echanges-erreur" role="alert">{{ error }}</p>
    <RiftSkeleton v-if="loading" block />

    <TradeActivate v-else-if="me && !me.trade_enabled" @enabled="me = $event" />

    <template v-else-if="me">
      <RiftSegments v-model="tab" class="echanges-segments" :items="segments" label="Échanges" id-base="echanges" />
      <div :id="`echanges-panel-${tab}`" role="tabpanel" :aria-labelledby="`echanges-tab-${tab}`">
        <TradeMatches v-if="tab === 'correspondances'" :zone="me.trade_zone" />
        <TradeOffers v-else-if="tab === 'offres'" />
        <TradeRequests v-else :target="target" />
      </div>
    </template>
  </div>
</template>

<style scoped>
.echanges-page {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
.echanges-tete {
  display: grid;
  gap: var(--space-2);
}
/* Titre de page : neutralise le style de base des h1. */
.echanges-titre {
  margin: 0;
  color: var(--ink);
  font-weight: 700;
}
.echanges-zone {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
  margin: 0;
  color: var(--ink-muted);
}
.echanges-erreur {
  margin: 0;
  font-size: 14px;
  color: var(--blood-text);
}
.echanges-segments {
  justify-self: start;
}
</style>
