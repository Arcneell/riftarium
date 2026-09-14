<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { cardThumb } from "../api.js"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import RuleText from "../components/RuleText.vue"
import LearnRuneDemo from "../components/LearnRuneDemo.vue"
import { applySeo } from "../seo.js"
import {
  ABCD_PHASES,
  CHAPTERS,
  chapterBySlug,
  chapterIndex,
  chapterPath,
  DEFAULT_CHAPTER,
  LEARN_INTRO
} from "../rules/learn.js"

const route = useRoute()
const router = useRouter()

const slug = computed(() => route.params.slug || DEFAULT_CHAPTER)
const chapter = computed(() => chapterBySlug(slug.value))
const index = computed(() => chapterIndex(slug.value))
const previous = computed(() => CHAPTERS[index.value - 1] ?? null)
const next = computed(() => CHAPTERS[index.value + 1] ?? null)

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

function firstTypeKey(doc) {
  return doc?.blocks.find((block) => block.type === "types")?.items[0]?.key ?? null
}

const selectedType = ref(firstTypeKey(chapter.value))

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
    selectedType.value = firstTypeKey(chapter.value)
    syncSeo()
  }
)

const zoomCard = ref(null)
const zoomEl = ref(null)
const zoomUrl = (card) => cardThumb(card.img, 1024)

function onZoomKey(event) {
  if (event.key === "Escape") zoomCard.value = null
}

function openZoom(card) {
  zoomCard.value = card
}

watch(zoomCard, async (card) => {
  if (typeof document === "undefined") return
  if (card) {
    document.body.classList.add("nav-locked")
    document.addEventListener("keydown", onZoomKey)
    await nextTick()
    zoomEl.value?.focus()
  } else {
    document.body.classList.remove("nav-locked")
    document.removeEventListener("keydown", onZoomKey)
  }
})

onBeforeUnmount(() => {
  if (typeof document === "undefined") return
  document.removeEventListener("keydown", onZoomKey)
  document.body.classList.remove("nav-locked")
})
</script>

