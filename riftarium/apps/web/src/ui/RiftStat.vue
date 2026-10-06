<script setup>
/* Statistique de jeu : glyphe officiel Riot, valeur en Cinzel, étiquette en capitales. */
defineProps({
  label: { type: String, required: true },
  value: { type: [Number, String], default: null },
  glyph: { type: String, default: "" },
  glyphKind: { type: String, default: "" },
  ink: { type: Boolean, default: false }
})
</script>

<template>
  <div class="rift-stat">
    <span class="rift-stat-glyphs">
      <slot>
        <span
          v-if="glyph && ink"
          class="rb-glyph ink"
          :style="{ '--glyph': `url(${glyph})` }"
          role="img"
          :aria-label="label"
        ></span>
        <img v-else-if="glyph" class="rb-glyph" :class="glyphKind" :src="glyph" :alt="label" width="26" height="26" />
      </slot>
      <b v-if="value !== null && value !== ''" class="rift-stat-value">{{ value }}</b>
    </span>
    <span class="rift-stat-label">{{ label }}</span>
  </div>
</template>

<style scoped>
.rift-stat {
  display: grid;
  gap: var(--space-1);
  min-width: 88px;
  padding: var(--space-2) var(--space-3);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
  clip-path: polygon(8px 0, 100% 0, 100% calc(100% - 8px), calc(100% - 8px) 100%, 0 100%, 0 8px);
}
.rift-stat-glyphs {
  display: flex;
  align-items: center;
  gap: var(--space-1);
  min-height: 28px;
  font-size: 24px;
}
.rift-stat-value {
  font-family: var(--font-display);
  font-size: 24px;
  font-weight: 900;
  color: var(--ink);
}
.rift-stat-label {
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
</style>
