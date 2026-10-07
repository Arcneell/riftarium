<script setup>
import { computed, onMounted, ref } from "vue"
import { useRoute, useRouter } from "vue-router"
import CardZoom from "../rules/CardZoom.vue"
import RulesHeader from "../rules/RulesHeader.vue"
import TopicDemo from "../rules/TopicDemo.vue"
import { CATEGORIES, TOPICS, topicBySlug } from "../rules/topics.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftText from "../ui/RiftText.vue"
import { keywordFamily } from "../cardText.js"
import { loadRulesDocuments } from "../rules/rulesStore.js"
import { applySeo } from "../seo.js"

const route = useRoute()
const router = useRouter()
const topic = computed(() => topicBySlug(route.params.slug))
const categoryLabel = computed(() => CATEGORIES.find((c) => c.key === topic.value?.category)?.label ?? "")

const crumbs = computed(() => [
  { label: "Règles", to: "/regles" },
  { label: "Aide avancée", to: "/regles/avancee" },
  { label: categoryLabel.value }
])

/* Pastilles de mots-clés dans l'en-tête : classes `rb-kw` de src/styles/base.css,
   partagées avec les cartes. */
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

/* Clic sur un renvoi « règle 123.4 » du texte officiel : le lecteur intégral le
   résout (paramètre `ref`). Délégation : un seul écouteur pour toutes les sections. */
function onOfficialClick(event) {
  const button = event.target instanceof Element ? event.target.closest("[data-ref]") : null
  if (!button) return
  router.push({ path: "/regles/officielles", query: { doc: officialDoc.value, ref: button.dataset.ref } })
}

/* Un appel direct, pas un `watch` : App.vue clef la RouterView sur le chemin, donc
   passer d'un sujet à l'autre remonte le composant — le sujet ne change jamais
   sous les pieds de cette instance. */
applySeo({
  title: topic.value ? `${topic.value.title} — Aide Riftbound` : "Aide Riftbound",
  description: topic.value?.summary,
  path: route.path,
  noindex: !topic.value
})

/* Zoom sur les cartes d'exemple : CardZoom est un vrai dialogue (focus, Échap). */
const zoomCard = ref(null)
</script>

<template>
  <div v-if="topic" class="wrap cards-wrap regles-sujet">
    <RulesHeader :title="topic.title" :crumbs="crumbs">
      <p v-if="keywordChips.length" class="sujet-kws">
        <span v-for="chip in keywordChips" :key="chip.label" class="rb-kw" :class="chip.family">{{ chip.label }}</span>
      </p>
    </RulesHeader>

    <div class="sujet-layout">
      <div class="sujet-main">
        <h2 class="sujet-part">L'essentiel</h2>
        <ul class="sujet-list">
          <li v-for="(line, i) in topic.details" :key="i"><RiftText rules :text="line" /></li>
        </ul>

        <template v-if="topic.demo">
          <h2 class="sujet-part">En animation</h2>
          <TopicDemo :demo="topic.demo" :key="topic.slug" />
        </template>

        <template v-if="topic.cases?.length">
          <h2 class="sujet-part">Cas concrets</h2>
          <div class="sujet-cases">
            <RiftPanel v-for="(item, i) in topic.cases" :key="i" tag="div" class="sujet-case">
              <p class="sujet-q"><RiftText rules :text="item.q" /></p>
              <p class="sujet-a"><RiftText rules :text="item.a" /></p>
            </RiftPanel>
          </div>
        </template>

        <p v-if="officialError" class="sujet-note">
          Texte officiel indisponible pour l'instant. Il reste consultable dans le
          <RouterLink to="/regles/officielles">lecteur des règles</RouterLink>.
        </p>

        <template v-if="officialSections.length">
          <h2 class="sujet-part">Le texte officiel, en intégralité</h2>
          <p class="sujet-note">
            <RouterLink :to="`/regles/officielles?doc=${officialDoc}&section=${topic.sections[0]}`"
              >Ouvrir dans le lecteur</RouterLink
            >.
          </p>
          <div class="sujet-official" @click="onOfficialClick">
            <RiftPanel v-for="section in officialSections" :key="section.id" tag="article" class="sujet-section">
              <h3 class="sujet-section-title">{{ section.number }} {{ section.title }}</h3>
              <p
                v-for="entry in section.entries"
                :key="entry.id"
                class="sujet-rule"
                :style="{ '--indent': Math.min(entry.depth, 4) }"
              >
                <span class="sujet-rule-num">{{ entry.number }}</span> <RiftText rules refs :text="entry.text" />
              </p>
            </RiftPanel>
          </div>
        </template>
      </div>

      <aside class="sujet-side">
        <template v-if="topic.examples?.length">
          <h2 class="sujet-part">Exemple</h2>
          <div class="sujet-examples">
            <button
              v-for="card in topic.examples"
              :key="card.id"
              type="button"
              class="sujet-example"
              :aria-label="`Agrandir ${card.name}`"
              @click="zoomCard = card"
            >
              <img :src="card.img" :alt="card.name" width="744" height="1039" loading="lazy" />
              <span class="sujet-example-name">{{ card.name }}</span>
            </button>
          </div>
          <p class="sujet-credit">© Riot Games.</p>
        </template>

        <h2 class="sujet-part">Dans la même catégorie</h2>
        <div class="sujet-related">
          <RouterLink v-for="t in related" :key="t.slug" class="sujet-related-row" :to="`/regles/avancee/${t.slug}`">
            <span>{{ t.title }}</span>
            <Icon name="arrow" :size="14" />
          </RouterLink>
        </div>
        <RiftButton class="sujet-back" variant="ghost" to="/regles/avancee">← Toute l'aide avancée</RiftButton>
      </aside>
    </div>

    <CardZoom v-if="zoomCard" :card="zoomCard" @close="zoomCard = null" />
  </div>

  <div v-else class="wrap cards-wrap regles-sujet">
    <RiftEmpty title="Sujet introuvable" text="Ce sujet n'existe pas ou a changé d'adresse.">
      <RiftButton variant="secondary" to="/regles/avancee">Retour à l'aide avancée</RiftButton>
    </RiftEmpty>
  </div>
