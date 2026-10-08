<script setup>
import { ref, useId } from "vue"
import { TRACEURS_ACK_KEY } from "../legal.js"
import RiftButton from "../ui/RiftButton.vue"
import ShellBandeau from "./ShellBandeau.vue"

/* `localStorage.getItem` lève en navigation privée ou stockage bloqué : sans ce
   try/catch, le bandeau faisait planter le rendu de toute l'application. */
function acknowledged() {
  try {
    return Boolean(localStorage.getItem(TRACEURS_ACK_KEY))
  } catch {
    /* stockage indisponible : on montre le bandeau, sans pouvoir le mémoriser */
    return false
  }
}

const visible = ref(!acknowledged())

/* Sur téléphone, le bandeau n'affiche qu'une phrase : en entier il occupait une
   bonne part de l'écran tant qu'il n'était pas fermé. Le texte complet se déplie
   ici même (CSS : version courte et bouton n'existent que sous 560 px). */
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
  <ShellBandeau
    v-if="visible"
    tone="info"
    class="bandeau-traceurs"
    :class="{ 'bandeau-deplie': expanded }"
    role="region"
    aria-label="Information sur les traceurs"
  >
    <p class="bandeau-court">Traceurs nécessaires et statistiques anonymes.</p>
    <p :id="fullId" class="bandeau-complet">
      Riftarium n'utilise que les traceurs nécessaires à la connexion. Les visites sont comptées de façon anonyme, sans
      cookie ni publicité.
      <RouterLink to="/cookies" class="bandeau-lien">Politique de traceurs</RouterLink>
    </p>
    <template #actions>
      <RiftButton
        variant="ghost"
        size="sm"
        class="bandeau-plus"
        :aria-expanded="expanded"
        :aria-controls="fullId"
        @click="expanded = !expanded"
      >
        {{ expanded ? "Réduire" : "En savoir plus" }}
      </RiftButton>
      <RiftButton variant="primary" size="sm" class="bandeau-ok" @click="dismiss">J'ai compris</RiftButton>
    </template>
  </ShellBandeau>
</template>

<style scoped>
/* Lien noyé dans le texte : le soulignement le distingue sans dépendre de la couleur. */
.bandeau-lien {
  text-decoration: underline;
  text-underline-offset: 2px;
}
/* Phrase courte et bouton de dépliage : n'existent que sur téléphone (≤ 560 px).
   Sélecteurs à deux classes : ils doivent l'emporter sur l'affichage de RiftButton. */
.bandeau-traceurs .bandeau-court,
.bandeau-actions .bandeau-plus {
  display: none;
}
@media (max-width: 560px) {
  .bandeau-traceurs .bandeau-court {
    display: block;
  }
  .bandeau-actions .bandeau-plus {
    display: inline-flex;
  }
  .bandeau-traceurs:not(.bandeau-deplie) .bandeau-complet {
    display: none;
  }
  .bandeau-traceurs.bandeau-deplie .bandeau-court {
    display: none;
  }
}
</style>
