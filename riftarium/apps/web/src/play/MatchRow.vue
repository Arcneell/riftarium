<script setup>
import { computed } from "vue"
import { cardThumb } from "../api.js"
import { formatPlayedAt, formatRelativePlayedAt, modeLabel, outcomeLabel } from "../play.js"
import { profilePath } from "../social.js"
import UserAvatar from "../components/UserAvatar.vue"
import RiftChip from "../ui/RiftChip.vue"

/* Une partie suivie terminée, telle que la renvoie `HistoryItem`. Le même rendu
   sert à `/historique` (mon point de vue) et au profil public d'un joueur (son
   point de vue) : seul change le nom porté par le côté gauche. */
const props = defineProps({
  item: { type: Object, required: true },
  /* Le joueur dont on regarde l'historique. null = moi, sur ma propre page. */
  self: { type: Object, default: null }
})

const opponent = computed(() => props.item.opponent || null)

/* Couleurs du jeu : victoire en bronze clair, défaite en rouge de texte, le reste
   (contesté, ne compte pas dans les stats) en encre atténuée, hachuré. */
const OUTCOME_COLORS = { win: "var(--bronze-light)", loss: "var(--blood-text)" }
const outcomeColor = computed(() => OUTCOME_COLORS[props.item.outcome] || "var(--ink-muted)")
const outcomeKind = computed(() =>
  props.item.outcome === "win" || props.item.outcome === "loss" ? props.item.outcome : "disputed"
)
</script>

<template>
  <li class="partie-row">
    <span class="partie-issue" :class="`partie-issue-${outcomeKind}`">
      <RiftChip static selected :label="outcomeLabel(item.outcome)" :color="outcomeColor" />
    </span>

    <div class="partie-side partie-side-me">
      <p class="partie-who">
        <template v-if="self">
          <UserAvatar :src="self.avatar_url" :handle="self.handle" :size="22" />
          <span class="partie-ellipse" :title="self.handle">{{ self.handle }}</span>
        </template>
        <span v-else class="partie-ellipse">Moi</span>
      </p>
      <p class="partie-legend">
        <img
          v-if="item.my_legend?.image_url"
          class="partie-thumb"
          :src="cardThumb(item.my_legend.image_url, 64)"
          :alt="`Légende : ${item.my_legend.name}`"
          width="32"
          height="32"
          loading="lazy"
          decoding="async"
        />
        <span v-else class="partie-thumb partie-thumb-empty" aria-hidden="true"></span>
        <span class="partie-ellipse">{{ item.my_legend?.name || "Sans légende" }}</span>
      </p>
      <p class="partie-deck">
        <RouterLink v-if="item.my_deck?.id" class="partie-ellipse" :to="`/decks/${item.my_deck.id}`">
          {{ item.my_deck.name }}
        </RouterLink>
        <span v-else class="partie-faint">Sans deck</span>
      </p>
    </div>

    <div class="partie-score">
      <b>{{ item.my_score }} – {{ item.opponent_score }}</b>
      <span v-if="item.mode === 'match'">manches {{ item.my_rounds }} – {{ item.opponent_rounds }}</span>
    </div>

    <div class="partie-side partie-side-adv">
      <p class="partie-who">
        <template v-if="opponent">
          <UserAvatar :src="opponent.avatar_url" :handle="opponent.handle" :size="22" />
          <!-- Le pseudo mène au profil public de l'adversaire. -->
          <RouterLink class="partie-ellipse partie-pseudo" :to="profilePath(opponent.handle)" :title="opponent.handle">
            {{ opponent.handle }}
          </RouterLink>
        </template>
        <span v-else class="partie-faint">Compte supprimé</span>
      </p>
      <p class="partie-legend">
        <img
          v-if="item.opponent_legend?.image_url"
          class="partie-thumb"
          :src="cardThumb(item.opponent_legend.image_url, 64)"
          :alt="`Légende adverse : ${item.opponent_legend.name}`"
          width="32"
          height="32"
          loading="lazy"
          decoding="async"
        />
        <span v-else class="partie-thumb partie-thumb-empty" aria-hidden="true"></span>
        <span class="partie-ellipse">{{ item.opponent_legend?.name || "Sans légende" }}</span>
      </p>
      <p class="partie-deck">
        <span class="partie-faint partie-ellipse">{{ item.opponent_deck?.name || "Sans deck" }}</span>
      </p>
    </div>

    <div class="partie-meta">
      <RiftChip static :label="modeLabel(item.mode)" />
      <time class="partie-when" :datetime="item.played_at" :title="formatPlayedAt(item.played_at)">
        {{ formatRelativePlayedAt(item.played_at) }}
      </time>
    </div>
  </li>
</template>

<style scoped>
.partie-row {
  list-style: none;
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto minmax(0, 1fr) auto;
  grid-template-areas: "issue me score adv meta";
  align-items: center;
  gap: var(--space-4);
  padding: var(--space-4) var(--space-5);
  background: var(--bg-raised);
  border: 1px solid var(--line);
  border-left: 3px solid var(--bronze);
}
.partie-issue {
  grid-area: issue;
}
.partie-side-me {
  grid-area: me;
}
.partie-score {
  grid-area: score;
}
.partie-side-adv {
  grid-area: adv;
}
.partie-meta {
  grid-area: meta;
}
/* Contesté : hachure sous la pastille, l'issue ne se lit pas qu'à la couleur. */
.partie-issue-disputed :deep(.rift-chip) {
  background-image: repeating-linear-gradient(
    135deg,
    transparent 0 5px,
    color-mix(in srgb, var(--ink-muted) 28%, transparent) 5px 6px
  );
}
.partie-side {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.partie-side p {
  margin: 0;
  min-width: 0;
}
.partie-who {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-family: var(--font-label);
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 0.04em;
  color: var(--ink);
}
.partie-legend {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  font-size: 0.85rem;
  color: var(--ink-muted);
}
.partie-deck {
  font-size: 0.8rem;
  color: var(--ink-muted);
}
.partie-deck a {
  color: var(--bronze-light);
}
.partie-deck a:focus-visible,
.partie-who a:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.partie-who a {
  color: var(--ink);
}
.partie-pseudo {
  font-weight: 700;
}
.partie-who a:hover {
  color: var(--bronze-light);
}
.partie-faint {
  color: var(--ink-muted);
}
/* Les pseudos et noms longs sont tronqués par une ellipse, jamais renvoyés à la ligne. */
.partie-ellipse {
  display: block;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.partie-thumb {
  width: 32px;
  height: 32px;
  flex: none;
  border-radius: 50%;
  object-fit: cover;
  background: var(--bg-sunken);
  border: 1px solid var(--bronze);
}
.partie-thumb-empty {
  display: inline-block;
}
.partie-score {
  text-align: center;
  min-width: 88px;
}
.partie-score b {
  display: block;
  font-family: var(--font-display);
  font-size: 1.6rem;
  font-weight: 700;
  color: var(--ink);
  white-space: nowrap;
}
.partie-score span {
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-muted);
  white-space: nowrap;
}
.partie-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: var(--space-1);
}
.partie-when {
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
  white-space: nowrap;
}

@media (max-width: 560px) {
  /* Deux lignes : issue et date en haut, le duel (moi, score, adversaire) dessous. */
  .partie-row {
    grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
    grid-template-areas:
      "issue issue meta"
      "me score adv";
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
  }
  .partie-meta {
    flex-direction: row;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
  }
  .partie-score {
    min-width: 64px;
  }
}
</style>
