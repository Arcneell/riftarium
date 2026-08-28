<script setup>
import { computed, onMounted, ref } from "vue"
import { cardThumb } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import UserAvatar from "../components/UserAvatar.vue"
import { formatPlayedAt, getHistory, modeLabel, outcomeLabel, outcomeTone } from "../play.js"

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
    const payload = await getHistory(page.value, SIZE)
    /* Le contrat ne fige pas l'enveloppe : liste nue ou { items, total } paginé. */
    const list = Array.isArray(payload) ? payload : payload?.items || []
    items.value = list
    total.value = Array.isArray(payload) ? list.length : (payload?.total ?? list.length)
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
          <li v-for="item in items" :key="item.match_id" class="panel play-row">
            <div class="play-row-head">
              <span class="mono play-when">{{ formatPlayedAt(item.played_at) }}</span>
              <span class="chip play-mode">{{ modeLabel(item.mode) }}</span>
              <span class="chip play-outcome" :class="outcomeTone(item.outcome)">{{ outcomeLabel(item.outcome) }}</span>
            </div>

            <div class="play-duel">
              <div class="play-side">
                <p class="play-side-who">Moi</p>
                <div class="play-side-legend">
                  <img
                    v-if="item.my_legend?.image_url"
                    class="play-legend-thumb"
                    :src="cardThumb(item.my_legend.image_url, 72)"
                    :alt="`Légende : ${item.my_legend.name}`"
                    width="72"
                    height="72"
                    loading="lazy"
                    decoding="async"
                  />
                  <span v-else class="play-legend-thumb empty" aria-hidden="true"></span>
                  <span class="mono">{{ item.my_legend?.name || "Sans légende" }}</span>
                </div>
                <p class="play-side-deck mono">
                  <RouterLink v-if="item.my_deck?.id" :to="`/decks/${item.my_deck.id}`">{{
                    item.my_deck.name
                  }}</RouterLink>
                  <span v-else class="muted">Sans deck</span>
                </p>
              </div>

              <div class="play-score">
                <b>{{ item.my_score }} – {{ item.opponent_score }}</b>
                <span v-if="item.mode === 'match'" class="mono muted">
                  manches {{ item.my_rounds }} – {{ item.opponent_rounds }}
                </span>
              </div>

              <div class="play-side">
                <p class="play-side-who">
                  <template v-if="item.opponent">
                    <UserAvatar :src="item.opponent.avatar_url" :handle="item.opponent.handle" :size="22" />
                    {{ item.opponent.handle }}
                  </template>
                  <span v-else class="muted">Compte supprimé</span>
                </p>
                <div class="play-side-legend">
                  <img
                    v-if="item.opponent_legend?.image_url"
                    class="play-legend-thumb"
                    :src="cardThumb(item.opponent_legend.image_url, 72)"
                    :alt="`Légende adverse : ${item.opponent_legend.name}`"
                    width="72"
                    height="72"
                    loading="lazy"
                    decoding="async"
                  />
                  <span v-else class="play-legend-thumb empty" aria-hidden="true"></span>
                  <span class="mono">{{ item.opponent_legend?.name || "Sans légende" }}</span>
                </div>
                <p class="play-side-deck mono">
                  <span class="muted">{{ item.opponent_deck?.name || "Sans deck" }}</span>
                </p>
              </div>
            </div>
          </li>
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
