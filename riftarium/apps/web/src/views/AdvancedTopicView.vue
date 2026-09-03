<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute } from "vue-router"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import { CATEGORIES, TOPICS, topicBySlug } from "../rules/topics.js"
import RuleText from "../components/RuleText.vue"
import TopicDemo from "../components/TopicDemo.vue"
import { keywordFamily } from "../cardText.js"
import { cardThumb } from "../api.js"
import { loadRulesDocuments } from "../rules/rulesStore.js"
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

/* Texte officiel : les sections référencées, chargées depuis les règles embarquées.
   `doc` choisit le document (règles du jeu par défaut, règles de tournoi pour la
   catégorie Tournoi) : les numéros de section se recoupent d'un document à l'autre. */
const officialSections = ref([])
/* Le fichier n'a pas pu être lu (hors ligne, 404) : on le dit au lieu de laisser
   croire que le sujet n'a pas de texte officiel. */
const officialError = ref(false)
const officialDoc = computed(() => topic.value?.doc ?? "core")

async function loadOfficial() {
  officialSections.value = []
  officialError.value = false
  if (!topic.value?.sections?.length) return
  try {
    /* Cache de module partagé avec le lecteur intégral : un seul téléchargement. */
    const documents = await loadRulesDocuments()
    const found = new Map()
    for (const chapter of documents[officialDoc.value]?.chapters ?? []) {
      for (const section of chapter.sections) {
        if (topic.value.sections.includes(section.id)) found.set(section.id, section)
      }
    }
    officialSections.value = topic.value.sections.map((id) => found.get(id)).filter(Boolean)
  } catch {
    officialError.value = true
  }
}
onMounted(loadOfficial)

/* Un appel direct, pas un `watch` : App.vue clef la RouterView sur le chemin, donc
   passer d'un sujet à l'autre remonte le composant — le sujet ne change jamais
   sous les pieds de cette instance. */
applySeo({
  title: topic.value ? `${topic.value.title} — Aide Riftbound` : "Aide Riftbound",
  description: topic.value?.summary,
  path: route.path,
  noindex: !topic.value
})

/* Zoom sur les cartes d'exemple : le redimensionnement CDN est celui d'api.js,
   plutôt qu'un remplacement de largeur au petit bonheur dans l'URL. */
const zoomCard = ref(null)
const zoomUrl = (card) => cardThumb(card.img, 1024)

/* Échap ferme le zoom, et le panneau prend le focus à l'ouverture : sans cela le
   `role="dialog"` promet un dialogue que le clavier ne sait ni atteindre ni quitter. */
const zoomEl = ref(null)

function onZoomKey(event) {
  if (event.key === "Escape") zoomCard.value = null
}

watch(zoomCard, async (card) => {
  if (typeof document === "undefined") return
  if (card) {
    document.addEventListener("keydown", onZoomKey)
    await nextTick()
    zoomEl.value?.focus()
  } else {
    document.removeEventListener("keydown", onZoomKey)
  }
})

onBeforeUnmount(() => {
  if (typeof document !== "undefined") document.removeEventListener("keydown", onZoomKey)
})
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

          <p v-if="officialError" class="muted" style="font-size: 0.8rem">
            Texte officiel indisponible pour l'instant. Il reste consultable dans le
            <RouterLink to="/regles/officielles">lecteur des règles</RouterLink>.
          </p>

          <template v-if="officialSections.length">
            <h3 class="topic-part">Le texte officiel, en intégralité</h3>
            <p class="muted" style="font-size: 0.8rem; margin-bottom: 16px">
              <RouterLink :to="`/regles/officielles?doc=${officialDoc}&section=${topic.sections[0]}`"
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
        ref="zoomEl"
        class="tb-zoom topic-zoom"
        role="dialog"
        aria-modal="true"
        aria-label="Carte en grand"
        tabindex="-1"
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
