<script setup>
import { computed } from "vue"
import { DOMAINS } from "../api.js"
import {
  domainFilterOptions,
  energyFilterOptions,
  rarityFilterOptions,
  toggleValue,
  typeFilterOptions
} from "../cardText.js"
import RiftChip from "../ui/RiftChip.vue"
import RiftField from "../ui/RiftField.vue"

/* Contenu du panneau de filtres de la cartothèque : la recherche, puis une facette par
   fieldset, options en puces à bascule. L'état vit dans useQuerySyncedFilters (URL). */
const props = defineProps({
  state: { type: Object, required: true },
  sets: { type: Array, default: () => [] },
  /* Quand la page a déjà sa propre barre de recherche (galerie de l'éditeur de deck). */
  hideSearch: { type: Boolean, default: false }
})
const emit = defineEmits(["update"])

const facets = computed(() => [
  { key: "domain", label: "Domaines", options: domainFilterOptions() },
  { key: "type", label: "Types", options: typeFilterOptions() },
  { key: "rarity", label: "Raretés", options: rarityFilterOptions() },
  { key: "energy", label: "Coût", options: energyFilterOptions() },
  { key: "set_id", label: "Sets", options: props.sets }
])

function toggle(key, value) {
  emit("update", key, toggleValue(props.state[key], value))
}
</script>

<template>
  <div class="card-filters">
    <RiftField
      v-if="!hideSearch"
      search
      hide-label
      label="Rechercher une carte"
      placeholder="Jinx, ogn-202, reaction…"
      :model-value="state.q"
      inputmode="search"
      enterkeyhint="search"
      autocapitalize="off"
      autocorrect="off"
      spellcheck="false"
      @update:model-value="emit('update', 'q', $event)"
    />
    <fieldset v-for="facet in facets" :key="facet.key" class="facet">
      <legend>{{ facet.label }}</legend>
      <div class="facet-options">
        <RiftChip
          v-for="option in facet.options"
          :key="option.value"
          :label="option.label"
          :glyph="option.glyph"
          :glyph-kind="option.glyphKind"
          :color="facet.key === 'domain' ? DOMAINS[option.value]?.color : ''"
          :selected="state[facet.key].includes(option.value)"
          @toggle="toggle(facet.key, option.value)"
        />
      </div>
    </fieldset>
  </div>
</template>

<style scoped>
.card-filters {
  display: grid;
  gap: var(--space-4);
}
.facet {
  border: none;
}
.facet legend {
  margin-bottom: var(--space-2);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.facet-options {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1);
}
</style>
