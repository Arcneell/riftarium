<script setup>
/* Une partie de texte de jeu : texte brut, pastille de mot-clé ou glyphe officiel Riot.
   Les glyphes « ink » (puissance, épuisement) sont blancs à l'origine : teintés par masque. */
defineProps({ part: { type: Object, required: true } })
</script>

<template>
  <span v-if="part.type === 'text'">{{ part.value }}</span>
  <button v-else-if="part.type === 'ref'" type="button" class="rift-ref" :data-ref="part.ref">{{ part.value }}</button>
  <span v-else-if="part.type === 'keyword'" class="rb-kw" :class="[part.family, { arrow: part.arrow }]">{{
    part.label
  }}</span>
  <span
    v-else-if="part.kind === 'ink'"
    class="rb-glyph ink"
    :style="{ '--glyph': `url(${part.src})` }"
    role="img"
    :aria-label="part.label"
    :title="part.label"
  ></span>
  <img
    v-else
    class="rb-glyph"
    :class="part.kind"
    :src="part.src"
    :alt="part.label"
    :title="part.label"
    width="18"
    height="18"
    loading="lazy"
  />
</template>

<style scoped>
.rift-ref {
  display: inline;
  padding: 0;
  border: 0;
  border-bottom: 1px dotted var(--bronze-light);
  background: none;
  color: inherit;
  font: inherit;
  cursor: pointer;
  transition: color 0.15s;
}
.rift-ref:hover {
  color: var(--bronze-light);
}
.rift-ref:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
@media (hover: none) {
  .rift-ref {
    display: inline-flex;
    align-items: center;
    min-height: 44px;
  }
}
</style>
