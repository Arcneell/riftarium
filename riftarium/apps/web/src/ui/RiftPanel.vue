<script setup>
import { computed, useId, useSlots } from "vue"

/* Bloc de la Forge : plaque à angles coupés, filet de bronze, liseré d'accent en
   haut, intertitre Cinzel prolongé d'un filet qui s'efface. */
const props = defineProps({
  title: { type: String, default: "" },
  tag: { type: String, default: "section" },
  accent: { type: String, default: "" }
})
const slots = useSlots()
const titleId = `${useId()}-title`
const hasTitle = computed(() => Boolean(props.title || slots.title))
const style = computed(() => (props.accent ? { "--panel-accent": props.accent } : undefined))
</script>

<template>
  <component :is="tag" class="rift-panel" :style="style" :aria-labelledby="hasTitle ? titleId : undefined">
    <h2 v-if="hasTitle" :id="titleId" class="rift-panel-title">
      <slot name="title">{{ title }}</slot>
    </h2>
    <slot />
  </component>
</template>

<style scoped>
.rift-panel {
  --panel-accent: var(--blood);
  position: relative;
  padding: var(--space-5);
  background: var(--bg-raised);
  border-top: 2px solid var(--panel-accent);
  box-shadow: inset 0 0 0 1px var(--line);
  clip-path: polygon(
    var(--cut) 0,
    100% 0,
    100% calc(100% - var(--cut)),
    calc(100% - var(--cut)) 100%,
    0 100%,
    0 var(--cut)
  );
}
.rift-panel-title {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  margin: 0 0 var(--space-3);
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.rift-panel-title::after {
  content: "";
  flex: 1;
  height: 1px;
  background: linear-gradient(90deg, var(--bronze), transparent);
}
</style>
