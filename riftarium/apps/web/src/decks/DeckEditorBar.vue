<script setup>
import { FORMAT_OPTIONS } from "../deckDisplay.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import { pluralWord } from "../ui/french.js"

/* Barre d'édition d'un deck (édition seulement : la lecture passe par DeckView) : nom, format, visibilité, mentions et état de sauvegarde.
   Elle ne modifie pas `deck` : la page applique les changements émis. */
defineProps({
  deck: { type: Object, required: true },
  canEdit: { type: Boolean, default: false },
  saveState: { type: String, default: "" },
  error: { type: String, default: "" },
  likeBusy: { type: Boolean, default: false }
})
const emit = defineEmits(["like", "export", "update:name", "update:format", "update:public"])
</script>

<template>
  <div class="atelier-bar">
    <RouterLink to="/decks" class="atelier-back">← Mes decks</RouterLink>
    <input
      v-if="canEdit"
      type="text"
      class="atelier-name"
      maxlength="80"
      aria-label="Nom du deck"
      :value="deck.name"
      @input="emit('update:name', $event.target.value)"
    />
    <RiftChoice
      v-if="canEdit"
      label="Format"
      :options="FORMAT_OPTIONS"
      :model-value="deck.format"
      @update:model-value="emit('update:format', $event)"
    />
    <RiftChip
      v-if="canEdit"
      label="Public"
      :selected="Boolean(deck.is_public)"
      @toggle="emit('update:public', !deck.is_public)"
    />
    <div class="atelier-stats">
      <button
        v-if="deck.is_public && deck.moderation_status === 'published'"
        type="button"
        class="atelier-stat atelier-like"
        :class="{ liked: deck.liked_by_me }"
        :aria-pressed="String(Boolean(deck.liked_by_me))"
        :aria-label="deck.liked_by_me ? 'Ne plus aimer' : 'Aimer ce deck'"
        :disabled="likeBusy"
        @click="emit('like')"
      >
        <Icon name="heart" :size="16" />
        {{ deck.likes }}
      </button>
      <span class="atelier-stat" :title="`${deck.views ?? 0} ${pluralWord(deck.views, 'vue', 'vues')}`">
        <Icon name="eye" :size="16" />
        {{ deck.views ?? 0 }}
      </span>
    </div>
    <RiftButton variant="ghost" size="sm" @click="emit('export')">Exporter</RiftButton>
    <!-- `idle` : sous 1100 px cette mention devient un toast fixe, qui ne doit pas flotter
         à vide entre deux sauvegardes. -->
    <span v-if="canEdit" class="atelier-save" :class="[saveState, { idle: !saveState }]" role="status">
      <template v-if="saveState === 'saving'">Enregistrement…</template>
      <template v-else-if="saveState === 'saved'">Enregistré</template>
      <template v-else-if="saveState === 'error'">Échec de l'enregistrement</template>
    </span>
    <span v-if="error" class="atelier-error">{{ error }}</span>
  </div>
</template>

<style scoped>
.atelier-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3) var(--space-4);
}
.atelier-back {
  white-space: nowrap;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-muted);
  text-decoration: none;
}
.atelier-back:hover {
  color: var(--ink);
}
.atelier-back:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
/* Nom : champ sans cadre, filet bas. `min-width: 0` laisse un nom long rétrécir
   dans la ligne au lieu de la faire déborder. */
.atelier-name {
  flex: 1 1 200px;
  min-width: 0;
  max-width: 360px;
  width: auto;
  padding: var(--space-1) 0;
  border: none;
  border-bottom: 1px solid var(--line);
  border-radius: 0;
  background: transparent;
  box-shadow: none;
  font-family: var(--font-display);
  font-size: 20px;
  font-weight: 700;
  color: var(--ink);
  outline: none;
  transition: border-color var(--t-fast);
}
.atelier-name:focus {
  border-bottom-color: var(--bronze-light);
  box-shadow: none;
}
.atelier-stats {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}
.atelier-stat {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  font-family: var(--font-label);
  font-size: 15px;
  color: var(--ink-muted);
}
/* Bouton redéfini ici : fond, filet et curseur ne viennent pas du style de base. */
.atelier-like {
  min-height: 44px;
  min-width: 44px;
  padding: 0 var(--space-2);
  border: none;
  border-radius: 0;
  background: none;
  box-shadow: none;
  cursor: pointer;
}
.atelier-like:hover,
.atelier-like.liked {
  color: var(--blood-text);
}
.atelier-like:focus-visible {
  outline: 2px solid var(--bronze-light);
}
.atelier-save {
  margin: 0;
  min-width: 130px;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.06em;
  color: var(--ink-muted);
}
.atelier-save.saved {
  color: var(--bronze-light);
}
.atelier-save.error {
  color: var(--blood-text);
}
.atelier-error {
  font-size: 14px;
  color: var(--blood-text);
}

/* Sous 1100 px la mention d'état devient un toast au-dessus des onglets du bas. */
@media (max-width: 1100px) {
  .atelier-save:not(.idle) {
    position: fixed;
    left: var(--space-3);
    right: var(--space-3);
    /* --shell-bottom contient déjà la barre d'onglets et la zone de sécurité (tokens.css). */
    bottom: calc(var(--shell-bottom, env(safe-area-inset-bottom, 0px)) + var(--space-3));
    /* Juste sous les modales. */
    z-index: calc(var(--z-overlay) - 1);
    min-width: 0;
    padding: var(--space-3) var(--space-4);
    background: var(--bg-raised);
    box-shadow:
      inset 0 0 0 1px var(--bronze),
      var(--shadow-deep);
    text-align: center;
  }
  .atelier-save.idle {
    display: none;
  }
}
</style>
