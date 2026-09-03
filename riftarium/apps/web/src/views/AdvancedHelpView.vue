<script setup>
import { computed, ref } from "vue"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import { CATEGORIES, TOPICS } from "../rules/topics.js"

const query = ref("")

/* Plage des diacritiques combinants, écrite en points de code : les caractères
   littéraux étaient invisibles dans l'éditeur et impossibles à relire. */
const normalize = (value) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()

/* Texte cherchable de chaque sujet, calculé une fois au chargement du module :
   le recomposer à chaque frappe refaisait un `normalize` sur tout le catalogue.
   `details` et `cases` sont facultatifs dans topics.js. */
const HAYSTACKS = new Map(
  TOPICS.map((topic) => [
    topic.slug,
    normalize(
      [
        topic.title,
        topic.summary,
        ...(topic.details ?? []),
        ...(topic.cases ?? []).map((item) => `${item.q} ${item.a}`)
      ].join(" ")
    )
  ])
)

const filtered = computed(() => {
  const tokens = normalize(query.value.trim()).split(/\s+/).filter(Boolean)
  if (!tokens.length) return TOPICS
  return TOPICS.filter((topic) => {
    const haystack = HAYSTACKS.get(topic.slug) ?? ""
    return tokens.every((token) => haystack.includes(token))
  })
})

const grouped = computed(() =>
  CATEGORIES.map((category) => ({
    ...category,
    topics: filtered.value.filter((topic) => topic.category === category.key)
  })).filter((category) => category.topics.length)
)
</script>

<template>
  <PageBanner :art="BANNERS.rules" title="Aide avancée">
    <template #eyebrow> <RouterLink to="/regles">Règles</RouterLink> › Aide avancée </template>
    <template #after>
      <label class="search" style="max-width: 420px; margin-top: 18px">
        <Icon name="search" :size="18" />
        <input
          type="search"
          inputmode="search"
          enterkeyhint="search"
          autocapitalize="off"
          autocorrect="off"
          spellcheck="false"
          v-model="query"
          placeholder="tank, conquête, réaction, recycler…"
          aria-label="Rechercher une mécanique"
        />
      </label>
    </template>
  </PageBanner>

  <section>
    <div class="wrap">
      <p class="muted mono" v-if="!grouped.length" style="font-size: 0.8rem">
        Aucune mécanique ne correspond à cette recherche. Essayez un autre mot, ou passez par les
        <RouterLink to="/regles/officielles">règles officielles</RouterLink>.
      </p>

      <div v-for="(category, i) in grouped" :key="category.key" class="topic-section" v-reveal="i % 3">
        <h3 class="topic-heading">
          {{ category.label }} <small class="mono">{{ category.topics.length }}</small>
        </h3>
        <div class="topic-list">
          <RouterLink
            v-for="topic in category.topics"
            :key="topic.slug"
            class="topic-row"
            :to="`/regles/avancee/${topic.slug}`"
          >
            <span class="topic-title">{{ topic.title }}</span>
            <span class="topic-summary">{{ topic.summary }}</span>
            <Icon name="arrow" :size="16" />
          </RouterLink>
        </div>
      </div>

      <div style="text-align: center; margin-top: 44px" v-reveal>
        <RouterLink class="btn" to="/regles/officielles">Chercher dans les règles officielles</RouterLink>
      </div>
    </div>
  </section>
</template>
