<script setup>
import { computed, nextTick, onMounted, ref } from "vue"
import { useRoute } from "vue-router"

/* Onglets de sous-rubriques. Sur téléphone ils défilent horizontalement ;
   l'onglet actif est ramené dans le champ au montage. */
const props = defineProps({
  items: { type: Array, required: true },
  label: { type: String, required: true }
})

const route = useRoute()
const list = ref(null)

/* Plus long préfixe : /regles/debutant/plateau active « Plateau animé », pas « Apprendre ». */
const activeTo = computed(() => {
  const path = route.path
  const matches = props.items.filter((item) => path === item.to || path.startsWith(`${item.to}/`))
  return matches.sort((a, b) => b.to.length - a.to.length)[0]?.to ?? null
})

onMounted(async () => {
  await nextTick()
  list.value?.querySelector(".active")?.scrollIntoView?.({ block: "nearest", inline: "center" })
})
</script>

<template>
  <nav class="rift-tabs" :aria-label="label">
    <ul ref="list">
      <li v-for="item in items" :key="item.to">
        <RouterLink
          :to="item.to"
          class="rift-tab"
          :class="{ active: item.to === activeTo }"
          :aria-current="item.to === activeTo ? 'page' : undefined"
          >{{ item.label }}</RouterLink
        >
      </li>
    </ul>
  </nav>
</template>

<style scoped>
.rift-tabs ul {
  display: flex;
  gap: var(--space-1);
  list-style: none;
  overflow-x: auto;
  scrollbar-width: none;
  border-bottom: 1px solid var(--line);
}
.rift-tabs ul::-webkit-scrollbar {
  display: none;
}
.rift-tab {
  display: block;
  padding: var(--space-3) var(--space-4);
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  white-space: nowrap;
  color: var(--ink-muted);
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
}
.rift-tab:hover {
  color: var(--ink);
}
.rift-tab.active {
  color: var(--ink);
  border-bottom-color: var(--blood-bright);
}
</style>
