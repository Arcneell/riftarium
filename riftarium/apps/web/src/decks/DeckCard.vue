<script setup>
import { computed } from "vue"
import UserAvatar from "../components/UserAvatar.vue"
import { deckIdentity, legalState, legendOf, runesOf } from "../deckDisplay.js"
import { PRICE_NOTE, formatEur } from "../prices.js"
import { profilePath } from "../social.js"
import RiftButton from "../ui/RiftButton.vue"
import DeckLegalBadge from "./DeckLegalBadge.vue"

const props = defineProps({
  deck: { type: Object, required: true },
  to: { type: String, required: true },
  community: { type: Boolean, default: false },
  /* Fiche en lecture seule (profil public d'un joueur) : ni suppression, ni
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
const score = computed(() => (!props.community && props.record?.played ? props.record : null))
const mine = computed(() => !props.community && !props.readonly)

/* « 3 manquante(s) (~4,50 €) » — le coût n'apparaît que si l'API l'a chiffré. */
function missingNote(deck) {
  const cost = formatEur(deck.missing_cost_eur)
  return `${deck.missing_cards} manquante(s)${cost ? ` (~${cost})` : ""}`
}
</script>

<template>
  <!-- Fiche portrait posée sur l'illustration de la légende ; les couleurs de ses
       domaines habillent le liseré (deckIdentity pose --cover, --d1 et --d2). Le
       lien principal couvre toute la fiche, les autres contrôles passent au-dessus. -->
  <article class="deck-card" :class="{ 'deck-card--blank': !legend }" :style="deckIdentity(deck)">
    <RouterLink class="deck-card-link" :to="to" :aria-label="`Ouvrir le deck ${deck.name}`"></RouterLink>
    <span v-if="!legend" class="deck-card-nolegend">Sans légende</span>

    <div class="deck-card-top">
      <DeckLegalBadge :deck="deck" />
      <span v-if="runes.length" class="deck-card-runes">
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
    </div>

    <div class="deck-card-body">
      <h3 class="deck-card-title" :title="deck.name">{{ deck.name }}</h3>
      <p v-if="legend" class="deck-card-legend">{{ legend.name }}</p>
      <p v-else class="deck-card-legend deck-card-legend--none">Légende à choisir</p>
      <!-- Au doigt l'infobulle ne s'ouvre jamais : la raison de l'illégalité se lit en clair. -->
      <p v-if="!legal.ok" class="legalite-why deck-card-why">{{ legal.title }}</p>

      <p class="deck-card-meta">
        <span v-if="community && deck.owner" class="deck-card-owner">
          <UserAvatar :src="deck.owner_avatar" :handle="deck.owner" :size="18" />
          <!-- Le pseudo de l'auteur mène à son profil public. -->
          <RouterLink class="deck-card-author" :to="profilePath(deck.owner)">{{ deck.owner }}</RouterLink>
        </span>
        <!-- Le format n'est plus écrit ici : la pastille Légal / Illégal le porte. -->
        <span v-if="deck.card_count !== undefined && deck.card_count !== null">{{ deck.card_count }} cartes</span>
        <span v-if="formatEur(deck.prices?.total_eur)" class="deck-card-price" :title="PRICE_NOTE">
          {{ formatEur(deck.prices.total_eur) }}
        </span>
        <template v-if="mine">
          <span>{{ deck.is_public ? "public" : "privé" }}</span>
          <span v-if="deck.moderation_status === 'pending'" class="deck-card-pending">en modération</span>
        </template>
        <!-- Renseigné par l'API pour les visiteurs connectés uniquement. -->
        <template v-if="community && deck.missing_cards !== undefined && deck.missing_cards !== null">
          <span v-if="deck.missing_cards === 0" class="deck-card-complete" title="Vous possédez toutes les cartes">
            Complet
          </span>
          <span v-else class="deck-card-missing" :title="PRICE_NOTE">{{ missingNote(deck) }}</span>
        </template>
      </p>

      <div class="deck-card-foot">
        <span
          v-if="score"
          class="deck-card-record"
          :title="`Parties suivies : ${score.won} victoire(s), ${score.lost} défaite(s)`"
        >
          {{ score.won }} V · {{ score.lost }} D
        </span>
        <button
          v-if="community"
          type="button"
          class="deck-card-stat deck-card-like"
          :class="{ 'deck-card-like--on': deck.liked_by_me }"
          :aria-pressed="Boolean(deck.liked_by_me)"
          :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
          :disabled="likeBusy"
          @click.stop.prevent="$emit('like', deck)"
        >
          <Icon name="heart" :size="16" />
          {{ deck.likes ?? 0 }}
        </button>
        <span v-else class="deck-card-stat" :title="`${deck.likes ?? 0} j'aime`">
          <Icon name="heart" :size="16" />
          {{ deck.likes ?? 0 }}
        </span>
        <span v-if="community" class="deck-card-stat" :title="`${deck.views ?? 0} vue(s)`">
          <Icon name="eye" :size="16" />
          {{ deck.views ?? 0 }}
        </span>
        <RiftButton
          v-if="mine"
          class="deck-card-remove"
          variant="ghost"
          size="sm"
          @click.stop.prevent="$emit('remove', deck)"
        >
          Supprimer
        </RiftButton>
      </div>
    </div>
  </article>
</template>

<style scoped>
.deck-card {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: var(--space-4);
  min-width: 0;
  aspect-ratio: 5 / 7;
  padding: var(--space-3);
  overflow: hidden;
  color: var(--ink);
  background-color: var(--bg);
  /* Voile --bg : transparent en haut, opaque sur le dernier tiers ; l'illustration
     est cadrée sur le haut de la carte. */
  background-image: linear-gradient(180deg, transparent 0%, transparent 34%, var(--bg) 78%), var(--cover, none);
  background-size: cover;
  background-position:
    center,
    center 18%;
  background-repeat: no-repeat;
  border: 1px solid var(--line);
  clip-path: polygon(
    var(--cut) 0,
    100% 0,
    100% calc(100% - var(--cut)),
    calc(100% - var(--cut)) 100%,
    0 100%,
    0 var(--cut)
  );
  transition:
    border-color var(--t-fast),
    transform var(--t-fast);
}
/* Liseré aux deux couleurs des domaines de la légende. */
.deck-card::before {
  content: "";
  position: absolute;
  inset: 0 0 auto;
  height: 2px;
  background: linear-gradient(90deg, var(--d1), var(--d2));
  z-index: 1;
}
.deck-card:hover,
.deck-card:focus-within {
  border-color: var(--bronze);
  transform: translateY(-2px);
}
/* Sans légende : fond creusé, filets de bronze en diagonale. */
.deck-card--blank {
  background-color: var(--bg-sunken);
  background-image: repeating-linear-gradient(135deg, transparent 0 14px, rgba(138, 110, 75, 0.18) 14px 15px);
}
.deck-card-nolegend {
  position: absolute;
  inset: 22% 0 auto;
  text-align: center;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
/* Lien principal : son pseudo-élément couvre toute la fiche. */
.deck-card-link {
  position: absolute;
  inset: 0;
}
.deck-card-link::after {
  content: "";
  position: absolute;
  inset: 0;
}
.deck-card-link:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -4px;
}
/* Le texte laisse passer le clic jusqu'au lien principal. */
.deck-card-top,
.deck-card-body {
  position: relative;
  pointer-events: none;
}
.deck-card-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--space-2);
  padding-top: var(--space-1);
}
.deck-card-runes {
  display: inline-flex;
  gap: var(--space-1);
}
.deck-card-runes img {
  width: 22px;
  height: 22px;
}
.deck-card-body {
  display: grid;
  gap: var(--space-1);
  min-width: 0;
}
.deck-card-title {
  margin: 0;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.3;
  color: var(--ink);
}
.deck-card-legend {
  margin: 0;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.06em;
  color: var(--bronze-light);
}
.deck-card-legend--none {
  color: var(--ink-muted);
}
.deck-card-why {
  margin: 0;
  font-family: var(--font-body);
  font-size: 13px;
  line-height: 1.35;
  color: var(--blood-text);
}
.deck-card-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-1) var(--space-2);
  margin: 0;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.04em;
  color: var(--ink-muted);
}
.deck-card-owner {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
}
/* Contrôles interactifs : au-dessus du lien principal. */
.deck-card-author,
.deck-card-stat,
.deck-card-remove {
  position: relative;
  z-index: 1;
  pointer-events: auto;
}
.deck-card-author,
.deck-card-price,
.deck-card-complete {
  color: var(--bronze-light);
}
.deck-card-pending,
.deck-card-missing {
  color: var(--blood-text);
}
.deck-card-foot {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2) var(--space-3);
  margin-top: var(--space-1);
}
.deck-card-record {
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.06em;
  color: var(--ink);
}
.deck-card-stat {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  font-family: var(--font-label);
  font-size: 14px;
  color: var(--ink-muted);
}
.deck-card-like {
  min-width: 44px;
  min-height: 44px;
  padding: 0 var(--space-2);
  background: none;
  border: 0;
  cursor: pointer;
  transition: color var(--t-fast);
}
.deck-card-like:hover,
.deck-card-like:focus-visible,
.deck-card-like--on {
  color: var(--blood-text);
}
.deck-card-like:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.deck-card-like:disabled {
  opacity: 0.6;
  cursor: wait;
}
.deck-card-remove {
  margin-left: auto;
}
@media (prefers-reduced-motion: reduce) {
  .deck-card {
    transition: none;
  }
  .deck-card:hover,
  .deck-card:focus-within {
    transform: none;
  }
}
</style>
