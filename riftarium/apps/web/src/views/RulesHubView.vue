<script setup>
import { onMounted } from "vue"
import { useRoute, useRouter } from "vue-router"
import { RULE_COUNTS } from "../stats.js"
import { CHAPTERS, chapterPath } from "../rules/learn.js"
import { TOPICS } from "../rules/topics.js"
import { useOnline } from "../composables/useOnline.js"
import RulesHeader from "../rules/RulesHeader.vue"

const route = useRoute()
const router = useRouter()
const online = useOnline()

/* Les anciens liens /regles?doc=…&section=… pointent vers le lecteur officiel. */
onMounted(() => {
  if (route.query.doc || route.query.section || route.query.rule) {
    router.replace({ path: "/regles/officielles", query: route.query })
  }
})

const TIERS = [
  {
    to: "/regles/debutant",
    numeral: "I",
    kicker: "Commencer ici",
    title: "Apprendre à jouer",
    text: `${CHAPTERS.length} chapitres courts : comment on gagne, comment on paie, comment on combat. Puis une partie rejouée sur le plateau.`,
    go: "Ouvrir le guide",
    big: true
  },
  {
    to: "/regles/avancee",
    numeral: "II",
    kicker: "En pleine partie",
    title: "Aide avancée",
    text: "Une page par mécanique : l'essentiel, des cas concrets, des cartes d'exemple et le texte officiel.",
    go: "Chercher une mécanique"
  },
  {
    to: "/regles/officielles",
    numeral: "III",
    kicker: "Dernier recours",
    title: "Règles officielles",
    text: `Les ${RULE_COUNTS.core.toLocaleString("fr-FR")} règles du jeu et les ${RULE_COUNTS.tournament.toLocaleString("fr-FR")} règles de tournoi, en intégralité, avec recherche. C'est ce texte qui fait foi.`,
    go: "Ouvrir le texte intégral"
  }
]

const CHAPTER_PREVIEWS = CHAPTERS.slice(0, 6)

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
  <div class="wrap cards-wrap regles-hub">
    <RulesHeader title="Règles" kicker="Riftbound" />
    <p v-if="!online" class="regles-offline" role="status">
      Hors ligne : vous lisez les règles enregistrées sur cet appareil.
    </p>

    <div class="regles-portails">
      <RouterLink
        v-for="tier in TIERS"
        :key="tier.to"
        class="portail"
        :class="{ 'portail-big': tier.big }"
        :to="tier.to"
      >
        <span class="portail-num" aria-hidden="true">{{ tier.numeral }}</span>
        <div class="portail-body">
          <p class="portail-kicker">{{ tier.kicker }}</p>
          <h2>{{ tier.title }}</h2>
          <p class="portail-text">{{ tier.text }}</p>
          <span class="portail-go">{{ tier.go }} →</span>
        </div>
      </RouterLink>
    </div>

    <section class="regles-bloc" aria-labelledby="regles-chapitres">
      <h2 id="regles-chapitres" class="regles-bloc-title">Chapitres du guide</h2>
      <div class="regles-chapitres">
        <RouterLink
          v-for="(item, i) in CHAPTER_PREVIEWS"
          :key="item.slug"
          class="chapitre-card"
          :to="chapterPath(item.slug)"
        >
          <span class="chapitre-num">{{ i + 1 }}</span>
          <b>{{ item.title }}</b>
          <span class="chapitre-sum">{{ item.summary }}</span>
        </RouterLink>
        <RouterLink class="chapitre-card" to="/regles/debutant">
          <span class="chapitre-num">+</span>
          <b>Tous les chapitres</b>
          <span class="chapitre-sum">Les {{ CHAPTERS.length }} chapitres, puis le plateau animé</span>
        </RouterLink>
      </div>
    </section>

    <section class="regles-bloc" aria-labelledby="regles-acces">
      <h2 id="regles-acces" class="regles-bloc-title">Accès rapide</h2>
      <div class="regles-quick-row">
        <RouterLink
          v-for="topic in QUICK_TOPICS"
          :key="topic.slug"
          class="regles-quick"
          :to="`/regles/avancee/${topic.slug}`"
        >
          {{ topic.title }}
        </RouterLink>
      </div>
    </section>

    <aside class="regles-or">
      <p class="regles-or-kicker">Règle 002 : la Règle d'or</p>
      <p class="regles-or-text">
        « Ce qui est inscrit sur une carte a priorité sur ce qui est inscrit dans les règles du jeu. »
      </p>
    </aside>
  </div>
