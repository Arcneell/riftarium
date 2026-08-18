<script setup>
import { computed, ref } from "vue"
import { CATEGORIES, ENTRIES } from "../rules/help.js"

const query = ref("")
const category = ref("")
const open = ref(new Set())

const normalize = (value) => value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()

const filtered = computed(() => {
  const tokens = normalize(query.value.trim()).split(/\s+/).filter(Boolean)
  return ENTRIES.filter((entry) => {
    if (category.value && entry.category !== category.value) return false
    if (!tokens.length) return true
    const haystack = normalize(`${entry.title} ${entry.summary} ${entry.details.join(" ")}`)
    return tokens.every((token) => haystack.includes(token))
  })
})

const label = (key) => CATEGORIES.find((c) => c.key === key)?.label ?? key

function toggle(title) {
  open.value.has(title) ? open.value.delete(title) : open.value.add(title)
  open.value = new Set(open.value)
}
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Aide avancée</p>
      <h2>Chaque mécanique, expliquée clairement</h2>
      <p class="lead">
        Une situation bloque la partie ? Cherchez la mécanique concernée : timing, combat, points, mots-clés. Chaque
        fiche renvoie à la règle officielle.
      </p>
    </div>
  </div>

  <section style="padding-top: 36px">
    <div class="wrap">
      <div class="toolbar">
        <div class="filters" role="tablist" aria-label="Catégorie">
          <button class="filter" :aria-pressed="category === ''" @click="category = ''">Tout</button>
          <button
            v-for="c in CATEGORIES"
            :key="c.key"
            class="filter"
            :aria-pressed="category === c.key"
            @click="category = category === c.key ? '' : c.key"
          >
            {{ c.label }}
          </button>
        </div>
        <label class="search">
          <Icon name="search" :size="18" />
          <input
            type="search"
            v-model="query"
            placeholder="tank, conquête, réaction…"
            aria-label="Rechercher une mécanique"
          />
        </label>
      </div>

      <p class="muted mono" v-if="!filtered.length" style="font-size: 0.8rem">
        Rien ici. Essayez un autre mot, ou passez par les
        <RouterLink to="/regles/officielles">règles officielles</RouterLink>.
      </p>

      <div class="help-grid">
        <article
          v-for="(entry, i) in filtered"
          :key="entry.title"
          class="help-card"
          :class="{ open: open.has(entry.title) }"
          v-reveal="i % 3"
        >
          <button class="help-head" @click="toggle(entry.title)" :aria-expanded="open.has(entry.title)">
            <span class="help-cat mono">{{ label(entry.category) }}</span>
            <h3>{{ entry.title }}</h3>
            <p class="help-summary">{{ entry.summary }}</p>
            <span class="help-caret" aria-hidden="true">▾</span>
          </button>
          <div class="help-body" v-if="open.has(entry.title)">
            <p v-for="(line, j) in entry.details" :key="j">{{ line }}</p>
            <RouterLink class="rref" :to="`/regles/officielles?doc=core&section=${entry.ref}`">
              → Règle {{ entry.ref }}
            </RouterLink>
          </div>
        </article>
      </div>

      <div style="text-align: center; margin-top: 44px" v-reveal>
        <p class="muted" style="font-size: 0.85rem; margin-bottom: 14px">Pas trouvé ? Le texte intégral fait foi.</p>
        <RouterLink class="btn" to="/regles/officielles">Chercher dans les règles officielles</RouterLink>
      </div>
    </div>
  </section>
</template>
