<script setup>
import { computed, onMounted, ref } from "vue"
import { BANNERS } from "../banners.js"
import MatchRow from "../components/MatchRow.vue"
import PageBanner from "../components/PageBanner.vue"
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
  <PageBanner :art="BANNERS.community" title="Historique des parties" />

  <section>
    <div class="wrap play-page">
      <p v-if="error" class="error">{{ error }}</p>
      <p v-else-if="loading" class="muted">Chargement de l'historique…</p>

      <template v-else-if="items.length">
        <p class="muted mono play-count">{{ total }} partie(s) terminée(s)</p>

        <ol class="play-history">
          <MatchRow v-for="item in items" :key="item.match_id" :item="item" />
        </ol>

        <div v-if="pageCount > 1" class="pager">
          <button class="btn btn-ghost btn-sm" :disabled="page <= 1" @click="goTo(page - 1)">← Précédent</button>
          <span>page {{ page }} / {{ pageCount }}</span>
          <button class="btn btn-ghost btn-sm" :disabled="page >= pageCount" @click="goTo(page + 1)">Suivant →</button>
        </div>
      </template>

      <div v-else-if="empty" class="panel play-empty">
        <h3>Aucune partie suivie pour l'instant</h3>
        <p class="muted">
          Le compteur vit sur le téléphone : ouvrez l'application Riftarium, choisissez « Jouer » puis « Partie suivie »
          pour créer un salon. Votre adversaire vous rejoint avec le code ou le lien partagé.
        </p>
        <p class="muted">
          Un code vous a été envoyé ? Ouvrez le <RouterLink to="/salon">salon</RouterLink> pour le saisir.
        </p>
        <RouterLink class="btn btn-gold" to="/salon">Rejoindre un salon</RouterLink>
      </div>
    </div>
  </section>
</template>
