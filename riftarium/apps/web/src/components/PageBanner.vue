<script setup>
import { computed } from "vue"

const props = defineProps({
  art: { type: String, required: true },
  title: { type: String, required: true },
  eyebrow: { type: String, default: "" }
})

const bannerStyle = computed(() => ({ "--banner": `url("${props.art}")` }))
</script>

<template>
  <div class="page-banner" :style="bannerStyle">
    <div class="wrap">
      <p v-if="eyebrow || $slots.eyebrow" class="eyebrow">
        <slot name="eyebrow">{{ eyebrow }}</slot>
      </p>
      <h2>{{ title }}</h2>
      <slot name="meta" />
      <p v-if="$slots.default" class="lead"><slot /></p>
      <slot name="after" />
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </div>
</template>
