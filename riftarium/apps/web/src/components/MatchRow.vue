<script setup>
import { computed } from "vue"
import { cardThumb } from "../api.js"
import { formatPlayedAt, modeLabel, outcomeLabel, outcomeTone } from "../play.js"
import { profilePath } from "../social.js"
import UserAvatar from "./UserAvatar.vue"

/* Une partie suivie terminée, telle que la renvoie `HistoryItem`. Le même rendu
   sert à `/historique` (mon point de vue) et au profil public d'un joueur (son
   point de vue) : seul change le nom porté par le côté gauche. */
const props = defineProps({
  item: { type: Object, required: true },
  /* Le joueur dont on regarde l'historique. null = moi, sur ma propre page. */
  self: { type: Object, default: null }
})

const opponent = computed(() => props.item.opponent || null)
</script>

<template>
  <li class="panel play-row">
    <div class="play-row-head">
      <span class="mono play-when">{{ formatPlayedAt(item.played_at) }}</span>
      <span class="chip play-mode">{{ modeLabel(item.mode) }}</span>
      <span class="chip play-outcome" :class="outcomeTone(item.outcome)">{{ outcomeLabel(item.outcome) }}</span>
    </div>

    <div class="play-duel">
      <div class="play-side">
        <p class="play-side-who">
          <template v-if="self">
            <UserAvatar :src="self.avatar_url" :handle="self.handle" :size="22" />
            {{ self.handle }}
          </template>
          <template v-else>Moi</template>
        </p>
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
          <RouterLink v-if="item.my_deck?.id" :to="`/decks/${item.my_deck.id}`">{{ item.my_deck.name }}</RouterLink>
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
          <template v-if="opponent">
            <UserAvatar :src="opponent.avatar_url" :handle="opponent.handle" :size="22" />
            <!-- Le pseudo mène au profil public de l'adversaire. -->
            <RouterLink :to="profilePath(opponent.handle)">{{ opponent.handle }}</RouterLink>
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
</template>