</template>

<style scoped>
.regles-hub {
  padding-bottom: var(--space-7);
}
.regles-offline {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
  font-size: 14px;
}
.regles-portails {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-4);
  margin-bottom: var(--space-6);
}
.portail {
  --portail-accent: var(--bronze);
  display: flex;
  align-items: flex-start;
  gap: var(--space-4);
  min-height: 44px;
  padding: var(--space-5);
  background: var(--bg-raised);
  border-left: 3px solid var(--portail-accent);
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  text-decoration: none;
  clip-path: polygon(10px 0, 100% 0, 100% calc(100% - 10px), calc(100% - 10px) 100%, 0 100%, 0 10px);
  transition:
    box-shadow 0.15s,
    transform 0.15s;
}
.portail-big {
  --portail-accent: var(--blood);
  grid-column: 1 / -1;
}
.portail:hover,
.portail:focus-visible {
  box-shadow: inset 0 0 0 1px var(--bronze-light);
  transform: translateX(2px);
}
.portail:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -4px;
}
.portail-num {
  flex: none;
  min-width: 56px;
  color: var(--bronze);
  font-family: var(--font-display);
  font-size: 48px;
  font-weight: 700;
  line-height: 1;
}
.portail-body {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
  min-width: 0;
}
.portail-kicker {
  margin: 0;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
/* `h2` : neutralise le style de base. */
.portail h2 {
  margin: 0;
  padding: 0;
  background: none;
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 700;
  line-height: 1.2;
}
.portail-text {
  margin: 0;
  color: var(--ink-muted);
  line-height: 1.5;
}
.portail-go {
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 15px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.regles-bloc {
  margin: 0 0 var(--space-6);
  padding: 0;
}
.regles-bloc-title {
  margin: 0 0 var(--space-3);
  padding: 0;
  background: none;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 16px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.regles-chapitres {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: var(--space-3);
}
.chapitre-card {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  min-height: 44px;
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  text-decoration: none;
  transition: box-shadow 0.15s;
}
.chapitre-card:hover,
.chapitre-card:focus-visible {
  box-shadow: inset 0 0 0 1px var(--bronze-light);
}
.chapitre-card:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -4px;
}
.chapitre-num {
  color: var(--bronze);
  font-family: var(--font-display);
  font-size: 22px;
  font-weight: 700;
}
.chapitre-sum {
  color: var(--ink-muted);
  font-size: 14px;
  line-height: 1.4;
}
.regles-quick-row {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
.regles-quick {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  padding: 0 var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 15px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  text-decoration: none;
  transition:
    box-shadow 0.15s,
    color 0.15s;
}
.regles-quick:hover,
.regles-quick:focus-visible {
  box-shadow: inset 0 0 0 1px var(--bronze-light);
  color: var(--bronze-light);
}
.regles-quick:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.regles-or {
  padding: var(--space-5);
  background: var(--bg-sunken);
  border-top: 2px solid var(--blood);
  box-shadow: inset 0 0 0 1px var(--line);
  clip-path: polygon(10px 0, 100% 0, 100% calc(100% - 10px), calc(100% - 10px) 100%, 0 100%, 0 10px);
}
.regles-or-kicker {
  margin: 0 0 var(--space-2);
  color: var(--blood-text);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.regles-or-text {
  margin: 0;
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 20px;
  font-style: italic;
  line-height: 1.5;
}
@media (max-width: 767px) {
  .regles-portails {
    grid-template-columns: 1fr;
  }
  .regles-chapitres {
    grid-template-columns: 1fr 1fr;
  }
}
@media (max-width: 480px) {
  .regles-chapitres {
    grid-template-columns: 1fr;
  }
}
@media (prefers-reduced-motion: reduce) {
  .portail,
  .chapitre-card,
  .regles-quick {
    transition: none;
  }
  .portail:hover,
  .portail:focus-visible {
    transform: none;
  }
}
</style>
