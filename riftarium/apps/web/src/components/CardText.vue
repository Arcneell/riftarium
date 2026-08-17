<script setup>
import { computed } from "vue"
import { parseCardText } from "../cardText.js"

const props = defineProps({ text: { type: String, default: "" } })
const parts = computed(() => parseCardText(props.text))
</script>

<template>
  <p class="card-text">
    <template v-for="(part, i) in parts" :key="i">
      <span v-if="part.type === 'text'">{{ part.value }}</span>
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
  </p>
</template>
