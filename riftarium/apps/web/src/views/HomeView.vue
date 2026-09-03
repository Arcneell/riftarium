<script setup>
import { onBeforeUnmount, onMounted, ref } from "vue"
import { RouterLink } from "vue-router"
import { api, cardThumb } from "../api.js"
import { BANNERS } from "../banners.js"
import { RULE_COUNTS } from "../stats.js"
import CardRiver from "../components/CardRiver.vue"

const cardCount = ref(null)
const setCount = ref(null)

/* Éventail héros : trois cartes portrait chargées depuis l'API pour éviter
   de coder en dur des hashes CDN qui peuvent changer côté Riot.
   --halo : chaque carte émet la lumière de son illustration. */
const FAN_STYLES = [
  "left:2%; top:60px; rotate:-9deg; z-index:1; --halo:var(--fury)",
  "left:30%; top:18px; rotate:1deg; z-index:2; --halo:var(--gold)",
  "left:58%; top:52px; rotate:9deg; z-index:1; --halo:var(--mind)"
]
const fanCards = ref([])

/* L'éventail du héros est masqué par le CSS sous 761 px : sans ce v-if, le
   téléphone téléchargerait quand même trois visuels de 460 px de large pour rien.
   Repli à vrai quand matchMedia manque (tests) : on garde l'éventail. */
const fanQuery = typeof window !== "undefined" && window.matchMedia ? window.matchMedia("(min-width: 761px)") : null
const showFan = ref(fanQuery ? fanQuery.matches : true)
function onFanQuery(event) {
  showFan.value = event.matches
}

const splashStyle = { "--splash": `url("${BANNERS.home}")` }

/* Les salles de la vitrine : une bande cinématique par pilier du site, l'art
   officiel en fond, un accent de domaine par salle. La première n'a pas d'art :
   la rivière de cartes est son visuel. */
const HALLS = [
  {
    id: "decks",
    chip: "var(--fury)",
    art: BANNERS.decks,
    flip: false,
    eyebrow: "L'atelier",
    title: "Des decks vérifiés en direct",
    text: "Le deck builder vérifie les règles officielles à mesure que vous ajoutez des cartes ; si la liste n'est pas légale, il vous dit pourquoi. Vous pouvez aussi publier vos decks et importer ceux des autres joueurs.",
    links: [
      { to: "/decks", label: "Construire un deck", gold: true },
      { to: "/communaute", label: "Decks de la communauté" }
    ]
  },
  {
    id: "collection",
    chip: "var(--body)",
    art: BANNERS.collection,
    flip: true,
    eyebrow: "La collection",
    title: "Ce que vous avez, ce qui vous manque",
    text: "Notez vos exemplaires avec leur quantité, leur état et leur langue, suivez la complétion de chaque set, gardez le reste en wishlist. Pour trier un classeur, le scanner lit le code de la carte et l'ajoute pour vous.",
    links: [
      { to: "/collection", label: "Suivre ma collection", gold: true },
      { to: "/scan", label: "Scanner une carte" },
      { to: "/wishlist", label: "Ma wishlist" }
    ]
  },
  {
    id: "regles",
    chip: "var(--gold)",
    art: BANNERS.rules,
    flip: false,
    eyebrow: "Pendant la partie",
    title: "Une règle, tout de suite",
    text: "Un doute en pleine partie ? Le guide du débutant montre le jeu sur un plateau animé, l'aide avancée explique chaque mécanique avec des cas concrets, et le texte officiel complet se cherche en français.",
    links: [{ to: "/regles", label: "Ouvrir les règles", gold: true }],
    plaque: true
  }
]

/* Précharge la cinématique du héros : un fond CSS n'est découvert qu'au premier
   rendu, trop tard pour le LCP. Posé au montage et retiré au démontage, pour ne
   pas laisser une balise orpheline dans le <head> après navigation. */
let preload = null

onBeforeUnmount(() => {
  fanQuery?.removeEventListener?.("change", onFanQuery)
  preload?.remove()
  preload = null
})

onMounted(async () => {
  fanQuery?.addEventListener?.("change", onFanQuery)
  if (typeof document !== "undefined") {
    preload = document.createElement("link")
    /* setAttribute et non les propriétés : `as` et `fetchpriority` ne sont pas
       reflétées partout (jsdom compris) et la balise partirait incomplète. */
    preload.setAttribute("rel", "preload")
    preload.setAttribute("as", "image")
    preload.setAttribute("href", BANNERS.home)
    preload.setAttribute("fetchpriority", "high")
    document.head.appendChild(preload)
  }
  try {
    const [sets, cards, fan] = await Promise.all([
      api("/api/sets"),
      api("/api/cards?size=1"),
      api("/api/cards?size=12&sort=random")
    ])
    setCount.value = sets.length
    cardCount.value = cards.total
    /* On garde uniquement les cartes portrait (pas de champs de bataille) pour
       l'éventail héros : les cartes landscape brisent le ratio de la pochette. */
    fanCards.value = fan.items.filter((c) => c.orientation !== "landscape" && c.image_url).slice(0, 3)
  } catch {
    /* les chiffres arriveront au prochain chargement */
  }
})
</script>

