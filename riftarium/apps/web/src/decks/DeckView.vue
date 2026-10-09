<script setup>
import { computed, ref } from "vue"
import { useRouter } from "vue-router"
import { api, session } from "../api.js"
import UserAvatar from "../components/UserAvatar.vue"
import { DECK_ZONES, deckIdentity, groupDeck, runesOf } from "../deckDisplay.js"
import { profilePath } from "../social.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftStat from "../ui/RiftStat.vue"
import DeckExportBar from "./DeckExportBar.vue"
import DeckLegalBadge from "./DeckLegalBadge.vue"
import DeckStatsPanel from "./DeckStatsPanel.vue"
import DeckVisual from "./DeckVisual.vue"
import { pluralWord } from "../ui/french.js"

const props = defineProps({
  deck: { type: Object, required: true },
  /* Un like de ce deck est en cours : le bouton attend la réponse du serveur. */
  likeBusy: { type: Boolean, default: false }
})
defineEmits(["like"])

const grouped = computed(() => groupDeck(props.deck))
const runes = computed(() => runesOf(props.deck))
const zoneCounts = computed(() => {
  const counts = {}
  for (const zone of DECK_ZONES) {
    counts[zone.key] = grouped.value[zone.key].reduce((total, entry) => total + entry.qty, 0)
  }
  return counts
})

/* Copier le deck d'un autre joueur dans « Mes decks » : copie privée (« Nom (copie) »,
   créditée à l'auteur) qui s'ouvre dans l'éditeur. */
const router = useRouter()
const copying = ref(false)
const copyError = ref("")
const canCopy = computed(() => Boolean(session.token) && session.handle !== props.deck.owner)

async function copyDeck() {
  if (copying.value) return
  copying.value = true
  copyError.value = ""
  try {
    const copy = await api(`/api/decks/${props.deck.id}/copy`, { method: "POST" })
    router.push(`/decks/${copy.id}`)
  } catch (e) {
    copyError.value = e.message
  } finally {
    copying.value = false
  }
}
</script>

<template>
  <div class="wrap cards-wrap lecture">
    <!-- Bandeau : l'illustration de la légende en fond, sous un voile --bg. -->
    <header class="lecture-hero" :style="deckIdentity(deck)">
      <RouterLink to="/communaute" class="lecture-back">← Communauté</RouterLink>
      <h1 class="lecture-title" :title="deck.name">{{ deck.name }}</h1>
      <div class="lecture-legal">
        <DeckLegalBadge :deck="deck" explain />
      </div>
      <div class="lecture-meta">
        <span class="lecture-owner">
          <UserAvatar :src="deck.owner_avatar" :handle="deck.owner" :size="20" />
          par
          <RouterLink class="lecture-author" :to="profilePath(deck.owner)">{{ deck.owner }}</RouterLink>
        </span>
        <span v-if="runes.length" class="lecture-runes">
          <img
            v-for="rune in runes"
            :key="rune.domain"
            :src="rune.src"
            :alt="rune.label"
            :title="rune.label"
            width="26"
            height="26"
          />
        </span>
      </div>
      <div class="lecture-stats">
        <!-- Même condition que l'éditeur : un deck public mais en modération
             n'est pas encore likeable. -->
        <button
          v-if="deck.is_public && deck.moderation_status === 'published'"
          type="button"
          class="lecture-stat lecture-like"
          :class="{ 'lecture-like--on': deck.liked_by_me }"
          :aria-pressed="Boolean(deck.liked_by_me)"
          :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
          :disabled="likeBusy"
          @click="$emit('like')"
        >
          <Icon name="heart" :size="16" />
          {{ deck.likes ?? 0 }}
        </button>
        <span class="lecture-stat" :title="`${deck.views ?? 0} ${pluralWord(deck.views, 'vue', 'vues')}`">
          <Icon name="eye" :size="16" />
          {{ deck.views ?? 0 }}
        </span>
        <RiftButton
          v-if="canCopy"
          variant="secondary"
          :disabled="copying"
          title="Crée une copie privée de ce deck dans vos decks et l'ouvre dans l'éditeur"
          @click="copyDeck"
        >
          {{ copying ? "Copie…" : "Copier dans mes decks" }}
        </RiftButton>
      </div>
      <p v-if="copyError" class="lecture-error" role="alert">{{ copyError }}</p>
    </header>

    <div class="lecture-meters">
      <RiftStat
        v-for="zone in DECK_ZONES"
        :key="zone.key"
        class="lecture-meter"
        :class="{ 'lecture-meter--full': zoneCounts[zone.key] >= zone.target }"
        :label="zone.label"
        :value="`${zoneCounts[zone.key]}/${zone.target}${zone.key === 'main' ? '+' : ''}`"
      />
    </div>

    <div class="lecture-layout">
      <div class="lecture-board">
        <DeckVisual :deck="deck" />
      </div>
      <aside class="lecture-side">
        <DeckStatsPanel :cards="deck.cards || []" :checks="deck.checks || []" :prices="deck.prices" />
        <p v-if="deck.description" class="lecture-desc">{{ deck.description }}</p>
        <RiftPanel title="Exporter">
          <DeckExportBar :deck="deck" />
        </RiftPanel>
      </aside>
    </div>
  </div>
