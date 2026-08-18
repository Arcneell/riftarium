<script setup>
import { computed, ref } from "vue"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import { CATEGORIES, TOPICS } from "../rules/topics.js"

const query = ref("")

const normalize = (value) => value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()

const filtered = computed(() => {
  const tokens = normalize(query.value.trim()).split(/\s+/).filter(Boolean)
  if (!tokens.length) return TOPICS
  return TOPICS.filter((topic) => {
    const haystack = normalize(
      `${topic.title} ${topic.summary} ${topic.details.join(" ")} ${topic.cases.map((c) => c.q + " " + c.a).join(" ")}`
    )
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
  <PageBanner :art="BANNERS.rules" title="Chaque mécanique a sa page">
    <template #eyebrow> <RouterLink to="/regles">Règles</RouterLink> › Aide avancée </template>
    Un résumé par sujet ci-dessous ; ouvrez la page pour l'essentiel, les cas concrets, des cartes d'exemple et le texte
    officiel intégral de la mécanique.
    <template #after>
      <label class="search" style="max-width: 420px; margin-top: 18px">
        <Icon name="search" :size="18" />
        <input
          type="search"
          v-model="query"
          placeholder="tank, conquête, réaction, recycler…"
          aria-label="Rechercher une mécanique"
        />
      </label>
    </template>
  </PageBanner>

  <section style="padding-top: 30px">
    <div class="wrap">
      <p class="muted mono" v-if="!grouped.length" style="font-size: 0.8rem">
        Rien ici. Essayez un autre mot, ou passez par les
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
        <p class="muted" style="font-size: 0.85rem; margin-bottom: 14px">Pas trouvé ? Le texte intégral fait foi.</p>
        <RouterLink class="btn" to="/regles/officielles">Chercher dans les règles officielles</RouterLink>
      </div>
    </div>
  </section>
</template>
