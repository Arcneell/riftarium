<script setup>
import { ref } from "vue"
import { atlasList, copyText, deckCode, nameList } from "../deckExport.js"

const props = defineProps({
  deck: { type: Object, required: true }
})

const note = ref("")
let timer = 0

async function copy(kind) {
  note.value = ""
  try {
    const text =
      kind === "atlas" ? atlasList(props.deck) : kind === "names" ? nameList(props.deck) : deckCode(props.deck)
    await copyText(text)
    note.value = "Copié dans le presse-papiers"
  } catch (error) {
    note.value = error.message || "Copie impossible"
  }
  clearTimeout(timer)
  timer = window.setTimeout(() => {
    note.value = ""
  }, 2400)
}
</script>

<template>
  <div class="dexport">
    <p class="muted mono dexport-hint">
      Collez la liste ou le code dans Rift Atlas, Piltover Archive, UVS Games ou un autre outil.
    </p>
    <div class="dexport-actions">
      <button type="button" class="btn btn-gold btn-sm" @click="copy('atlas')">Liste Rift Atlas</button>
      <button type="button" class="btn btn-ghost btn-sm" @click="copy('code')">Code de deck</button>
      <button type="button" class="btn btn-ghost btn-sm" @click="copy('names')">Liste texte</button>
    </div>
    <p v-if="note" class="dexport-note" role="status">{{ note }}</p>
  </div>
</template>
