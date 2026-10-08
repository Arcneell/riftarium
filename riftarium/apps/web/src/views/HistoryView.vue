<script setup>
import { computed, onMounted, ref } from "vue"
import MatchRow from "../play/MatchRow.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import { getHistory } from "../play.js"

const SIZE = 20

const items = ref([])
const total = ref(0)
const page = ref(1)
const loading = ref(true)
const error = ref("")

const pageCount = computed(() => Math.max(1, Math.ceil(total.value / SIZE)))
const empty = computed(() => !loading.value && !error.value && !items.value.length)

async function load() {
  loading.value = true
  error.value = ""
  try {
    /* Enveloppe du contrat : { total, page, size, items: [HistoryItem] }. */
    const payload = await getHistory(page.value, SIZE)
    const list = payload?.items || []
    items.value = list
    total.value = payload?.total ?? list.length
  } catch (e) {
    error.value = e.message
    items.value = []
    total.value = 0
  } finally {
    loading.value = false
  }
}

function goTo(next) {
  if (next < 1 || next > pageCount.value || loading.value) return
  page.value = next
  load()
}

onMounted(load)
</script>

<template>
  <div class="wrap cards-wrap histo">
    <h1 class="histo-title">Historique des parties</h1>

    <p v-if="error" class="histo-error" role="alert">{{ error }}</p>

    <div v-else-if="loading && !items.length" class="histo-squelette" role="status">
      <span class="sr-only">Chargement de l'historique…</span>
      <RiftSkeleton v-for="n in 4" :key="n" block />
    </div>

    <template v-else-if="items.length">
      <p class="histo-count">{{ total }} partie(s) terminée(s)</p>

      <ol class="histo-list">
        <MatchRow v-for="item in items" :key="item.match_id" :item="item" />
      </ol>

      <div v-if="pageCount > 1" class="histo-pager">
        <RiftButton variant="ghost" size="sm" :disabled="page <= 1 || loading" @click="goTo(page - 1)">
          ← Précédent
        </RiftButton>
        <span class="histo-page">page {{ page }} / {{ pageCount }}</span>
        <RiftButton variant="ghost" size="sm" :disabled="page >= pageCount || loading" @click="goTo(page + 1)">
          Suivant →
        </RiftButton>
      </div>
    </template>

    <RiftEmpty
      v-else-if="empty"
      class="histo-empty"
      title="Aucune partie suivie"
      text="Les parties suivies se créent depuis l'application mobile (« Jouer », puis « Partie suivie »). Un code reçu se saisit dans le salon."
    >
      <RiftButton variant="primary" to="/salon">Rejoindre un salon</RiftButton>
    </RiftEmpty>
  </div>
</template>

<style scoped>
.histo {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
.histo p {
  margin: 0;
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.histo-title {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.histo-empty {
  margin-top: var(--space-4);
}
.histo-error {
  color: var(--blood-text);
}
.histo-count {
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.histo-list {
  display: grid;
  gap: var(--space-3);
  margin: 0;
  padding: 0;
  list-style: none;
}
.histo-squelette {
  display: grid;
  gap: var(--space-3);
}
.histo-squelette :deep(.rift-skeleton-block) {
  height: 84px;
}
.histo-pager {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
}
.histo-page {
  font-family: var(--font-label);
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
</style>
