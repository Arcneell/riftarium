<script setup>
import { ref } from "vue"
import { cardThumb } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"

/* Liste du deck de l'éditeur : vitrine de la légende, compteurs par zone et lignes
   compactes. Sa racine sert de zone de dépôt au glisser-déposer (useDeckDrag). Composant
   de présentation : les règles (plafonds, légende) restent dans useDeckRules. */
defineProps({
  deck: { type: Object, required: true },
  canEdit: { type: Boolean, default: false },
  zones: { type: Array, required: true },
  listZones: { type: Array, required: true },
  grouped: { type: Object, required: true },
  zoneCounts: { type: Object, required: true },
  legendEntry: { type: Object, default: null },
  legendRunes: { type: Array, default: () => [] },
  flashes: { type: Object, required: true },
  limitMessage: { type: String, default: "" },
  missingInDeck: { type: Number, default: 0 },
  drag: { type: Object, required: true },
  finePointer: { type: Boolean, default: false },
  signedIn: { type: Boolean, default: false }
})
const emit = defineEmits(["set-qty", "remove-one", "show-legends", "row-pointerdown", "preview", "hide-preview"])

const panel = ref(null)
defineExpose({ panel })

const isLacking = (entry, signedIn) => signedIn && (entry.card.owned_qty ?? 0) < entry.qty
const lackCount = (entry) => entry.qty - (entry.card.owned_qty ?? 0)
</script>

