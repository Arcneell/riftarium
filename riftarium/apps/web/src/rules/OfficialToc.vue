<script setup>
import { nextTick, onMounted, ref, watch } from "vue"

/* Table des matières du texte officiel : chapitres repliables et sections.
   Partagée entre la colonne collante (bureau) et la feuille « Sommaire » (< 1 024 px). */
const props = defineProps({
  doc: { type: Object, required: true },
  sectionId: { type: String, default: null },
  openChapters: { type: Object, required: true } // Set d'identifiants de chapitres
})
const emit = defineEmits(["pick", "toggle"])

const root = ref(null)
const bare = (number) => number.replace(/\.$/, "")

/* Premier ancêtre à défilement vertical (colonne collante ou feuille). */
function scrollParent(element) {
  for (let node = element?.parentElement; node && node !== document.body; node = node.parentElement) {
    if (/(auto|scroll)/.test(getComputedStyle(node).overflowY)) return node
  }
  return null
}

/* La section courante reste visible dans le défilement interne de la table. */
function revealCurrent() {
  nextTick(() => {
    const current = root.value?.querySelector("[aria-current]")
    const box = scrollParent(root.value)
    if (!current || !box) return
    /* Seul le conteneur de la table défile (pas la fenêtre) : on règle son scrollTop. */
    const top = current.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop
    if (top < box.scrollTop) box.scrollTop = top
    else if (top + current.offsetHeight > box.scrollTop + box.clientHeight)
      box.scrollTop = top + current.offsetHeight - box.clientHeight
  })
}
watch(() => props.sectionId, revealCurrent)
onMounted(revealCurrent)
</script>

<template>
  <nav ref="root" class="officiel-toc-list" aria-label="Sommaire du texte officiel">
    <div v-for="chapter in doc.chapters" :key="chapter.id" class="officiel-toc-chapter">
      <button
        type="button"
        class="officiel-toc-chapter-btn"
        :aria-expanded="String(openChapters.has(chapter.id))"
        @click="emit('toggle', chapter.id)"
      >
        <span class="officiel-toc-chevron" aria-hidden="true">{{ openChapters.has(chapter.id) ? "▾" : "▸" }}</span>
        <span class="officiel-toc-chapter-title">{{ chapter.title }}</span>
        <small>{{ chapter.sections.length }}</small>
      </button>
      <div v-if="openChapters.has(chapter.id)">
        <button
          v-for="section in chapter.sections"
          :key="section.id"
          type="button"
          class="officiel-toc-section"
          :aria-current="section.id === sectionId ? 'true' : undefined"
          @click="emit('pick', section.id)"
        >
          <b>{{ bare(section.number) }}</b> {{ section.title }}
        </button>
      </div>
    </div>
  </nav>
</template>

<style scoped>
.officiel-toc-list {
  display: block;
}
.officiel-toc-chapter {
  border-bottom: 1px solid var(--line);
}
/* Boutons neutralisés localement : main.css stylise `button` globalement. */
.officiel-toc-chapter-btn,
.officiel-toc-section {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  width: 100%;
  min-height: 44px;
  padding: 0 var(--space-3);
  border: 0;
  border-radius: 0;
  background: none;
  box-shadow: none;
  color: var(--ink);
  font-family: var(--font-body);
  font-size: 14px;
  text-align: left;
  cursor: pointer;
  transition:
    background var(--t-fast),
    color var(--t-fast);
}
.officiel-toc-chapter-btn {
  font-family: var(--font-label);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0.04em;
}
.officiel-toc-chapter-btn:hover,
.officiel-toc-section:hover {
  background: var(--bg-raised);
}
.officiel-toc-chapter-btn:focus-visible,
.officiel-toc-section:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.officiel-toc-chevron {
  flex: none;
  width: 1em;
  color: var(--bronze-light);
}
.officiel-toc-chapter-title {
  flex: 1;
  min-width: 0;
}
.officiel-toc-chapter-btn small {
  color: var(--ink-muted);
  font-size: 13px;
}
.officiel-toc-section {
  padding-left: var(--space-6);
  color: var(--ink-muted);
}
.officiel-toc-section b {
  flex: none;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-weight: 600;
}
.officiel-toc-section[aria-current="true"] {
  color: var(--ink);
  background: var(--bg-raised);
  box-shadow: inset 2px 0 0 var(--blood);
}
</style>
