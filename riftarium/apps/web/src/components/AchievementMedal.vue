<script setup>
import { achievementGlyph } from "../social.js"

/* Gemme hexagonale d'un haut fait : la forme reprend la gemme hex des
   impressions alternatives Riftbound, le palier donne le matériau (cuivre,
   acier, or, prisme irisé). Décorative : le libellé du palier reste écrit
   à côté (le sens ne repose pas sur la couleur). */
defineProps({
  icon: { type: String, default: "" },
  tier: { type: String, default: "bronze" },
  locked: { type: Boolean, default: false }
})
</script>

<template>
  <span class="gem" :class="[`gem-${tier || 'bronze'}`, { locked }]" aria-hidden="true">
    <i class="gem-face"></i>
    <i class="gem-foil"></i>
    <span class="gem-glyph">{{ achievementGlyph(icon) }}</span>
  </span>
</template>