<template>
  <aside
    ref="panel"
    class="decklist"
    :class="{ 'decklist-hot': drag.active && drag.from === 'gallery' && drag.overDeck }"
  >
    <div
      v-if="drag.active && drag.from === 'gallery'"
      class="decklist-drop"
      :class="{ hot: drag.overDeck }"
      aria-hidden="true"
    >
      <span>Déposez ici</span>
    </div>

    <div
      v-if="legendEntry"
      class="decklist-hero"
      :style="{ '--hero-art': `url(${cardThumb(legendEntry.card.image_url, 480)})` }"
      @mouseenter="emit('preview', legendEntry.card, $event)"
      @mouseleave="emit('hide-preview')"
    >
      <div class="decklist-hero-copy">
        <p class="decklist-hero-label">Légende</p>
        <h3 class="decklist-hero-name">{{ legendEntry.card.name }}</h3>
        <div class="decklist-hero-runes">
          <img
            v-for="rune in legendRunes"
            :key="rune.domain"
            :src="rune.src"
            :alt="rune.label"
            :title="rune.label"
            width="26"
            height="26"
          />
        </div>
      </div>
      <button
        v-if="canEdit"
        type="button"
        class="decklist-hero-remove"
        aria-label="Retirer la légende du deck"
        @click="emit('remove-one', legendEntry.card.id)"
      >
        ✕
      </button>
    </div>
    <div v-else class="decklist-hero decklist-hero--empty">
      <p v-if="canEdit"><b>1.</b> Choisissez votre légende : elle fixe les deux domaines du deck.</p>
      <p v-else>Ce deck n'a pas encore de légende.</p>
      <RiftButton v-if="canEdit" variant="ghost" size="sm" @click="emit('show-legends')">Voir les légendes</RiftButton>
    </div>

    <div class="decklist-meters">
      <div
        v-for="zone in zones"
        :key="zone.key"
        class="decklist-meter"
        :class="{ full: zoneCounts[zone.key] >= zone.target }"
      >
        <b
          >{{ zoneCounts[zone.key] }}<small>/{{ zone.target }}{{ zone.key === "main" ? "+" : "" }}</small></b
        >
        <span>{{ zone.label }}</span>
        <i
          class="decklist-meter-bar"
          :style="{ width: `${Math.min(100, (zoneCounts[zone.key] / zone.target) * 100)}%` }"
          aria-hidden="true"
        ></i>
      </div>
    </div>

    <p v-if="limitMessage" class="decklist-message" role="status">{{ limitMessage }}</p>
    <p v-else-if="missingInDeck" class="decklist-message decklist-message--soft" role="status">
      {{ missingInDeck }} carte(s) du deck manquent à votre collection.
    </p>

    <div class="decklist-scroll">
      <template v-for="zone in listZones" :key="zone.key">
        <h3 class="decklist-zone">
          {{ zone.label }} <small>{{ zoneCounts[zone.key] }}</small>
        </h3>
        <TransitionGroup name="decklist-row" tag="div" class="decklist-rows">
          <div
            v-for="entry in grouped[zone.key]"
            :key="entry.card.id"
            class="decklist-row"
            :class="{ flash: flashes.has(entry.card.id), lacking: isLacking(entry, signedIn) }"
            :data-row="entry.card.id"
            :style="{ '--row-art': `url(${cardThumb(entry.card.image_url, 200)})` }"
            @pointerdown="emit('row-pointerdown', entry.card, $event)"
            @mouseenter="emit('preview', entry.card, $event)"
            @mouseleave="emit('hide-preview')"
          >
            <span v-if="entry.card.energy != null" class="decklist-cost">{{ entry.card.energy }}</span>
            <span v-else class="decklist-cost decklist-cost--none"></span>
            <span class="decklist-name">{{ entry.card.name }}</span>
            <!-- Texte plutôt qu'un « ! » : l'infobulle qui l'expliquait ne s'ouvre pas au doigt. -->
            <span
              v-if="isLacking(entry, signedIn)"
              class="decklist-lack"
              :title="`${lackCount(entry)} exemplaire(s) manquant(s) dans votre collection`"
              >manque {{ lackCount(entry) }}</span
            >
            <span class="decklist-qty">×{{ entry.qty }}</span>
            <span v-if="canEdit" class="decklist-actions">
              <button
                type="button"
                :aria-label="`Retirer un exemplaire de ${entry.card.name}`"
                @click.stop="emit('set-qty', entry, -1)"
              >
                −
              </button>
              <button
                type="button"
                :aria-label="`Ajouter un exemplaire de ${entry.card.name}`"
                @click.stop="emit('set-qty', entry, 1)"
              >
                +
              </button>
            </span>
          </div>
        </TransitionGroup>
        <p v-if="!grouped[zone.key].length" class="decklist-empty">
          <!-- Au tactile le glisser-déposer est désactivé : c'est le tap qui ajoute. -->
          {{
            !canEdit
              ? "Aucune carte dans cette zone."
              : finePointer
                ? "Glissez des cartes ici."
                : "Touchez une carte de la galerie pour l'ajouter."
          }}
        </p>
      </template>
    </div>
  </aside>
</template>

<style scoped>
.decklist {
  position: relative;
  display: flex;
  flex-direction: column;
  min-height: 0;
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
  transition: box-shadow var(--t-base);
}
.decklist-hot {
  box-shadow: inset 0 0 0 2px var(--bronze-light);
}

/* Consigne de dépôt, posée sur toute la liste pendant un glisser depuis la galerie. */
.decklist-drop {
  position: absolute;
  inset: var(--space-2);
  z-index: 5;
  display: grid;
  place-items: center;
  border: 2px dashed var(--bronze);
  background: rgba(13, 13, 15, 0.82);
  pointer-events: none;
}
.decklist-drop.hot {
  border-style: solid;
  border-color: var(--bronze-light);
  background: rgba(13, 13, 15, 0.55);
}
.decklist-drop span {
  padding: var(--space-2) var(--space-5);
  background: var(--blood);
  color: #fff;
  font-family: var(--font-label);
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}

