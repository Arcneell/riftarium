<script setup>
import { onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"

const route = useRoute()
const router = useRouter()

/* Les anciens liens /regles?doc=…&section=… pointent vers le lecteur officiel. */
onMounted(() => {
  if (route.query.doc || route.query.section || route.query.rule) {
    router.replace({ path: "/regles/officielles", query: route.query })
  }
})

const TIERS = [
  {
    to: "/regles/debutant",
    chip: "var(--hex)",
    kicker: "Commencer ici",
    title: "Guide du débutant",
    text: "Dix étapes animées sur un plateau : placer ses cartes, jouer un tour, combattre, marquer. Cinq minutes pour comprendre le jeu.",
    go: "Apprendre à jouer",
    big: true
  },
  {
    to: "/regles/avancee",
    chip: "var(--gold)",
    kicker: "En pleine partie",
    title: "Aide avancée",
    text: "Une page complète par mécanique : l'essentiel, des cas concrets, des cartes d'exemple et le texte officiel intégral — timing, combat, points, mots-clés.",
    go: "Chercher une mécanique"
  },
  {
    to: "/regles/officielles",
    chip: "var(--ink)",
    kicker: "Dernier recours",
    title: "Règles officielles",
    text: "Les 2 137 règles du jeu et les 812 règles de tournoi, intégrales et cherchables. Le texte qui fait foi.",
    go: "Ouvrir le texte intégral"
  }
]
</script>

<template>
  <PageBanner :art="BANNERS.rules" eyebrow="Règles" title="Trouvez la bonne réponse, au bon niveau">
    Débutant ? Suivez le guide animé. Une situation litigieuse en partie ? L'aide avancée. Et si le doute persiste, le
    texte officiel tranche.
  </PageBanner>

  <section style="padding-top: 36px">
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
          <span class="tier-step mono">{{ i + 1 }}</span>
          <p class="eyebrow">{{ tier.kicker }}</p>
          <h3>{{ tier.title }}</h3>
          <p class="tier-text">{{ tier.text }}</p>
          <span class="m-go">{{ tier.go }} <Icon name="arrow" :size="14" /></span>
        </RouterLink>
      </div>

      <div class="panel golden-rule" v-reveal="1" style="margin-top: 44px">
        <p class="eyebrow">À retenir avant tout — la Règle d'or</p>
        <p style="font-family: var(--font-display); font-size: 1.15rem; line-height: 1.5; color: var(--ink-strong)">
          « Ce qui est inscrit sur une carte a priorité sur ce qui est inscrit dans les règles du jeu. »
        </p>
      </div>
    </div>
  </section>
</template>