<template>
  <section class="hero-splash hero-full" :style="splashStyle">
    <div class="hero-beam" aria-hidden="true"></div>
    <div class="wrap hero-grid">
      <div class="hero-copy">
        <p class="eyebrow">Le compagnon pour Riftbound</p>
        <h1>Vos cartes, vos decks, <br class="hide-mobile" /><em class="h1-accent">vos règles.</em></h1>
        <p class="lead" style="margin-top: 20px">
          Cartothèque, suivi de collection, deck builder et texte officiel des règles, en français.
        </p>
        <div class="hero-cta">
          <RouterLink class="btn btn-gold" to="/cartes">Voir les cartes</RouterLink>
          <RouterLink class="btn" to="/regles">Lire les règles</RouterLink>
        </div>
        <div class="hero-stats">
          <div class="hero-stat">
            <b>{{ cardCount ?? "—" }}</b>
            <span>cartes</span>
          </div>
          <div class="hero-stat">
            <b>{{ setCount ?? "—" }}</b>
            <span>sets</span>
          </div>
          <div class="hero-stat">
            <b>{{ RULE_COUNTS.core.toLocaleString("fr-FR") }}</b>
            <span>règles du jeu</span>
          </div>
          <div class="hero-stat">
            <b>{{ RULE_COUNTS.tournament.toLocaleString("fr-FR") }}</b>
            <span>règles de tournoi</span>
          </div>
        </div>
      </div>
      <div v-if="showFan && fanCards.length" class="hero-fan" aria-hidden="true">
        <div v-for="(card, i) in fanCards" :key="card.id" v-tilt class="fan-card" :style="FAN_STYLES[i]">
          <div class="card-art">
            <!-- Décoratives : priorité basse pour laisser la bande passante à la cinématique (LCP). -->
            <img :src="cardThumb(card.image_url, 460)" alt="" loading="eager" fetchpriority="low" />
            <span class="fan-foil"></span>
          </div>
        </div>
      </div>
    </div>
    <span class="hero-cue" aria-hidden="true"></span>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>

  <!-- Salle d'entrée : la cartothèque, la rivière de cartes pour visuel. -->
  <section class="hall hall-river" style="--chip: var(--mind)">
    <div class="wrap hall-head" v-reveal>
      <p class="eyebrow">La cartothèque</p>
      <h2>Toutes les cartes du jeu</h2>
      <p class="lead">
        La recherche couvre le nom et le texte des cartes, les filtres font le reste : domaine, type, rareté, coût, set.
        Les variantes alt-art et les signatures y sont, avec leur prix indicatif.
      </p>
    </div>
    <CardRiver />
    <div class="wrap hall-cta" style="justify-content: center" v-reveal>
      <RouterLink class="btn btn-gold" to="/cartes">Ouvrir la cartothèque</RouterLink>
    </div>
  </section>

  <section
    v-for="hall in HALLS"
    :key="hall.id"
    class="hall hall-art"
    :class="{ flip: hall.flip }"
    :style="{ '--chip': hall.chip, '--art': `url('${hall.art}')` }"
  >
    <div class="wrap hall-grid">
      <div class="hall-copy" v-reveal>
        <p class="eyebrow">{{ hall.eyebrow }}</p>
        <h2>{{ hall.title }}</h2>
        <p class="lead">{{ hall.text }}</p>
        <div class="hall-cta">
          <RouterLink
            v-for="link in hall.links"
            :key="link.to"
            class="btn"
            :class="{ 'btn-gold': link.gold, 'btn-ghost': !link.gold }"
            :to="link.to"
          >
            {{ link.label }}
          </RouterLink>
        </div>
      </div>
      <div v-if="hall.plaque" class="golden-rule hall-plaque" v-reveal="1">
        <p class="eyebrow">Règle 002 — la Règle d'or</p>
        <p class="golden-rule-text">
          « Ce qui est inscrit sur une carte a priorité sur ce qui est inscrit dans les règles du jeu. »
        </p>
        <p class="muted mono" style="font-size: 0.74rem; margin-top: 14px">Règles du jeu Riftbound · © Riot Games</p>
      </div>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>

  <div class="wrap made-by" v-reveal>
    <p>
      Riftarium est un projet fan-made gratuit, sans pub ni boutique, développé par un joueur —
      <a href="https://github.com/Arcneell/riftarium" target="_blank" rel="noopener">code source sur GitHub</a>.
    </p>
  </div>
</template>
