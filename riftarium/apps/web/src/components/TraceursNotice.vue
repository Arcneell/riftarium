<script setup>
import { ref, useId } from "vue"
import { TRACEURS_ACK_KEY } from "../legal.js"

const visible = ref(typeof localStorage !== "undefined" && !localStorage.getItem(TRACEURS_ACK_KEY))

/* Sur téléphone, le bandeau n'affiche qu'une phrase : en entier il occupait le
   cinquième bas de chaque écran tant qu'il n'était pas fermé. Le texte complet
   se déplie ici même (CSS : version courte et bouton n'existent que sous 560 px). */
const expanded = ref(false)
const fullId = useId()

function dismiss() {
  try {
    localStorage.setItem(TRACEURS_ACK_KEY, "1")
  } catch {
    /* stockage indisponible (tests / mode privé) */
  }
  visible.value = false
}
</script>

<template>
  <div
    v-if="visible"
    class="traceurs-notice"
    :class="{ expanded }"
    role="dialog"
    aria-label="Information sur les traceurs"
  >
    <div class="traceurs-copy">
      <p class="traceurs-short">Traceurs nécessaires et statistiques anonymes.</p>
      <p :id="fullId" class="traceurs-full">
        Riftarium n'utilise que des traceurs strictement nécessaires à la connexion, plus des statistiques de
        fréquentation anonymes et agrégées, sans cookie — pas de publicité.
        <RouterLink to="/cookies">Politique de traceurs</RouterLink>
      </p>
    </div>
    <div class="traceurs-actions">
      <button
        type="button"
        class="traceurs-more"
        :aria-expanded="expanded"
        :aria-controls="fullId"
        @click="expanded = !expanded"
      >
        {{ expanded ? "Réduire" : "En savoir plus" }}
      </button>
      <button class="btn btn-gold btn-sm traceurs-ack" type="button" @click="dismiss">J'ai compris</button>
    </div>
  </div>
</template>
