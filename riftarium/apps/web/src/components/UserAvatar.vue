<script setup>
import { cardThumb } from "../api.js"

defineProps({
  src: { type: String, default: "" },
  handle: { type: String, default: "" },
  size: { type: Number, default: 40 },
  orientation: { type: String, default: "" }
})
</script>

<template>
  <span
    class="avatar"
    :class="{ landscape: orientation === 'landscape', empty: !src }"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${size}px` }"
    :title="handle"
  >
    <!-- Chargement différé : la page profil aligne 50+ portraits dans un défileur,
         inutile de les télécharger tous avant que le lecteur y arrive. -->
    <img v-if="src" :src="cardThumb(src, Math.max(96, size * 3))" alt="" loading="lazy" decoding="async" />
    <span v-else class="avatar-fallback">{{ (handle || "?").slice(0, 1).toUpperCase() }}</span>
  </span>
</template>
