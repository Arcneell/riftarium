<script setup>
import { computed, ref } from "vue"
import { useRouter } from "vue-router"
import { api, session, DOMAINS } from "../api.js"
import { DOMAIN_RUNE, RUNE_LABELS, glyphUrl } from "../cardText.js"
import { useDeckStats } from "../composables/useDeckStats.js"
import { DECK_ZONES, groupDeck, legalState, runesOf } from "../deckDisplay.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import DeckExportBar from "./DeckExportBar.vue"
import DeckVisual from "./DeckVisual.vue"
import UserAvatar from "./UserAvatar.vue"

const props = defineProps({
  deck: { type: Object, required: true }
})
defineEmits(["like"])

const grouped = computed(() => groupDeck(props.deck))
const runes = computed(() => runesOf(props.deck))
const legal = computed(() => legalState(props.deck))
const zoneCounts = computed(() => {
  const counts = {}
  for (const zone of DECK_ZONES) {
    counts[zone.key] = grouped.value[zone.key].reduce((total, entry) => total + entry.qty, 0)
  }
  return counts
})

const { curve, curveLabel, energyTotal, domainSpread } = useDeckStats(() => props.deck.cards || [])

/* Valeur indicative du deck (deck_out.prices, null si rien de pricé). */
const deckValue = computed(() => formatEur(props.deck.prices?.total_eur))

/* Copier le deck d'un autre joueur dans « Mes decks » : copie privée, modifiable,
   avec la modale des cartes manquantes pour savoir quoi acheter. */
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
  <section class="deck-view">
    <div class="wrap">
      <div class="deck-view-bar">
        <RouterLink to="/communaute" class="dbuilder-back">← Communauté</RouterLink>
        <h2 class="deck-view-title">{{ deck.name }}</h2>
        <p class="muted mono deck-view-meta">
          <!-- Même pastille que sur les fiches : format officiel ET règles respectées. -->
          <span class="deck-legal" :class="legal.ok ? 'ok' : 'ko'" :title="legal.title">
            <span aria-hidden="true">{{ legal.ok ? "✓" : "✕" }}</span>
            {{ legal.label }}
          </span>
          ·
          <span class="deck-box-owner">
            <UserAvatar :src="deck.owner_avatar" :handle="deck.owner" :size="20" />
            par {{ deck.owner }}
          </span>
        </p>
        <!-- Au doigt l'infobulle ne s'ouvre jamais : la raison de l'illégalité se lit en clair. -->
        <p v-if="!legal.ok" class="deck-legal-why">{{ legal.title }}</p>
        <div class="deck-view-runes" v-if="runes.length">
          <img
            v-for="rune in runes"
            :key="rune.domain"
            :src="rune.src"
            :alt="rune.label"
            :title="rune.label"
            width="26"
            height="26"
          />
        </div>
        <div class="deck-box-stats">
          <!-- Même condition que l'éditeur : un deck public mais en modération
               n'est pas encore likeable. -->
          <button
            v-if="deck.is_public && deck.moderation_status === 'published'"
            type="button"
            class="deck-box-stat"
            :class="{ liked: deck.liked_by_me }"
            :aria-pressed="deck.liked_by_me"
            :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
            @click="$emit('like')"
          >
            <Icon name="heart" :size="16" />
            {{ deck.likes ?? 0 }}
          </button>
          <span class="deck-box-stat" :title="`${deck.views ?? 0} vue(s)`">
            <Icon name="eye" :size="16" />
            {{ deck.views ?? 0 }}
          </span>
          <button
            v-if="canCopy"
            type="button"
            class="btn btn-ghost btn-sm"
            :disabled="copying"
            title="Crée votre copie privée, modifiable, avec la liste des cartes manquantes"
            @click="copyDeck"
          >
            {{ copying ? "Copie…" : "Copier dans mes decks" }}
          </button>
        </div>
        <p v-if="copyError" class="error">{{ copyError }}</p>
      </div>

      <div class="deck-meters">
        <div
          class="meter"
          v-for="zone in DECK_ZONES"
          :key="zone.key"
          :class="{ full: zoneCounts[zone.key] >= zone.target }"
        >
          <b
            >{{ zoneCounts[zone.key] }}<small>/{{ zone.target }}{{ zone.key === "main" ? "+" : "" }}</small></b
          >
          <span>{{ zone.label }}</span>
        </div>
      </div>

      <div class="deck-view-layout">
        <div class="deck-view-board">
          <DeckVisual :deck="deck" />
        </div>
        <aside class="deck-view-side">
          <p class="overview-energy">
            <b>{{ energyTotal }}</b> énergie
          </p>
          <p v-if="deckValue" class="price-deck" :title="PRICE_NOTE">
            Valeur du deck : <b class="price-amount">{{ deckValue }}</b>
          </p>
          <div class="curve" role="group" aria-label="Répartition des coûts en énergie du deck principal">
            <div class="bar" v-for="bucket in curve" :key="bucket.cost">
              <i :style="{ height: bucket.height + '%' }" :title="`${bucket.count} carte(s) à ${bucket.cost}`"></i>
              <span class="sr-only">{{ bucket.count }} carte(s) à {{ bucket.cost }} d'énergie</span>
              <small>{{ bucket.cost }}{{ bucket.cost === 7 ? "+" : "" }}</small>
            </div>
          </div>
          <!-- Doublon visuel des barres : aria-hidden, les .sr-only des barres le disent déjà. -->
          <p v-if="curveLabel" class="curve-legend mono" aria-hidden="true">{{ curveLabel }}</p>
          <div class="deck-domains" v-if="domainSpread.length">
            <span class="chip chip-rune" v-for="[domain, count] in domainSpread" :key="domain">
              <img
                class="rb-glyph rune"
                :src="glyphUrl(`rune_${DOMAIN_RUNE[domain] || 'rainbow'}`)"
                :alt="RUNE_LABELS[DOMAIN_RUNE[domain]] || domain"
                width="18"
                height="18"
              />
              {{ DOMAINS[domain]?.label || domain }} · {{ count }}
            </span>
          </div>
          <ul class="validator" v-if="deck.checks?.length">
            <li v-for="checkItem in deck.checks" :key="checkItem.rule" :class="checkItem.ok ? 'v-ok' : 'v-ko'">
              {{ checkItem.message }}
            </li>
          </ul>
          <p v-if="deck.description" class="deck-read-desc">{{ deck.description }}</p>
          <DeckExportBar :deck="deck" />
        </aside>
      </div>
    </div>
  </section>
</template>
