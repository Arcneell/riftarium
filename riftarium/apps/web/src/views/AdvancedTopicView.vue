<script setup>
import { computed, onMounted, ref, watch } from "vue"
import { useRoute } from "vue-router"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import { CATEGORIES, TOPICS, topicBySlug } from "../rules/topics.js"
import RuleText from "../components/RuleText.vue"
import TopicDemo from "../components/TopicDemo.vue"
import { keywordFamily } from "../cardText.js"
import { applySeo } from "../seo.js"

const route = useRoute()
const topic = computed(() => topicBySlug(route.params.slug))
const categoryLabel = computed(() => CATEGORIES.find((c) => c.key === topic.value?.category)?.label ?? "")

/* Chips de mots-clés dans l'en-tête, colorés comme dans la cartothèque. */
const keywordChips = computed(() => {
  if (topic.value?.category !== "mots-cles") return []
  const labels = topic.value.chips ?? [topic.value.title]
  return labels.map((label) => ({ label, family: keywordFamily(label) }))
})

/* Sujets voisins de la même catégorie. */
const related = computed(() =>
  TOPICS.filter((t) => t.category === topic.value?.category && t.slug !== topic.value?.slug).slice(0, 4)
)

/* Texte officiel : les sections référencées, chargées depuis les règles embarquées. */
const officialSections = ref([])
let documents = null

async function loadOfficial() {
  officialSections.value = []
  if (!topic.value) return
  try {
    if (!documents) {
      const response = await fetch("/data/rules-fr.json")
      documents = await response.json()
    }
    const sections = []
    for (const document of Object.values(documents)) {
      for (const chapter of document.chapters) {
        for (const section of chapter.sections) {
          if (topic.value.sections?.includes(section.id)) sections.push(section)
        }
      }
    }
    officialSections.value = topic.value.sections.map((id) => sections.find((s) => s.id === id)).filter(Boolean)
  } catch {
    officialSections.value = []
  }
}
onMounted(loadOfficial)
watch(() => route.params.slug, loadOfficial)
watch(
  topic,
  (item) => {
    applySeo({
      title: item ? `${item.title} — Aide Riftbound` : "Aide Riftbound",
      description: item?.summary,
      path: route.path,
      noindex: !item
    })
  },
  { immediate: true }
)

/* Zoom sur les cartes d'exemple. */
const zoomCard = ref(null)
const zoomUrl = (card) => card.img.replace("w=360", "w=860").replace("w=560", "w=1024")
</script>

<template>
  <template v-if="topic">
    <PageBanner :art="BANNERS.rules" :title="topic.title" show-title>
      <template #eyebrow>
        <RouterLink to="/regles">Règles</RouterLink> › <RouterLink to="/regles/avancee">Aide avancée</RouterLink> ›
        {{ categoryLabel }}
      </template>
      <template #meta>
        <p v-if="keywordChips.length" style="margin: 6px 0 10px">
          <span
            v-for="chip in keywordChips"
            :key="chip.label"
            class="rb-kw"
            :class="chip.family"
            style="margin-right: 6px"
            >{{ chip.label }}</span
          >
        </p>
      </template>
    </PageBanner>

    <section>
      <div class="wrap topic-layout">
        <div class="topic-main">
          <h3 class="topic-part">L'essentiel</h3>
          <ul class="guide-text">
            <li v-for="(line, i) in topic.details" :key="i"><RuleText :text="line" /></li>
          </ul>

          <template v-if="topic.demo">
            <h3 class="topic-part">En animation</h3>
            <TopicDemo :demo="topic.demo" :key="topic.slug" />
          </template>

          <template v-if="topic.cases?.length">
            <h3 class="topic-part">Cas concrets</h3>
            <div class="topic-case panel" v-for="(item, i) in topic.cases" :key="i" v-reveal="i % 3">
              <p class="topic-q"><RuleText :text="item.q" /></p>
              <p class="topic-a"><RuleText :text="item.a" /></p>
            </div>
          </template>

          <template v-if="officialSections.length">
            <h3 class="topic-part">Le texte officiel, en intégralité</h3>
            <p class="muted" style="font-size: 0.8rem; margin-bottom: 16px">
              <RouterLink :to="`/regles/officielles?doc=core&section=${topic.sections[0]}`"
                >Ouvrir dans le lecteur</RouterLink
              >.
            </p>
            <article v-for="section in officialSections" :key="section.id" class="topic-official panel">
              <h4 class="mono">{{ section.number }} {{ section.title }}</h4>
              <p
                v-for="entry in section.entries"
                :key="entry.id"
                class="topic-rule"
                :style="{ '--indent': Math.min(entry.depth, 4) }"
              >
                <span class="mono topic-rule-num">{{ entry.number }}</span> <RuleText :text="entry.text" />
              </p>
            </article>
          </template>
        </div>

        <aside class="topic-side">
          <template v-if="topic.examples?.length">
            <h3 class="topic-part">Exemple</h3>
            <div class="topic-examples">
              <button
                v-for="card in topic.examples"
                :key="card.id"
                class="topic-example"
                @click="zoomCard = card"
                :aria-label="`Agrandir ${card.name}`"
              >
                <img :src="card.img" :alt="card.name" width="744" height="1039" loading="lazy" />
                <span class="mono">{{ card.name }}</span>
              </button>
            </div>
            <p class="muted" style="font-size: 0.68rem">© Riot Games.</p>
          </template>

          <h3 class="topic-part">Dans la même catégorie</h3>
          <div class="topic-list">
            <RouterLink v-for="t in related" :key="t.slug" class="topic-row" :to="`/regles/avancee/${t.slug}`">
              <span class="topic-title">{{ t.title }}</span>
              <Icon name="arrow" :size="14" />
            </RouterLink>
          </div>
          <RouterLink class="btn btn-ghost" to="/regles/avancee" style="margin-top: 18px"
            >← Toute l'aide avancée</RouterLink
          >
        </aside>
      </div>

      <div
        v-if="zoomCard"
        class="tb-zoom topic-zoom"
        role="dialog"
        aria-label="Carte en grand"
        @click="zoomCard = null"
      >
        <img :src="zoomUrl(zoomCard)" :alt="zoomCard.name" />
        <p class="mono">{{ zoomCard.name }}</p>
      </div>
    </section>
  </template>

  <section v-else>
    <div class="wrap">
      <p class="muted">Sujet introuvable. <RouterLink to="/regles/avancee">Retour à l'aide avancée</RouterLink></p>
    </div>
  </section>
</template>
