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
    class="rift-avatar"
    :class="{ landscape: orientation === 'landscape', empty: !src }"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${size}px` }"
    :title="handle"
  >
    <!-- Chargement différé : la page profil aligne 50+ portraits dans un défileur,
         inutile de les télécharger tous avant que le lecteur y arrive. -->
    <img v-if="src" :src="cardThumb(src, Math.max(96, size * 3))" alt="" loading="lazy" decoding="async" />
    <span v-else class="rift-avatar-fallback">{{ (handle || "?").slice(0, 1).toUpperCase() }}</span>
  </span>
</template>

<style scoped>
/* Portrait rond de la Forge : liseré bronze de 1 px, repli sombre avec l'initiale
   en Cinzel. Classes rift-avatar* : `.avatar` (main.css) fuirait ses bordures dorées. */
.rift-avatar {
  display: inline-grid;
  place-items: center;
  overflow: hidden;
  border-radius: 50%;
  background: var(--bg-sunken);
  border: 1px solid var(--bronze);
  box-shadow: none;
  flex-shrink: 0;
}
.rift-avatar img {
  width: 100%;
  height: 100%;
  max-width: none;
  object-fit: cover;
  object-position: 50% 16%;
  transform: scale(1.45);
}
.rift-avatar.landscape img {
  object-position: 48% 42%;
  transform: scale(1.7);
}
.rift-avatar-fallback {
  font-family: var(--font-display);
  font-weight: 700;
  /* 0.42em d'une pastille de 22 px = 9 px : plancher absolu pour rester lisible. */
  font-size: max(10px, 0.42em);
  color: var(--bronze-light);
  line-height: 1;
}
</style>
