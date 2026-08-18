<script setup>
import { onMounted, ref } from "vue"
import { api } from "../api.js"
import CardRiver from "../components/CardRiver.vue"

const cardCount = ref(null)
const setCount = ref(null)

/* Trois « Overnumbered » : les illustrations alternatives numérotées au-delà du set. */
const FAN = [
  {
    hash: "8a7dbbed04133926e58843f1d586f51178ef2ebd-1488x2078.png",
    style: "left:2%; top:60px; rotate:-9deg; z-index:1"
  },
  {
    hash: "dc89c6a2415debd5bf504ed46843f5dcc1d9b815-1488x2078.png",
    style: "left:30%; top:18px; rotate:1deg; z-index:2"
  },
  {
    hash: "2c804ec513085702763a9145fac93a8adb6c4783-1488x2078.png",
    style: "left:58%; top:52px; rotate:9deg; z-index:1"
  }
]
const cardImg = (hash) =>
  `https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/${hash}?auto=format&fit=max&w=460&accountingTag=RB`

const MODULES = [
  {
    icon: "cards",
    chip: "var(--mind)",
    title: "Cartothèque",
    text: "Toutes les cartes du jeu, variantes incluses. Recherche plein texte, filtres par domaine, type, rareté et set.",
    to: "/cartes",
    go: "Parcourir"
  },
  {
    icon: "book",
    chip: "var(--order)",
    title: "Règles",
    text: "Le texte officiel intégral en français, consultable et cherchable en quelques secondes.",
    to: "/regles",
    go: "Consulter"
  },
  {
    icon: "layers",
    chip: "var(--fury)",
    title: "Deck builder",
    text: "Construisez vos decks avec validation des règles de tournoi — ou en mode libre, sans contrainte.",
    to: "/decks",
    go: "Construire"
  },
  {
    icon: "box",
    chip: "var(--body)",
    title: "Collection",
    text: "Suivez ce que vous possédez : quantités, état, langue. Votre inventaire, toujours à jour.",
    to: "/collection",
    go: "Inventorier"
  },
  {
    icon: "users",
    chip: "var(--chaos)",
    title: "Communauté",
    text: "Parcourez les decks publiés par les autres joueurs, votez pour vos préférés, partagez les vôtres.",
    to: "/communaute",
    go: "Découvrir"
  },
  {
    icon: "code",
    chip: "var(--calm)",
    title: "Fait par un joueur",
    text: "Gratuit, au code source accessible, sans pub ni boutique. Les retours et les idées sont bienvenus.",
    href: "https://github.com/Arcneell/riftarium",
    go: "Voir sur GitHub"
  }
]

onMounted(async () => {
  try {
    const [sets, health] = await Promise.all([api("/api/sets"), api("/api/health")])
    setCount.value = sets.length
    cardCount.value = health.cards
  } catch {
    /* les chiffres arriveront au prochain chargement */
  }
})
</script>

