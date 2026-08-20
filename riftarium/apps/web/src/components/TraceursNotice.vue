<script setup>
import { ref } from "vue"
import { TRACEURS_ACK_KEY } from "../legal.js"

const visible = ref(typeof localStorage !== "undefined" && !localStorage.getItem(TRACEURS_ACK_KEY))

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
  <div v-if="visible" class="traceurs-notice" role="dialog" aria-label="Information sur les traceurs">
    <p>
      Riftarium n'utilise que des traceurs strictement nécessaires à la connexion, plus des statistiques de
      fréquentation anonymes et agrégées, sans cookie — pas de publicité.
      <RouterLink to="/cookies">En savoir plus</RouterLink>
    </p>
    <button class="btn btn-gold btn-sm" type="button" @click="dismiss">J'ai compris</button>
  </div>
</template>
