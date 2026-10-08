<script setup>
import { computed, onUnmounted, ref } from "vue"
import { atlasList, copyText, deckCode, nameList } from "../deckExport.js"
import { pageUrl } from "../seo.js"
import RiftButton from "../ui/RiftButton.vue"

const props = defineProps({
  deck: { type: Object, required: true }
})

const note = ref("")
let timer = 0

/* Le lien n'a d'intérêt que si un tiers peut l'ouvrir : deck public et publié.
   C'est aussi la condition de l'aperçu Discord (image générée côté serveur). */
const shareable = computed(() => Boolean(props.deck.is_public && props.deck.moderation_status === "published"))

function flash(message) {
  note.value = message
  clearTimeout(timer)
  /* 5 s : au doigt, la confirmation apparaissait sous les boutons — donc souvent
     sous le pouce — et disparaissait avant d'avoir été lue. */
  timer = window.setTimeout(() => {
    note.value = ""
  }, 5000)
}

/* Le composant peut disparaître avant l'échéance (navigation, fermeture du deck). */
onUnmounted(() => clearTimeout(timer))

async function copy(kind) {
  note.value = ""
  try {
    const text =
      kind === "atlas" ? atlasList(props.deck) : kind === "names" ? nameList(props.deck) : deckCode(props.deck)
    await copyText(text)
    flash("Copié dans le presse-papiers")
  } catch (error) {
    flash(error.message || "Copie impossible")
  }
}

async function copyLink() {
  note.value = ""
  try {
    await copyText(pageUrl(`/decks/${props.deck.id}`))
    flash("Lien copié — Discord affichera l'aperçu du deck")
  } catch (error) {
    flash(error.message || "Copie impossible")
  }
}
</script>

<template>
  <div class="lecture-export">
    <p class="lecture-export-hint">
      Collez la liste ou le code dans Rift Atlas, Piltover Archive, UVS Games ou un autre outil.
    </p>
    <p v-if="note" class="lecture-export-note" role="status">{{ note }}</p>
    <div class="lecture-export-actions">
      <RiftButton variant="primary" size="sm" @click="copy('atlas')">Liste Rift Atlas</RiftButton>
      <RiftButton variant="secondary" size="sm" @click="copy('code')">Code de deck</RiftButton>
      <RiftButton variant="secondary" size="sm" @click="copy('names')">Liste texte</RiftButton>
      <RiftButton v-if="shareable" variant="secondary" size="sm" @click="copyLink">Lien de partage</RiftButton>
    </div>
  </div>
</template>

<style scoped>
.lecture-export {
  display: grid;
  gap: var(--space-3);
}
.lecture-export-hint {
  margin: 0;
  font-family: var(--font-body);
  font-size: 13px;
  line-height: 1.4;
  color: var(--ink-muted);
}
.lecture-export-note {
  margin: 0;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.04em;
  color: var(--bronze-light);
}
.lecture-export-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
</style>