/* Vitrine de la légende */
.decklist-hero {
  position: relative;
  display: flex;
  align-items: flex-end;
  min-height: 118px;
  margin-bottom: var(--space-3);
  overflow: hidden;
  background:
    linear-gradient(to top, rgba(13, 13, 15, 0.94) 18%, rgba(13, 13, 15, 0.15) 60%, rgba(13, 13, 15, 0.35)),
    var(--hero-art) center 18% / cover no-repeat,
    var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--bronze);
}
.decklist-hero-copy {
  padding: var(--space-3) var(--space-4);
}
.decklist-hero-label {
  margin: 0 0 2px;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
/* h3 neutralisé localement : main.css le style globalement. */
.decklist-hero-name {
  margin: 0;
  font-family: var(--font-display);
  font-size: 17px;
  font-weight: 700;
  letter-spacing: 0.02em;
  line-height: 1.2;
  color: var(--ink);
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.9);
}
.decklist-hero-runes {
  display: flex;
  gap: 6px;
  margin-top: 6px;
}
.decklist-hero-runes img {
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.8));
}
/* Bouton neutralisé localement : main.css stylise `button` globalement. */
.decklist-hero-remove {
  position: absolute;
  top: var(--space-2);
  right: var(--space-2);
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  padding: 0;
  border: none;
  border-radius: 0;
  background: rgba(13, 13, 15, 0.92);
  box-shadow: inset 0 0 0 1px var(--bronze);
  color: var(--ink);
  font-size: 12px;
  cursor: pointer;
  opacity: 0;
  transition: opacity var(--t-fast);
}
.decklist-hero:hover .decklist-hero-remove,
.decklist-hero-remove:focus-visible {
  opacity: 1;
}
.decklist-hero-remove:focus-visible {
  outline: 2px solid var(--bronze-light);
}
@media (hover: none) {
  .decklist-hero-remove {
    width: 44px;
    height: 44px;
    opacity: 1;
  }
}
.decklist-hero--empty {
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  padding: var(--space-4);
  background:
    repeating-linear-gradient(-45deg, rgba(138, 110, 75, 0.1) 0 12px, transparent 12px 24px), var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  font-size: 14px;
}
.decklist-hero--empty p {
  margin: 0;
  line-height: 1.45;
}