<template>
  <section
    class="hero-splash"
    style="
      --splash: url(&quot;https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png?auto=format&w=1920&quot;);
    "
  >
    <div class="wrap hero-grid">
      <div>
        <p class="eyebrow">Le compagnon tout-en-un pour Riftbound</p>
        <h1>Vos cartes, vos decks,<br />vos règles. Un seul site.</h1>
        <p class="lead" style="margin-top: 20px">
          Cartothèque complète, suivi de collection, deck builder et règles officielles : tout ce qu'il faut pour jouer
          à Riftbound, réuni au même endroit.
        </p>
        <div style="display: flex; gap: 16px; margin-top: 34px; flex-wrap: wrap">
          <RouterLink class="btn btn-gold" to="/cartes">Voir les cartes</RouterLink>
          <RouterLink class="btn" to="/regles">Lire les règles</RouterLink>
        </div>
      </div>
      <div class="hero-fan" aria-hidden="true">
        <div v-for="card in FAN" :key="card.hash" v-tilt class="fan-card" :style="card.style">
          <img :src="cardImg(card.hash)" alt="" loading="eager" />
          <span class="fan-foil"></span>
        </div>
      </div>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>

  <div class="wrap" v-reveal>
    <div class="figures">
      <div class="figure">
        <b>{{ cardCount ?? "—" }}</b
        ><span>cartes</span>
      </div>
      <div class="figure">
        <b>{{ setCount ?? "—" }}</b
        ><span>sets</span>
      </div>
      <div class="figure"><b>2 137</b><span>règles du jeu</span></div>
      <div class="figure"><b>812</b><span>règles de tournoi</span></div>
    </div>
  </div>

  <section style="padding-bottom: 40px">
    <div class="wrap" style="margin-bottom: 36px">
      <p class="eyebrow" v-reveal>Les cartes</p>
      <h2 v-reveal>Toutes les cartes du jeu, à jour</h2>
    </div>
    <CardRiver />
    <div class="wrap" style="text-align: center; margin-top: 36px" v-reveal>
      <RouterLink class="btn btn-gold" to="/cartes">Explorer la cartothèque</RouterLink>
    </div>
  </section>

  <section>
    <div class="wrap">
      <p class="eyebrow" v-reveal>Tout-en-un</p>
      <h2 v-reveal style="margin-bottom: 36px">Tout ce qu'il faut pour jouer</h2>
      <div class="modules">
        <component
          :is="module.to ? 'RouterLink' : 'a'"
          v-for="(module, i) in MODULES"
          :key="module.title"
          class="module"
          v-reveal="i % 3"
          :to="module.to"
          :href="module.href"
          :target="module.href ? '_blank' : undefined"
          :style="{ '--chip': module.chip }"
        >
          <span class="m-icon"><Icon :name="module.icon" :size="24" /></span>
          <h3>{{ module.title }}</h3>
          <p>{{ module.text }}</p>
          <span class="m-go">{{ module.go }} <Icon name="arrow" :size="14" /></span>
        </component>
      </div>
    </div>
  </section>

  <div
    class="interlude"
    role="img"
    aria-label="Illustration officielle Riftbound"
    style="
      --art: url(&quot;https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/91a720561b6cd9c649a9148782f34d96e78cd894-4320x2430.jpg?auto=format&w=1800&quot;);
    "
  >
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </div>

  <section>
    <div class="wrap cols-2">
      <div v-reveal>
        <p class="eyebrow">Pendant la partie</p>
        <h2>Une règle, tout de suite</h2>
        <p class="lead" style="margin-bottom: 18px">
          Un doute sur un effet ou une interaction ? Cherchez un mot-clé et retrouvez la règle exacte, avec son
          contexte.
        </p>
        <p class="muted" style="margin-bottom: 26px">Sur téléphone comme sur ordinateur, en pleine partie.</p>
        <RouterLink class="btn btn-gold" to="/regles">Ouvrir les règles</RouterLink>
      </div>
      <div class="panel" v-reveal="1">
        <p class="eyebrow">Règle 002 — la Règle d'or</p>
        <p style="font-family: var(--font-display); font-size: 1.25rem; line-height: 1.5; color: var(--ink-strong)">
          « Ce qui est inscrit sur une carte a priorité sur ce qui est inscrit dans les règles du jeu. »
        </p>
        <p class="muted mono" style="font-size: 0.74rem; margin-top: 14px">Règles du jeu Riftbound · © Riot Games</p>
      </div>
    </div>
  </section>

  <section style="padding-top: 32px; padding-bottom: 104px">
    <div class="wrap cols-2">
      <div class="panel" v-reveal>
        <h3 style="margin-bottom: 10px">Gratuit, sans pub</h3>
        <p class="muted" style="font-size: 0.95rem">
          Riftarium est un projet fan-made, non commercial et indépendant de Riot Games. Pas de boutique, pas de
          publicité.
        </p>
      </div>
      <div class="panel" v-reveal="1">
        <h3 style="margin-bottom: 10px">Un projet de joueur</h3>
        <p class="muted" style="font-size: 0.95rem">
          Le code est ouvert et le site évolue avec vos retours. Une idée, un bug ? Rendez-vous sur
          <a href="https://github.com/Arcneell/riftarium" target="_blank" rel="noopener">GitHub</a>.
        </p>
      </div>
    </div>
  </section>
</template>