</template>

<style scoped>
.regles-sujet {
  padding-bottom: var(--space-7);
}
.sujet-kws {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin: 0;
}
.sujet-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.8fr) minmax(280px, 1fr);
  gap: var(--space-7);
  align-items: start;
}
.sujet-main,
.sujet-side {
  min-width: 0;
}
.sujet-side {
  position: sticky;
  top: calc(var(--topbar-h) + var(--space-4));
}
/* main.css style `h2` : on neutralise localement. */
.sujet-part {
  margin: var(--space-6) 0 var(--space-3);
  padding: 0;
  background: none;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
}
.sujet-part:first-child {
  margin-top: 0;
}
.sujet-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  margin: 0;
  padding: 0;
  list-style: none;
}
.sujet-list li {
  position: relative;
  padding-left: 20px;
  color: var(--ink);
  line-height: 1.6;
}
.sujet-list li::before {
  content: "";
  position: absolute;
  left: 2px;
  top: 0.6em;
  width: 7px;
  height: 7px;
  background: var(--bronze);
  rotate: 45deg;
}
.sujet-cases,
.sujet-official {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
}
.sujet-case {
  padding: var(--space-4) var(--space-5);
}
.sujet-q,
.sujet-a {
  margin: 0;
  line-height: 1.6;
}
.sujet-q {
  margin-bottom: var(--space-2);
  color: var(--ink);
  font-weight: 700;
}
.sujet-q::before,
.sujet-a::before {
  font-family: var(--font-label);
  font-size: 0.9em;
  letter-spacing: 0.1em;
}
.sujet-q::before {
  content: "Q — ";
  color: var(--blood-text);
}
.sujet-a {
  color: var(--ink);
  font-size: 15px;
}
.sujet-a::before {
  content: "R — ";
  color: var(--bronze-light);
}
.sujet-note {
  margin: 0 0 var(--space-3);
  color: var(--ink-muted);
  font-size: 14px;
}
.sujet-note a {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--bronze-light);
}
.sujet-section {
  content-visibility: auto;
  contain-intrinsic-size: auto 420px;
}
.sujet-section-title {
  margin: 0 0 var(--space-3);
  padding: 0;
  background: none;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 18px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.sujet-rule {
  margin: 0 0 var(--space-2);
  /* Indentation par profondeur (--indent posé par la vue). */
  margin-left: calc(var(--indent, 0) * 16px);
  color: var(--ink);
  font-size: 15px;
  line-height: 1.6;
}
.sujet-rule-num {
  margin-right: var(--space-1);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 0.06em;
}

/* Colonne latérale */
.sujet-examples {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-4);
  margin-bottom: var(--space-2);
}
.sujet-example {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  width: 100%;
  max-width: 320px;
  padding: 0;
  background: none;
  border: 0;
  color: inherit;
  text-align: center;
  cursor: zoom-in;
}
.sujet-example img {
  width: 100%;
  /* Réserve la hauteur avant chargement (cartes 744×1039). */
  aspect-ratio: 744 / 1039;
  border-radius: var(--radius-card);
  transition: transform var(--t-base);
}
.sujet-example:hover img {
  transform: translateY(-4px);
}
.sujet-example:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 4px;
}
.sujet-example-name {
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.sujet-credit {
  margin: 0;
  color: var(--ink-muted);
  font-size: 12px;
}
.sujet-related {
  display: flex;
  flex-direction: column;
}
.sujet-related-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
  min-height: 44px;
  padding: var(--space-2) var(--space-3);
  border-bottom: 1px solid var(--line);
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 18px;
  letter-spacing: 0.04em;
  text-decoration: none;
  transition: background var(--t-fast);
}
.sujet-related-row:hover {
  background: var(--bg-raised);
}
.sujet-related-row:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.sujet-back {
  margin-top: var(--space-4);
}

/* Sous 1 024 px, la colonne latérale passe sous la principale. */
@media (max-width: 1023px) {
  .sujet-layout {
    grid-template-columns: minmax(0, 1fr);
    gap: var(--space-6);
  }
  .sujet-side {
    position: static;
  }
}
</style>