</template>

<style scoped>
.lecture {
  display: grid;
  gap: var(--space-5);
  padding-block: var(--space-5);
}
.lecture-hero {
  position: relative;
  display: grid;
  gap: var(--space-3);
  justify-items: start;
  padding: var(--space-6) var(--space-5);
  background-color: var(--bg);
  /* Voile --bg sur l'illustration de la légende (--cover, posée par deckIdentity). */
  background-image:
    linear-gradient(180deg, color-mix(in srgb, var(--bg) 55%, transparent) 0%, var(--bg) 100%), var(--cover, none);
  background-size: cover;
  background-position:
    center,
    center 20%;
  background-repeat: no-repeat;
  border: 1px solid var(--line);
}
.lecture-hero::before {
  content: "";
  position: absolute;
  inset: 0 0 auto;
  height: 2px;
  background: linear-gradient(90deg, var(--d1), var(--d2));
}
.lecture-back {
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--bronze-light);
  text-decoration: none;
}
.lecture-back:hover {
  color: var(--ink);
}
.lecture-back:focus-visible,
.lecture-author:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
/* Titre de page : neutralise le style de base des h1. */
.lecture-title {
  display: -webkit-box;
  max-width: 100%;
  margin: 0;
  overflow: hidden;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  color: var(--ink);
  font-family: var(--font-display);
  font-size: clamp(26px, 4vw, 40px);
  font-weight: 700;
  line-height: 1.2;
}
.lecture-legal {
  display: grid;
  gap: var(--space-1);
  justify-items: start;
}
.lecture-meta,
.lecture-stats {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2) var(--space-4);
}
.lecture-owner {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  font-family: var(--font-label);
  font-size: 15px;
  letter-spacing: 0.04em;
  color: var(--ink-muted);
}
.lecture-author {
  color: var(--bronze-light);
}
.lecture-runes {
  display: inline-flex;
  gap: var(--space-1);
}
.lecture-stat {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  font-family: var(--font-label);
  font-size: 15px;
  color: var(--ink-muted);
}
.lecture-like {
  min-width: 44px;
  min-height: 44px;
  padding: 0 var(--space-2);
  background: none;
  border: 0;
  cursor: pointer;
  transition: color var(--t-fast);
}
.lecture-like:hover,
.lecture-like:focus-visible,
.lecture-like--on {
  color: var(--blood-text);
}
.lecture-like:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.lecture-like:disabled {
  opacity: 0.6;
  cursor: wait;
}
.lecture-error {
  margin: 0;
  font-family: var(--font-body);
  font-size: 14px;
  color: var(--blood-text);
}
.lecture-meters {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: var(--space-3);
}
.lecture-meter {
  min-width: 0;
}
/* Zone complète : valeur à l'encre de bronze. */
.lecture-meter--full :deep(.rift-stat-value) {
  color: var(--bronze-light);
}
.lecture-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 320px;
  gap: var(--space-5);
  align-items: start;
}
.lecture-board {
  min-width: 0;
}
.lecture-side {
  display: grid;
  gap: var(--space-4);
  min-width: 0;
}
.lecture-desc {
  margin: 0;
  white-space: pre-line;
  font-family: var(--font-body);
  font-size: 15px;
  line-height: 1.5;
  color: var(--ink);
}
@media (max-width: 1023px) {
  .lecture-layout {
    grid-template-columns: minmax(0, 1fr);
  }
}
@media (prefers-reduced-motion: reduce) {
  .lecture-like {
    transition: none;
  }
}
</style>
