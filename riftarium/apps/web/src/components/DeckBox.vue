<script setup>
import { computed } from "vue"
import { deckIdentity, legalState, legendOf, runesOf } from "../deckDisplay.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import { profilePath } from "../social.js"
import UserAvatar from "./UserAvatar.vue"

const props = defineProps({
  deck: { type: Object, required: true },
  to: { type: String, required: true },
  community: { type: Boolean, default: false },
  /* Boîte en lecture seule (profil public d'un joueur) : ni suppression, ni
     mention public/privé — le visiteur n'est pas chez lui. */
  readonly: { type: Boolean, default: false },
  /* Bilan des parties suivies de ce deck ({played, won, lost}), fourni par la vue
     qui liste les decks du propriétaire connecté. Jamais sur la communauté. */
  record: { type: Object, default: null },
  /* Un like de ce deck est en cours : le bouton attend la réponse du serveur. */
  likeBusy: { type: Boolean, default: false }
})
defineEmits(["like", "remove"])

const legal = computed(() => legalState(props.deck))
const legend = computed(() => legendOf(props.deck))
const runes = computed(() => runesOf(props.deck))
const record = computed(() => (!props.community && props.record?.played ? props.record : null))

/* « 3 manquante(s) (~4,50 €) » — le coût n'apparaît que si l'API l'a chiffré. */
function missingNote(deck) {
  const cost = formatEur(deck.missing_cost_eur)
  return `${deck.missing_cards} manquante(s)${cost ? ` (~${cost})` : ""}`
}
</script>

<template>
  <!-- Fiche horizontale : la carte de la légende à gauche, l'identité du deck à
       droite. Les couleurs de ses domaines habillent la tranche et le halo de la
       carte (deckIdentity pose --d1 / --d2). -->
  <article class="deck-box" :style="deckIdentity(deck)">
    <RouterLink class="deck-box-cover" :class="{ blank: !legend }" :to="to" :aria-label="`Ouvrir le deck ${deck.name}`">
      <span v-if="!legend" class="deck-box-nolegend">Sans légende</span>
    </RouterLink>

    <div class="deck-box-body">
      <div class="deck-box-head">
        <h3 class="deck-box-title">
          <RouterLink :to="to" :title="deck.name">{{ deck.name }}</RouterLink>
        </h3>
        <!-- role="img" : sans rôle, un aria-label posé sur un span générique est
             ignoré par les lecteurs d'écran ; la raison remplace alors « Légal ». -->
        <span
          class="deck-legal"
          :class="legal.ok ? 'ok' : 'ko'"
          role="img"
          :title="legal.title"
          :aria-label="legal.title"
        >
          <span aria-hidden="true">{{ legal.ok ? "✓" : "✕" }}</span>
          {{ legal.label }}
        </span>
      </div>
      <!-- Au doigt l'infobulle ne s'ouvre jamais : la raison de l'illégalité se lit en clair. -->
      <p v-if="!legal.ok" class="deck-legal-why">{{ legal.title }}</p>

      <p class="deck-box-legend mono" v-if="legend">{{ legend.name }}</p>
      <p class="deck-box-legend mono muted" v-else>Légende à choisir</p>

      <p class="deck-box-meta mono">
        <template v-if="community && deck.owner">
          <span class="deck-box-owner">
            <UserAvatar :src="deck.owner_avatar" :handle="deck.owner" :size="18" />
            <!-- Le pseudo de l'auteur mène à son profil public. -->
            <RouterLink :to="profilePath(deck.owner)">{{ deck.owner }}</RouterLink>
          </span>
          ·
        </template>
        <!-- Le format n'est plus écrit ici : la pastille Légal / Illégal le porte. -->
        <template v-if="deck.card_count !== undefined && deck.card_count !== null">
          {{ deck.card_count }} cartes
        </template>
        <template v-if="formatEur(deck.prices?.total_eur)">
          · <span class="price-tag" :title="PRICE_NOTE">{{ formatEur(deck.prices.total_eur) }}</span>
        </template>
        <template v-if="!community && !readonly">
          · {{ deck.is_public ? "public" : "privé" }}
          <span v-if="deck.moderation_status === 'pending'" class="deck-box-pending"> · en modération</span>
        </template>
        <!-- Renseigné par l'API pour les visiteurs connectés uniquement. -->
        <template v-if="community && deck.missing_cards !== undefined && deck.missing_cards !== null">
          ·
          <span v-if="deck.missing_cards === 0" class="deck-buildable" title="Vous possédez toutes les cartes">
            Complet
          </span>
          <span v-else class="deck-missing" :title="PRICE_NOTE">{{ missingNote(deck) }}</span>
        </template>
      </p>

      <div class="deck-box-foot">
        <span class="deck-box-runes" v-if="runes.length">
          <img
            v-for="rune in runes"
            :key="rune.domain"
            :src="rune.src"
            :alt="rune.label"
            :title="rune.label"
            width="22"
            height="22"
          />
        </span>
        <span class="deck-box-stats">
          <span
            v-if="record"
            class="deck-record mono"
            :title="`Parties suivies : ${record.won} victoire(s), ${record.lost} défaite(s)`"
          >
            {{ record.won }} V · {{ record.lost }} D
          </span>
          <button
            v-if="community"
            type="button"
            class="deck-box-stat"
            :class="{ liked: deck.liked_by_me }"
            :aria-pressed="deck.liked_by_me"
            :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
            :disabled="likeBusy"
            @click.stop="$emit('like', deck)"
          >
            <Icon name="heart" :size="16" />
            {{ deck.likes ?? 0 }}
          </button>
          <span v-else class="deck-box-stat" :title="`${deck.likes ?? 0} j'aime`">
            <Icon name="heart" :size="16" />
            {{ deck.likes ?? 0 }}
          </span>
          <span v-if="community" class="deck-box-stat" :title="`${deck.views ?? 0} vue(s)`">
            <Icon name="eye" :size="16" />
            {{ deck.views ?? 0 }}
          </span>
        </span>
        <div class="deck-box-buttons">
          <RouterLink class="btn btn-gold btn-sm" :to="to">Ouvrir</RouterLink>
          <button v-if="!community && !readonly" class="btn btn-ghost btn-sm" @click="$emit('remove', deck)">
            Supprimer
          </button>
        </div>
      </div>
    </div>
  </article>
</template>
