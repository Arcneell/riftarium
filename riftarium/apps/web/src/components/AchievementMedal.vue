<script setup>
import { computed } from "vue"
import { achievementIconPaths } from "../achievementIcons.js"

/* Gemme hexagonale d'un haut fait : la forme reprend la gemme hex des
   impressions alternatives Riftbound, le palier donne le matériau (cuivre,
   acier, or, prisme irisé). L'icône est un tracé unique par haut fait
   (achievementIcons.js). Décorative : le libellé du palier reste écrit
   à côté (le sens ne repose pas sur la couleur). */
const props = defineProps({
  achievementKey: { type: String, default: "" },
  icon: { type: String, default: "" },
  tier: { type: String, default: "bronze" },
  locked: { type: Boolean, default: false }
})

const paths = computed(() => achievementIconPaths(props.achievementKey, props.icon))
</script>

<template>
  <span class="gem" :class="[`gem-${tier || 'bronze'}`, { locked }]" aria-hidden="true">
    <i class="gem-face"></i>
    <i class="gem-foil"></i>
    <svg class="gem-glyph" viewBox="0 0 24 24" fill="none">
      <path
        v-for="(d, i) in paths"
        :key="i"
        :d="d"
        stroke="currentColor"
        stroke-width="1.7"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
  </span>
</template>
