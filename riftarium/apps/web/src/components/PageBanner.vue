<script setup>
import { computed } from "vue"

const props = defineProps({
  art: { type: String, required: true },
  title: { type: String, required: true },
  eyebrow: { type: String, default: "" },
  /* Le titre n'est affiché que sur les pages où il porte une information que la
     navigation ne donne pas (une mécanique, un document légal). Ailleurs il
     répète l'entrée de menu : il reste dans le DOM pour les lecteurs d'écran et
     le référencement, mais n'occupe plus le haut de page. */
  showTitle: { type: Boolean, default: false }
})

const bannerStyle = computed(() => ({ "--banner": `url("${props.art}")` }))
</script>

<template>
  <div class="page-banner" :class="{ 'has-title': showTitle }" :style="bannerStyle">
    <div class="wrap">
      <p v-if="eyebrow || $slots.eyebrow" class="eyebrow">
        <slot name="eyebrow">{{ eyebrow }}</slot>
      </p>
      <h2 :class="{ 'sr-only': !showTitle }">{{ title }}</h2>
      <slot name="meta" />
      <slot name="after" />
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </div>
</template>