<template>
  <template v-if="chapter">
    <PageBanner :art="BANNERS.rules" :title="chapter.title" show-title>
      <template #eyebrow>
        <RouterLink to="/regles">Règles</RouterLink> ›
        <RouterLink to="/regles/debutant">Apprendre à jouer</RouterLink> › Chapitre {{ index + 1 }} /
        {{ CHAPTERS.length }}
      </template>
      <template #meta>
        <p class="learn-kicker">{{ chapter.kicker }}</p>
      </template>
    </PageBanner>

    <section>
      <div class="wrap learn-layout">
        <aside class="learn-toc">
          <p class="eyebrow">Apprendre à jouer</p>
          <p class="learn-toc-count mono">{{ CHAPTERS.length }} chapitres</p>
          <nav aria-label="Chapitres du guide">
            <RouterLink
              v-for="(item, i) in CHAPTERS"
              :key="item.slug"
              class="learn-toc-link"
              :class="{ current: item.slug === chapter.slug }"
              :to="chapterPath(item.slug)"
            >
              <span class="mono">{{ i + 1 }}</span>
              <span>
                {{ item.title }}
                <small>{{ item.kicker }}</small>
              </span>
            </RouterLink>
          </nav>
          <RouterLink class="learn-toc-board" to="/regles/debutant/plateau">Voir sur le plateau →</RouterLink>
        </aside>

        <article class="learn-main">
          <p class="learn-lead">{{ chapter.lead }}</p>

          <template v-for="(block, i) in chapter.blocks" :key="i">
            <h3 v-if="block.type === 'h'" class="learn-h">{{ block.text }}</h3>

            <p v-else-if="block.type === 'p'" class="learn-p"><RuleText :text="block.text" /></p>

            <div v-else-if="block.type === 'stat'" class="learn-stat">
              <b>{{ block.value }}</b>
              <div>
                <p class="learn-stat-label">{{ block.label }}</p>
                <p class="learn-p"><RuleText :text="block.text" /></p>
              </div>
            </div>

            <ul v-else-if="block.type === 'ul'" class="learn-list">
              <li v-for="(item, j) in block.items" :key="j"><RuleText :text="item" /></li>
            </ul>

            <ol v-else-if="block.type === 'ol'" class="learn-list numbered">
              <li v-for="(item, j) in block.items" :key="j"><RuleText :text="item" /></li>
            </ol>

            <div v-else-if="block.type === 'table'" class="learn-table-wrap">
              <table>
                <thead>
                  <tr>
                    <th v-for="header in block.headers" :key="header">{{ header }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(row, r) in block.rows" :key="r">
                    <td v-for="(cell, c) in row" :key="c"><RuleText :text="cell" /></td>
                  </tr>
                </tbody>
              </table>
            </div>

            <aside v-else-if="block.type === 'note'" class="learn-note" :class="block.kind">
              <p class="learn-note-title">{{ block.title }}</p>
              <p><RuleText :text="block.text" /></p>
            </aside>

            <ol v-else-if="block.type === 'steps'" class="learn-steps">
              <li v-for="(step, s) in block.items" :key="s">
                <strong>{{ step.title }}</strong>
                <p><RuleText :text="step.text" /></p>
              </li>
            </ol>

            <div v-else-if="block.type === 'compare'" class="learn-compare">
              <div class="learn-compare-col">
                <p class="eyebrow">{{ block.left.kicker }}</p>
                <h4>{{ block.left.title }}</h4>
                <p><RuleText :text="block.left.text" /></p>
                <p class="mono learn-recover">{{ block.left.recover }}</p>
              </div>
              <div class="learn-compare-col">
                <p class="eyebrow">{{ block.right.kicker }}</p>
                <h4>{{ block.right.title }}</h4>
                <p><RuleText :text="block.right.text" /></p>
                <p class="mono learn-recover">{{ block.right.recover }}</p>
              </div>
            </div>

            <div v-else-if="block.type === 'abcd'" class="learn-abcd">
              <div v-for="phase in ABCD_PHASES" :key="phase.name" class="learn-abcd-step">
                <b class="mono">{{ phase.letter }}</b>
                <div>
                  <strong>{{ phase.name }}</strong>
                  <p>{{ phase.text }}</p>
                </div>
              </div>
            </div>

            <div v-else-if="block.type === 'types'" class="learn-types">
              <div class="learn-types-grid">
                <button
                  v-for="item in block.items"
                  :key="item.key"
                  type="button"
                  class="learn-type"
                  :class="{ current: selectedType === item.key, wide: item.wide }"
                  :aria-label="`${item.title}. Double-cliquer pour agrandir.`"
                  @click="selectedType = item.key"
                  @dblclick="openZoom(item.card)"
                >
                  <img :src="item.card.img" :alt="item.title" loading="lazy" decoding="async" />
                  <span>{{ item.title }}</span>
                </button>
              </div>
              <div
                v-for="item in block.items"
                :key="item.key + '-copy'"
                class="learn-type-copy"
                v-show="selectedType === item.key"
              >
                <p class="eyebrow">{{ item.title }}</p>
                <p><RuleText :text="item.text" /></p>
                <p class="muted learn-type-hint">Double-cliquez la carte pour l'agrandir.</p>
              </div>
            </div>

            <div v-else-if="block.type === 'loop'" class="learn-loop">
              <p class="eyebrow">Si vous ne retenez qu'une chose</p>
              <p>{{ LEARN_INTRO }}</p>
            </div>

            <LearnRuneDemo v-else-if="block.type === 'runes'" />
          </template>

          <p class="muted" style="font-size: 0.76rem; margin-top: 28px">
            <RouterLink :to="`/regles/officielles?doc=core&section=${chapter.ref}`"
              >Règle {{ chapter.ref }} ↗</RouterLink
            >
          </p>

          <div class="learn-pager">
            <RouterLink v-if="previous" class="btn btn-ghost" :to="chapterPath(previous.slug)">
              ← {{ previous.title }}
            </RouterLink>
            <span v-else></span>
            <RouterLink v-if="next" class="btn btn-gold" :to="chapterPath(next.slug)">{{ next.title }} →</RouterLink>
            <RouterLink v-else class="btn btn-gold" to="/regles/debutant/plateau">Voir sur le plateau →</RouterLink>
          </div>
        </article>
      </div>
    </section>
  </template>

  <section v-else>
    <div class="wrap">
      <p class="muted">Chapitre introuvable. <RouterLink to="/regles/debutant">Retour au guide</RouterLink></p>
    </div>
  </section>

  <Teleport to="body">
    <div
      v-if="zoomCard"
      ref="zoomEl"
      class="tb-zoom topic-zoom"
      role="dialog"
      aria-modal="true"
      aria-label="Carte en grand"
      tabindex="-1"
      @click="zoomCard = null"
    >
      <img :src="zoomUrl(zoomCard)" :alt="zoomCard.name" />
      <p class="mono">{{ zoomCard.name }} — clic ou Échap pour fermer</p>
    </div>
  </Teleport>
</template>