/* Compteurs par zone */
.decklist-meters {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: var(--space-2);
  margin-bottom: var(--space-3);
}
.decklist-meter {
  position: relative;
  overflow: hidden;
  padding: var(--space-2) var(--space-1);
  text-align: center;
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
}
.decklist-meter b {
  display: block;
  font-family: var(--font-display);
  font-size: 17px;
  line-height: 1.2;
  color: var(--ink);
}
.decklist-meter small {
  font-family: var(--font-label);
  font-size: 12px;
  color: var(--ink-muted);
}
.decklist-meter span {
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.decklist-meter-bar {
  position: absolute;
  left: 0;
  bottom: 0;
  height: 3px;
  background: var(--blood);
  transition: width var(--t-base);
}
.decklist-meter.full {
  box-shadow: inset 0 0 0 1px var(--blood);
}

.decklist-message {
  min-height: 1.4em;
  margin: 2px 0 var(--space-2);
  font-size: 14px;
  color: var(--blood-text);
}
.decklist-message--soft {
  color: var(--ink-muted);
}

/* Zones et lignes */
.decklist-scroll {
  min-height: 0;
  overflow-y: auto;
  padding-right: 6px;
  margin-right: -6px;
}
/* h3 neutralisé localement : marges, taille et couleur explicites. */
.decklist-zone {
  display: flex;
  align-items: baseline;
  gap: var(--space-2);
  margin: var(--space-5) 0 var(--space-2);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.16em;
  line-height: 1.2;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.decklist-zone:first-child {
  margin-top: var(--space-1);
}
.decklist-zone small {
  font-size: 13px;
  color: var(--ink-muted);
}
.decklist-zone::after {
  content: "";
  flex: 1;
  height: 1px;
  background: var(--line);
}
.decklist-empty {
  margin: 0;
  padding: var(--space-3);
  border: 1px dashed var(--line);
  font-size: 14px;
  text-align: center;
  color: var(--ink-muted);
}
.decklist-rows {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.decklist-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  height: 42px;
  padding: 0 10px;
  overflow: hidden;
  color: var(--ink);
  background:
    linear-gradient(90deg, rgba(13, 13, 15, 0.96) 34%, rgba(13, 13, 15, 0.6) 72%, rgba(13, 13, 15, 0.3)),
    var(--row-art) right 20% / 62% auto no-repeat,
    var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
  cursor: grab;
  user-select: none;
  transition:
    transform var(--t-fast),
    box-shadow var(--t-fast);
}
.decklist-row:hover {
  transform: translateX(-3px);
  box-shadow: inset 0 0 0 1px var(--bronze);
}
.decklist-row:active {
  cursor: grabbing;
}
.decklist-row.lacking {
  box-shadow: inset 0 0 0 1px var(--blood);
}
/* Éclat rouge à l'ajout : le filet intérieur s'éteint en 600 ms. */
.decklist-row.flash {
  animation: decklist-flash 600ms ease-out;
}
@keyframes decklist-flash {
  0% {
    box-shadow: inset 0 0 0 3px var(--blood);
  }
}
.decklist-cost {
  flex: none;
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  background: var(--bronze);
  clip-path: polygon(50% 0, 100% 50%, 50% 100%, 0 50%);
  color: #fff;
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 700;
}
.decklist-cost--none {
  background: transparent;
}
.decklist-name {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
  font-size: 14px;
  text-shadow: 0 1px 4px rgba(0, 0, 0, 0.9);
}
.decklist-lack {
  flex: none;
  white-space: nowrap;
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.decklist-qty {
  flex: none;
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  color: var(--bronze-light);
}
/* Masqués par l'opacité et non par display: none : les boutons restent dans l'ordre
   de tabulation, et réapparaissent dès que le focus clavier entre dans la ligne. */
.decklist-actions {
  flex: none;
  display: flex;
  gap: var(--space-1);
  opacity: 0;
  pointer-events: none;
  transition: opacity var(--t-fast);
}
.decklist-row:hover .decklist-actions,
.decklist-row:focus-within .decklist-actions {
  opacity: 1;
  pointer-events: auto;
}
/* Boutons neutralisés localement : main.css stylise `button` globalement. */
.decklist-actions button {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  padding: 0;
  border: none;
  border-radius: 0;
  background: rgba(13, 13, 15, 0.92);
  box-shadow: inset 0 0 0 1px var(--bronze);
  color: var(--ink);
  font-size: 16px;
  line-height: 1;
  cursor: pointer;
  transition: background-color var(--t-fast);
}
.decklist-actions button:hover {
  background: var(--bg-raised);
  color: var(--bronze-light);
}
.decklist-actions button:focus-visible {
  outline: 2px solid var(--bronze-light);
}
@media (hover: none) {
  /* Pas de survol au tactile : les boutons restent visibles, à taille de doigt. */
  .decklist-actions {
    opacity: 1;
    pointer-events: auto;
  }
  .decklist-actions button {
    width: 44px;
    height: 44px;
  }
  .decklist-row {
    height: 48px;
  }
}

.decklist-row-enter-from {
  opacity: 0;
  transform: translateY(-8px);
}
.decklist-row-leave-to {
  opacity: 0;
  transform: translateX(28px);
}
.decklist-row-enter-active,
.decklist-row-leave-active {
  transition:
    opacity 180ms,
    transform 180ms;
}
.decklist-row-leave-active {
  position: absolute;
  width: 100%;
}
.decklist-row-move {
  transition: transform 180ms;
}

@media (prefers-reduced-motion: reduce) {
  .decklist,
  .decklist-meter-bar,
  .decklist-row,
  .decklist-hero-remove,
  .decklist-actions,
  .decklist-row-enter-active,
  .decklist-row-leave-active,
  .decklist-row-move {
    transition: none;
  }
  .decklist-row.flash {
    animation: none;
  }
  .decklist-row:hover {
    transform: none;
  }
}
</style>
