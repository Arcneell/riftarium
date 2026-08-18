<script setup>
import { computed, onUnmounted, ref } from "vue"
import { cardThumb } from "../api.js"
import { isFoil, variantLabel } from "../cardText.js"
import CardText from "./CardText.vue"

const props = defineProps({
  card: { type: Object, required: true },
  disabled: { type: Boolean, default: false }
})

const HOVER_DELAY = 450

const visible = ref(false)
const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
const fine = window.matchMedia("(hover: hover) and (pointer: fine)").matches
let timer = 0

function show() {
  if (props.disabled || !fine) return
  clearTimeout(timer)
  timer = window.setTimeout(
    () => {
      visible.value = true
    },
    reduced ? 0 : HOVER_DELAY
  )
}

function hide() {
  clearTimeout(timer)
  visible.value = false
}

onUnmounted(() => clearTimeout(timer))

const foil = computed(() => isFoil(props.card))
</script>

<template>
  <div
    class="card-hover"
    :class="{ landscape: card.orientation === 'landscape' }"
    @mouseenter="show"
    @mouseleave="hide"
    @focusin="show"
    @focusout="hide"
  >
    <slot />
    <Teleport to="body">
      <div
        v-if="visible"
        class="card-preview"
        :class="{ instant: reduced, landscape: card.orientation === 'landscape' }"
        role="dialog"
        :aria-label="card.name"
      >
        <div class="card-art" :class="{ foil }">
          <img :src="cardThumb(card.image_url, 460)" :alt="`Aperçu : ${card.name}`" />
          <span v-if="foil" class="card-foil"></span>
        </div>
        <div class="preview-copy">
          <p class="eyebrow">{{ variantLabel(card) }}</p>
          <h3>{{ card.name }}</h3>
          <CardText v-if="card.text" :text="card.text" />
        </div>
      </div>
    </Teleport>
  </div>
</template>
