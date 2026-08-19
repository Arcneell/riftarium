<script setup>
import { coverStyle, formatLabel, legendOf, okCount, runesOf } from "../deckDisplay.js"
import UserAvatar from "./UserAvatar.vue"

defineProps({
  deck: { type: Object, required: true },
  to: { type: String, required: true },
  community: { type: Boolean, default: false }
})
defineEmits(["like", "remove"])
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
      <span class="deck-box-runes" v-if="runesOf(deck).length">
        <img
          v-for="rune in runesOf(deck)"
          :key="rune.domain"
          :src="rune.src"
          :alt="rune.label"
          :title="rune.label"
          width="24"
          height="24"
        />
      </span>
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
        {{ deck.card_count }} cartes · {{ formatLabel(deck.format) }}
        <template v-if="deck.checks">
          · {{ okCount(deck) }}/{{ deck.checks.length }} règles ·
          {{ deck.is_public ? "public" : "privé" }}
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
          <span v-else class="chip" style="--chip: var(--chaos)">♥ {{ deck.likes }}</span>
          <span v-if="community" class="deck-box-stat" :title="`${deck.views} vue(s)`">
            <Icon name="eye" :size="14" />
            {{ deck.views }}
          </span>
        </div>
        <RouterLink class="btn btn-ghost btn-sm" :to="to">Ouvrir</RouterLink>
        <button v-if="!community" class="btn btn-ghost btn-sm" @click="$emit('remove', deck)">Supprimer</button>
      </div>
    </div>
  </article>
</template>
