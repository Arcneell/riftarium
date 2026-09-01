<script setup>
import { onBeforeUnmount, onMounted, ref } from "vue"
import { RouterLink } from "vue-router"
import { api } from "../api.js"
import { BANNERS } from "../banners.js"
import { RULE_COUNTS } from "../stats.js"
import CardRiver from "../components/CardRiver.vue"

const cardCount = ref(null)
const setCount = ref(null)

/* Trois cartes « Signature » (signées par leur illustrateur) :
   Ahri - Nine-Tailed Fox, Lee Sin - Blind Monk, Kai'Sa - Daughter of the Void. */
const FAN = [
  {
    hash: "e5fe571a8f09c0a9e76345ec32b446480f54617c-1488x2078.png",
    style: "left:2%; top:60px; rotate:-9deg; z-index:1"
  },
  {
    hash: "b4dfd543b1cfcdefba4568fe78146e0d6e46add7-1488x2078.png",
    style: "left:30%; top:18px; rotate:1deg; z-index:2"
  },
  {
    hash: "ae8e68af43400f61f7391c0a6ee339fd718a7540-1488x2078.png",
    style: "left:58%; top:52px; rotate:9deg; z-index:1"
  }
]
const cardImg = (hash) =>
  `https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/${hash}?auto=format&fit=max&w=460&accountingTag=RB`

/* Précharge la cinématique du héros dès l'évaluation du bundle : un fond CSS n'est
   découvert qu'au premier rendu, trop tard pour le LCP de la page d'accueil. */
if (typeof document !== "undefined" && window.location.pathname === "/") {
  const link = document.createElement("link")
  link.rel = "preload"
  link.as = "image"
  link.href = BANNERS.home
  link.fetchPriority = "high"
  document.head.appendChild(link)
}

/* L'éventail du héros est masqué par le CSS sous 761 px : sans ce v-if, le
   téléphone téléchargerait quand même trois visuels de 460 px de large pour rien.
   Repli à vrai quand matchMedia manque (tests) : on garde l'éventail. */
const fanQuery = typeof window !== "undefined" && window.matchMedia ? window.matchMedia("(min-width: 761px)") : null
const showFan = ref(fanQuery ? fanQuery.matches : true)
function onFanQuery(event) {
  showFan.value = event.matches
}

const splashStyle = { "--splash": `url("${BANNERS.home}")` }
const tableStyle = { "--art": `url("${BANNERS.table}")` }

const MODULES = [
  {
    icon: "cards",
    chip: "var(--mind)",
    title: "Cartothèque",
    text: "Toutes les cartes du jeu, variantes incluses — cherchez en plein texte, filtrez par domaine, type, rareté ou set.",
    to: "/cartes",
    go: "Parcourir"
  },
  {
    icon: "book",
    chip: "var(--order)",
    title: "Règles",
    text: "Le texte officiel intégral en français, avec recherche plein texte.",
    to: "/regles",
    go: "Consulter"
  },
  {
    icon: "layers",
    chip: "var(--fury)",
    title: "Deck builder",
    text: "Construisez vos decks : le site vérifie les règles officielles et vous dit si la liste est légale.",
    to: "/decks",
    go: "Construire"
  },
  {
    icon: "box",
    chip: "var(--body)",
    title: "Collection",
    text: "Suivez ce que vous possédez, avec la quantité, l'état et la langue de chaque exemplaire.",
    to: "/collection",
    go: "Inventorier"
  },
  {
    icon: "camera",
    chip: "var(--calm)",
    title: "Scanner",
    text: "L'appareil photo lit le code de la carte et ouvre sa fiche ; un geste l'ajoute à la collection.",
    to: "/scan",
    go: "Scanner"
  },
  {
    icon: "users",
    chip: "var(--chaos)",
    title: "Communauté",
    text: "Parcourez les decks publiés par les autres joueurs, votez pour vos préférés, partagez les vôtres.",
    to: "/communaute",
    go: "Voir les decks"
  },
  {
    icon: "code",
    chip: "var(--calm)",
    title: "Fait par un joueur",
    text: "Projet fan-made gratuit, sans pub ni boutique. Les retours sont bienvenus.",
    href: "https://github.com/Arcneell/riftarium",
    go: "Voir sur GitHub"
  }
]

onBeforeUnmount(() => {
  fanQuery?.removeEventListener?.("change", onFanQuery)
})

onMounted(async () => {
  fanQuery?.addEventListener?.("change", onFanQuery)
  try {
    const [sets, cards] = await Promise.all([api("/api/sets"), api("/api/cards?size=1")])
    setCount.value = sets.length
    cardCount.value = cards.total
  } catch {
    /* les chiffres arriveront au prochain chargement */
  }
})
</script>

<template>
  <section class="hero-splash" :style="splashStyle">
    <div class="wrap hero-grid">
      <div>
        <p class="eyebrow">Le compagnon pour Riftbound</p>
        <h1>Vos cartes, vos decks,<br class="hide-mobile" />vos règles.</h1>
        <p class="lead" style="margin-top: 20px">
          Cartothèque, suivi de collection, deck builder et texte officiel des règles, en français.
        </p>
        <div style="display: flex; gap: 16px; margin-top: 34px; flex-wrap: wrap">
          <RouterLink class="btn btn-gold" to="/cartes">Voir les cartes</RouterLink>
          <RouterLink class="btn" to="/regles">Lire les règles</RouterLink>
        </div>
      </div>
      <div v-if="showFan" class="hero-fan" aria-hidden="true">
        <div v-for="card in FAN" :key="card.hash" v-tilt class="fan-card" :style="card.style">
          <!-- Décoratives : priorité basse pour laisser la bande passante à la cinématique (LCP). -->
          <img :src="cardImg(card.hash)" alt="" loading="eager" fetchpriority="low" />
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
      <div class="figure">
        <b>{{ RULE_COUNTS.core.toLocaleString("fr-FR") }}</b
        ><span>règles du jeu</span>
      </div>
      <div class="figure">
        <b>{{ RULE_COUNTS.tournament.toLocaleString("fr-FR") }}</b
        ><span>règles de tournoi</span>
      </div>
    </div>
  </div>

  <section style="padding-bottom: 40px">
    <div class="wrap" style="margin-bottom: 36px">
      <p class="eyebrow" v-reveal>Cartothèque</p>
      <h2 v-reveal>Toutes les cartes du jeu</h2>
    </div>
    <CardRiver />
    <div class="wrap" style="text-align: center; margin-top: 36px" v-reveal>
      <RouterLink class="btn btn-gold" to="/cartes">Ouvrir la cartothèque</RouterLink>
    </div>
  </section>

  <section>
    <div class="wrap">
      <p class="eyebrow" v-reveal>Le site</p>
      <h2 v-reveal style="margin-bottom: 36px">Les fonctionnalités</h2>
      <div class="modules">
        <!-- Objet composant (et non la chaîne "RouterLink"), et jamais de href indéfini :
             un attribut href retombant écraserait celui que RouterLink calcule, produisant
             des <a> sans href, invisibles pour les robots d'indexation. -->
        <component
          :is="module.to ? RouterLink : 'a'"
          v-for="(module, i) in MODULES"
          :key="module.title"
          class="module"
          v-reveal="i % 3"
          v-bind="module.to ? { to: module.to } : { href: module.href, target: '_blank', rel: 'noopener' }"
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

  <div class="interlude" role="img" aria-label="Illustration officielle Riftbound" :style="tableStyle">
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
</template>
