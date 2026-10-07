<script setup>
import { computed, ref } from "vue"
import RulesHeader from "../rules/RulesHeader.vue"
import { CATEGORIES, TOPICS } from "../rules/topics.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"

const query = ref("")

const crumbs = [{ label: "Règles", to: "/regles" }, { label: "Aide avancée" }]

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
  <div class="wrap cards-wrap regles-aide">
    <RulesHeader title="Aide avancée" kicker="Mécaniques en détail" :crumbs="crumbs">
      <div class="aide-search">
        <RiftField
          v-model="query"
          search
          label="Rechercher une mécanique"
          placeholder="tank, conquête, réaction, recycler…"
          enterkeyhint="search"
          inputmode="search"
          autocapitalize="off"
          autocorrect="off"
          spellcheck="false"
        />
      </div>
    </RulesHeader>

    <RiftEmpty
      v-if="!grouped.length"
      title="Aucune mécanique ne correspond"
      text="Essayez un autre mot, ou passez par le texte officiel."
    >
      <RiftButton variant="secondary" to="/regles/officielles">Règles officielles</RiftButton>
    </RiftEmpty>

    <section v-for="category in grouped" :key="category.key" class="aide-section">
      <h2 class="aide-heading">
        {{ category.label }} <small class="aide-count">{{ category.topics.length }}</small>
      </h2>
      <div class="aide-list">
        <RouterLink
          v-for="topic in category.topics"
          :key="topic.slug"
          class="aide-row"
          :to="`/regles/avancee/${topic.slug}`"
        >
          <span class="aide-row-title">{{ topic.title }}</span>
          <span class="aide-row-summary">{{ topic.summary }}</span>
          <Icon name="arrow" :size="16" class="aide-row-arrow" />
        </RouterLink>
      </div>
    </section>

    <div class="aide-foot">
      <RiftButton variant="secondary" to="/regles/officielles">Chercher dans les règles officielles</RiftButton>
    </div>
  </div>
</template>

<style scoped>
.regles-aide {
  padding-bottom: var(--space-7);
}
.aide-search {
  max-width: 420px;
}
/* main.css style `section` et `h2` : on neutralise localement. */
.aide-section {
  padding: 0;
  margin-bottom: var(--space-6);
}
.aide-heading {
  display: flex;
  align-items: baseline;
  gap: var(--space-2);
  margin: 0 0 var(--space-3);
  padding: 0 0 var(--space-2);
  border-bottom: 1px solid var(--line);
  background: none;
  color: var(--bronze-light);
  font-family: var(--font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.aide-count {
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.1em;
}
.aide-list {
  display: flex;
  flex-direction: column;
}
.aide-row {
  display: grid;
  grid-template-columns: minmax(180px, 0.9fr) 2fr auto;
  align-items: center;
  gap: var(--space-4);
  min-height: 44px;
  padding: var(--space-3);
  border-bottom: 1px solid var(--line);
  color: inherit;
  text-decoration: none;
  transition: background var(--t-fast);
}
.aide-row:hover {
  background: var(--bg-raised);
}
.aide-row:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.aide-row-title {
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 20px;
  font-weight: 600;
  letter-spacing: 0.04em;
}
.aide-row-summary {
  color: var(--ink-muted);
  font-size: 14px;
  line-height: 1.45;
}
.aide-row-arrow {
  flex-shrink: 0;
  color: var(--bronze-light);
}
.aide-foot {
  margin-top: var(--space-7);
  text-align: center;
}

@media (max-width: 760px) {
  .aide-row {
    grid-template-columns: 1fr auto;
    gap: var(--space-1) var(--space-4);
  }
  /* Le résumé reste lisible : il passe en seconde ligne au lieu de disparaître. */
  .aide-row-summary {
    grid-column: 1 / -1;
    grid-row: 2;
  }
}
</style>
