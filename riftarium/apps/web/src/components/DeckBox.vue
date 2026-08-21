<script setup>
import { computed } from "vue"
import { coverStyle, legalState, legendOf } from "../deckDisplay.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import UserAvatar from "./UserAvatar.vue"

const props = defineProps({
  deck: { type: Object, required: true },
  to: { type: String, required: true },
  community: { type: Boolean, default: false }
})
defineEmits(["like", "remove"])

const legal = computed(() => legalState(props.deck))

/* « 3 manquante(s) (~4,50 €) » — le coût n'apparaît que si l'API l'a chiffré. */
function missingNote(deck) {
  const cost = formatEur(deck.missing_cost_eur)
  return `${deck.missing_cards} manquante(s)${cost ? ` (~${cost})` : ""}`
}
</script>

<template>
  <article class="deck-box">
    <RouterLink
      class="deck-box-cover"
      :class="{ blank: !legendOf(deck) }"
      :to="to"
      :style="coverStyle(deck)"
      :aria-label="`Ouvrir le deck ${deck.name}`"
    >
      <span v-if="!legendOf(deck)" class="deck-box-nolegend">Sans légende</span>
      <span class="deck-legal" :class="legal.ok ? 'ok' : 'ko'" :title="legal.title">
        <span aria-hidden="true">{{ legal.ok ? "✓" : "✕" }}</span>
        {{ legal.label }}
      </span>
      <!-- Pas de pastilles de runes ici : la carte est affichée en entier, ses
           propres icônes de domaine sont lisibles. -->
    </RouterLink>
    <div class="deck-box-plate">
      <h3>
        <RouterLink :to="to">{{ deck.name }}</RouterLink>
      </h3>
      <p class="muted mono">
        <template v-if="community">
          <span class="deck-box-owner">
            <UserAvatar :src="deck.owner_avatar" :handle="deck.owner" :size="20" />
            par {{ deck.owner }}
          </span>
          ·
        </template>
        <!-- Le format n'est plus écrit ici : la pastille Légal / Illégal le porte. -->
        {{ deck.card_count }} cartes
        <template v-if="formatEur(deck.prices?.total_eur)">
          · <span class="price-tag" :title="PRICE_NOTE">{{ formatEur(deck.prices.total_eur) }}</span>
        </template>
        <!-- Renseigné par l'API pour les visiteurs connectés uniquement. -->
        <template v-if="community && deck.missing_cards !== undefined && deck.missing_cards !== null">
          ·
          <span v-if="deck.missing_cards === 0" class="deck-buildable" title="Vous possédez toutes les cartes">
            Complet ✓
          </span>
          <span v-else class="deck-missing" :title="PRICE_NOTE">{{ missingNote(deck) }}</span>
        </template>
        <template v-if="!community">
          · {{ deck.is_public ? "public" : "privé" }}
          <span v-if="deck.moderation_status === 'pending'" style="color: var(--order-text)"> · en modération</span>
        </template>
      </p>
      <div class="deck-box-actions">
        <div class="deck-box-stats">
          <button
            v-if="community"
            type="button"
            class="deck-box-stat"
            :class="{ liked: deck.liked_by_me }"
            :aria-pressed="deck.liked_by_me"
            :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
            @click.stop="$emit('like', deck)"
          >
            <Icon name="heart" :size="14" />
            {{ deck.likes }}
          </button>
          <span v-else class="deck-box-stat" :title="`${deck.likes} j'aime`">
            <Icon name="heart" :size="14" />
            {{ deck.likes }}
          </span>
          <span v-if="community" class="deck-box-stat" :title="`${deck.views} vue(s)`">
            <Icon name="eye" :size="14" />
            {{ deck.views }}
          </span>
        </div>
        <!-- Boutons sur leur propre ligne : la vignette est étroite, ils gardent
             la même largeur et la même position d'une boîte à l'autre. -->
        <div class="deck-box-buttons">
          <RouterLink class="btn btn-ghost btn-sm" :to="to">Ouvrir</RouterLink>
          <button v-if="!community" class="btn btn-ghost btn-sm" @click="$emit('remove', deck)">Supprimer</button>
        </div>
      </div>
    </div>
  </article>
</template>
