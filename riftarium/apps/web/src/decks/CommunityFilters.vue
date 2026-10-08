<script setup>
import { computed } from "vue"
import { DOMAINS } from "../api.js"
import { domainFilterOptions, toggleValue } from "../cardText.js"
import { FORMAT_OPTIONS } from "../deckDisplay.js"
import RiftChip from "../ui/RiftChip.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftField from "../ui/RiftField.vue"
import LegendPicker from "./LegendPicker.vue"

/* Contenu du panneau de filtres de la communauté : recherche, tri, puis une facette par
   fieldset en puces à bascule. L'état vit dans useQuerySyncedFilters (URL). */
const props = defineProps({
  state: { type: Object, required: true },
  legends: { type: Array, default: () => [] }, // [{ id, name, image_url, deck_count }]
  signedIn: { type: Boolean, default: false }
})
const emit = defineEmits(["update", "liked"])

const SORTS = [
  { value: "likes", label: "Tendance" },
  { value: "views", label: "Plus vus" },
  { value: "recent", label: "Récents" }
]

const domainOptions = computed(() => domainFilterOptions())

function toggle(key, value) {
  emit("update", key, toggleValue(props.state[key], value))
}
</script>

<template>
  <div class="communaute-filters-body">
    <RiftField
      search
      hide-label
      label="Rechercher un deck"
      placeholder="Nom, auteur, légende…"
      :model-value="state.q"
      inputmode="search"
      enterkeyhint="search"
      autocapitalize="off"
      autocorrect="off"
      spellcheck="false"
      @update:model-value="emit('update', 'q', $event)"
    />

    <fieldset class="communaute-facet">
      <legend>Trier</legend>
      <RiftChoice
        label="Trier les decks"
        :options="SORTS"
        :model-value="state.sort"
        @update:model-value="emit('update', 'sort', $event)"
      />
    </fieldset>

    <fieldset v-if="legends.length" class="communaute-facet">
      <legend>Légendes</legend>
      <LegendPicker
        :legends="legends"
        :model-value="state.legend"
        @update:model-value="emit('update', 'legend', $event)"
      />
    </fieldset>

    <fieldset class="communaute-facet">
      <legend>Domaines</legend>
      <div class="communaute-facet-options">
        <RiftChip
          v-for="option in domainOptions"
          :key="option.value"
          :label="option.label"
          :glyph="option.glyph"
          :glyph-kind="option.glyphKind"
          :color="DOMAINS[option.value]?.color"
          :selected="state.domain.includes(option.value)"
          @toggle="toggle('domain', option.value)"
        />
      </div>
    </fieldset>

    <fieldset class="communaute-facet">
      <legend>Format</legend>
      <div class="communaute-facet-options">
        <RiftChip
          v-for="option in FORMAT_OPTIONS"
          :key="option.value"
          :label="option.label"
          :selected="state.format.includes(option.value)"
          @toggle="toggle('format', option.value)"
        />
      </div>
    </fieldset>

    <fieldset class="communaute-facet">
      <legend>Mes decks aimés</legend>
      <div class="communaute-facet-options">
        <RiftChip label="Aimés" :selected="state.liked" @toggle="emit('liked')" />
      </div>
    </fieldset>

    <!-- Réservé aux connectés : la comparaison se fait avec leur collection. -->
    <fieldset v-if="signedIn" class="communaute-facet">
      <legend>Collection</legend>
      <div class="communaute-facet-options">
        <RiftChip
          label="Constructibles avec ma collection"
          :selected="state.buildable"
          @toggle="emit('update', 'buildable', !state.buildable)"
        />
      </div>
    </fieldset>
  </div>
</template>

<style scoped>
.communaute-filters-body {
  display: grid;
  gap: var(--space-4);
}
.communaute-facet {
  display: grid;
  gap: var(--space-2);
  min-width: 0;
  margin: 0;
  padding: 0;
  border: none;
}
.communaute-facet legend {
  margin-bottom: var(--space-2);
  padding: 0;
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.communaute-facet-options {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}
</style>
