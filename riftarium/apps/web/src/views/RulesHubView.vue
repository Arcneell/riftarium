<script setup>
import { onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { BANNERS } from "../banners.js"
import { RULE_COUNTS } from "../stats.js"
import { TOPICS } from "../rules/topics.js"
import { useOnline } from "../composables/useOnline.js"
import PageBanner from "../components/PageBanner.vue"

const route = useRoute()
const router = useRouter()
const online = useOnline()

/* Les anciens liens /regles?doc=…&section=… pointent vers le lecteur officiel. */
onMounted(() => {
  if (route.query.doc || route.query.section || route.query.rule) {
    router.replace({ path: "/regles/officielles", query: route.query })
  }
})

/* Trois portes, dans l'ordre d'un apprentissage : le numéral romain porte la
   séquence, la couleur porte la destination (hex = tutoriel, or = aide,
   champagne = texte de référence). */
const TIERS = [
  {
    to: "/regles/debutant",
    chip: "var(--hex)",
    numeral: "I",
    kicker: "Commencer ici",
    title: "Guide du débutant",
    text: "Un tutoriel animé sur un plateau : placer ses cartes, jouer un tour, combattre, marquer.",
    go: "Apprendre à jouer",
    big: true
  },
  {
    to: "/regles/avancee",
    chip: "var(--gold)",
    numeral: "II",
    kicker: "En pleine partie",
    title: "Aide avancée",
    text: "Une page par mécanique : l'essentiel, des cas concrets, des cartes d'exemple et le texte officiel.",
    go: "Chercher une mécanique"
  },
  {
    to: "/regles/officielles",
    chip: "var(--gold-deep)",
    numeral: "III",
    kicker: "Dernier recours",
    title: "Règles officielles",
    text: `Les ${RULE_COUNTS.core.toLocaleString("fr-FR")} règles du jeu et les ${RULE_COUNTS.tournament.toLocaleString("fr-FR")} règles de tournoi, intégrales et cherchables. Le texte qui fait foi.`,
    go: "Ouvrir le texte intégral"
  }
]

/* Les mécaniques qu'on cherche le plus souvent en cours de partie : raccourcis
   vers leur page d'aide, résolus depuis TOPICS pour ne jamais pointer dans le vide. */
const QUICK_SLUGS = [
  "reaction",
  "la-chaine",
  "assaut",
  "bouclier",
  "tank",
  "conquete-et-occupation",
  "embuscade",
  "agonie"
]
const QUICK_TOPICS = QUICK_SLUGS.map((slug) => TOPICS.find((t) => t.slug === slug)).filter(Boolean)
</script>

<template>
  <PageBanner :art="BANNERS.rules" title="Règles" />

  <div class="offline-note" v-if="!online" role="status">Hors ligne — règles servies depuis le cache</div>

  <section>
    <div class="wrap">
      <div class="tier-grid">
        <RouterLink
          v-for="(tier, i) in TIERS"
          :key="tier.to"
          class="tier"
          :class="{ big: tier.big }"
          :to="tier.to"
          v-reveal="i"
          :style="{ '--chip': tier.chip }"
        >
          <span class="tier-step" aria-hidden="true">{{ tier.numeral }}</span>
          <div class="tier-body">
            <p class="eyebrow">{{ tier.kicker }}</p>
            <h3>{{ tier.title }}</h3>
            <p class="tier-text">{{ tier.text }}</p>
            <span class="m-go">{{ tier.go }} <Icon name="arrow" :size="14" /></span>
          </div>
        </RouterLink>
      </div>

      <div class="quick-topics" v-reveal="1">
        <p class="eyebrow">Accès rapide</p>
        <div class="quick-topics-row">
          <RouterLink
            v-for="topic in QUICK_TOPICS"
            :key="topic.slug"
            class="quick-topic"
            :to="`/regles/avancee/${topic.slug}`"
          >
            {{ topic.title }}
          </RouterLink>
        </div>
      </div>

      <div class="golden-rule" v-reveal="2">
        <p class="eyebrow">Règle 002 — la Règle d'or</p>
        <p class="golden-rule-text">
          « Ce qui est inscrit sur une carte a priorité sur ce qui est inscrit dans les règles du jeu. »
        </p>
      </div>
    </div>
  </section>
</template>
