<script setup>
import { computed, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { applySeo } from "../seo.js"
import CardZoom from "../rules/CardZoom.vue"
import LessonBlock from "../rules/LessonBlock.vue"
import RulesHeader from "../rules/RulesHeader.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftText from "../ui/RiftText.vue"
import { CHAPTERS, chapterBySlug, chapterIndex, chapterPath, DEFAULT_CHAPTER } from "../rules/learn.js"

const route = useRoute()
const router = useRouter()
const breakpoint = useBreakpoint()

const slug = computed(() => route.params.slug || DEFAULT_CHAPTER)
const chapter = computed(() => chapterBySlug(slug.value))
const index = computed(() => chapterIndex(slug.value))
const previous = computed(() => CHAPTERS[index.value - 1] ?? null)
const next = computed(() => CHAPTERS[index.value + 1] ?? null)
const crumbs = computed(() => [
  { label: "Règles", to: "/regles" },
  { label: "Apprendre à jouer", to: "/regles/debutant" },
  { label: `Chapitre ${index.value + 1} / ${CHAPTERS.length}` }
])

function syncSeo() {
  if (!chapter.value) {
    applySeo({
      title: "Chapitre introuvable",
      description: "Ce chapitre du guide Riftbound n'existe pas.",
      path: route.path,
      noindex: true
    })
    return
  }
  applySeo({
    title: `${chapter.value.title} — Apprendre Riftbound`,
    description: chapter.value.summary,
    path: route.path
  })
}

onMounted(() => {
  /* Ancien guide animé : ?etape= reste la mémoire des 17 scènes. */
  if (route.query.etape) {
    router.replace({ path: "/regles/debutant/plateau", query: route.query })
    return
  }
  if (route.params.slug === DEFAULT_CHAPTER) {
    router.replace({ path: chapterPath(DEFAULT_CHAPTER), query: route.query })
    return
  }
  syncSeo()
})

watch(
  () => route.params.slug,
  () => {
    zoomCard.value = null
    syncSeo()
  }
)

const zoomCard = ref(null)
</script>

<template>
  <div class="wrap cards-wrap regles-guide">
    <template v-if="chapter">
      <RulesHeader :title="chapter.title" :kicker="chapter.kicker" :crumbs="crumbs" />

      <div class="chapitre-layout">
        <component :is="breakpoint === 'desktop' ? 'aside' : 'details'" class="chapitre-toc">
          <summary v-if="breakpoint !== 'desktop'" class="chapitre-toc-summary">
            Chapitres ({{ CHAPTERS.length }})
          </summary>
          <p v-else class="chapitre-toc-count">{{ CHAPTERS.length }} chapitres</p>
          <nav aria-label="Chapitres du guide">
            <RouterLink
              v-for="(item, i) in CHAPTERS"
              :key="item.slug"
              class="chapitre-toc-link"
              :to="chapterPath(item.slug)"
              :aria-current="item.slug === chapter.slug ? 'page' : undefined"
            >
              <span class="chapitre-toc-num">{{ i + 1 }}</span>
              <span class="chapitre-toc-text">
                {{ item.title }}
                <small>{{ item.kicker }}</small>
              </span>
            </RouterLink>
          </nav>
          <RouterLink class="chapitre-toc-board" to="/regles/debutant/plateau">Voir sur le plateau →</RouterLink>
        </component>

        <article class="chapitre-main">
          <p class="chapitre-lead"><RiftText rules :text="chapter.lead" /></p>

          <LessonBlock
            v-for="(block, i) in chapter.blocks"
            :key="`${chapter.slug}-${i}`"
            :block="block"
            @zoom="zoomCard = $event"
          />

          <p class="chapitre-ref">
            <RouterLink :to="`/regles/officielles?doc=core&section=${chapter.ref}`"
              >Règle {{ chapter.ref }} ↗</RouterLink
            >
          </p>

          <div class="chapitre-pager">
            <RiftButton v-if="previous" variant="ghost" :to="chapterPath(previous.slug)">
              ← {{ previous.title }}
            </RiftButton>
            <span v-else></span>
            <RiftButton v-if="next" variant="primary" :to="chapterPath(next.slug)">{{ next.title }} →</RiftButton>
            <RiftButton v-else variant="primary" to="/regles/debutant/plateau">Voir sur le plateau →</RiftButton>
          </div>
        </article>
      </div>

      <CardZoom v-if="zoomCard" :card="zoomCard" @close="zoomCard = null" />
    </template>

    <RiftEmpty v-else title="Chapitre introuvable" text="Ce chapitre du guide n'existe pas.">
      <RiftButton variant="secondary" to="/regles/debutant">Retour au guide</RiftButton>
    </RiftEmpty>
  </div>
</template>

<style scoped>
.regles-guide {
  padding-bottom: var(--space-7);
}
.chapitre-layout {
  display: grid;
  grid-template-columns: 280px minmax(0, 1fr);
  gap: var(--space-6);
  align-items: start;
}
.chapitre-toc {
  position: sticky;
  top: calc(var(--topbar-h) + var(--space-4));
  max-height: calc(100dvh - var(--topbar-h) - 32px);
  overflow-y: auto;
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.chapitre-toc-count {
  margin: 0 0 var(--space-3);
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.chapitre-toc nav {
  display: flex;
  flex-direction: column;
}
.chapitre-toc-link {
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
  min-height: 44px;
  padding: var(--space-2) var(--space-2);
  border-left: 2px solid transparent;
  color: var(--ink);
  text-decoration: none;
  transition:
    background var(--t-fast),
    border-color var(--t-fast);
}
.chapitre-toc-link:hover {
  background: var(--bg-sunken);
}
.chapitre-toc-link[aria-current="page"] {
  background: var(--bg-sunken);
  border-left-color: var(--blood);
}
.chapitre-toc-link:focus-visible,
.chapitre-toc-board:focus-visible,
.chapitre-toc-summary:focus-visible,
.chapitre-ref a:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -3px;
}
.chapitre-toc-num {
  flex: none;
  width: 24px;
  color: var(--bronze);
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
  line-height: 1.3;
}
.chapitre-toc-link[aria-current="page"] .chapitre-toc-num {
  color: var(--bronze-light);
}
.chapitre-toc-text {
  display: flex;
  flex-direction: column;
  font-size: 15px;
  line-height: 1.3;
}
.chapitre-toc-text small {
  color: var(--ink-muted);
  font-size: 13px;
}
.chapitre-toc-board {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  margin-top: var(--space-3);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 15px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  text-decoration: none;
}
.chapitre-toc-summary {
  display: flex;
  align-items: center;
  min-height: 44px;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 16px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  cursor: pointer;
}
.chapitre-main {
  min-width: 0;
  max-width: 760px;
}
.chapitre-lead {
  margin: 0 0 var(--space-5);
  color: var(--ink);
  font-family: var(--font-body);
  font-size: 19px;
  line-height: 1.55;
}
.chapitre-ref {
  margin: var(--space-6) 0 0;
  font-size: 14px;
}
.chapitre-ref a {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--ink-muted);
}
.chapitre-pager {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: var(--space-3);
  margin-top: var(--space-4);
}
@media (max-width: 1023px) {
  .chapitre-layout {
    grid-template-columns: 1fr;
    gap: var(--space-4);
  }
  .chapitre-toc {
    position: static;
  }
}
@media (prefers-reduced-motion: reduce) {
  .chapitre-toc-link {
    transition: none;
  }
}
</style>
