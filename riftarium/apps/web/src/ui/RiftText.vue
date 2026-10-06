<script setup>
import { computed } from "vue"
import RiftGlyph from "./RiftGlyph.vue"
import { richSegments } from "./richText.js"

/* Seul rendu du texte de jeu du site : cartes (`tag="p"`), règles (`rules`), aide. */
const props = defineProps({
  text: { type: String, default: "" },
  tag: { type: String, default: "span" },
  rules: { type: Boolean, default: false }
})
const segments = computed(() => richSegments(props.text, { rules: props.rules }))
</script>

<template>
  <component :is="tag" class="rift-text">
    <component :is="segment.bold ? 'b' : 'span'" v-for="(segment, s) in segments" :key="s">
      <RiftGlyph v-for="part in segment.parts" :key="part.key" :part="part" />
    </component>
  </component>
</template>
