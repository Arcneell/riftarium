<script setup>
import { computed } from "vue"
import { parseCardText } from "../cardText.js"

/* Texte de règle enrichi : **gras**, glyphes officiels (:rb_…:) et mots-clés
   entre crochets rendus comme dans la cartothèque. Les symboles abrégés des
   règles officielles ([R], [1], [E]…) sont convertis vers les glyphes. */
const props = defineProps({ text: { type: String, default: "" } })

const SHORT_TOKENS = {
  R: ":rb_rune_fury:",
  G: ":rb_rune_calm:",
  B: ":rb_rune_mind:",
  O: ":rb_rune_body:",
  P: ":rb_rune_chaos:",
  Y: ":rb_rune_order:",
  C: ":rb_rune_rainbow:",
  E: ":rb_exhaust:",
  M: ":rb_might:"
}

/* Glyphes d'énergie publiés par Riot : de 0 à 12. Le texte officiel ne va pas
   plus haut (`[0]` à `[8]` et `[12]` dans data/rules-fr.json) et au-delà aucun
   fichier n'existe : mieux vaut laisser « [42] » en clair qu'une image cassée. */
const MAX_ENERGY_GLYPH = 12

const expand = (text) =>
  text.replace(/\[([RGBOPYCEM]|\d{1,2})\]/g, (raw, token) => {
    if (SHORT_TOKENS[token]) return SHORT_TOKENS[token]
    const amount = Number(token)
    return Number.isInteger(amount) && amount <= MAX_ENERGY_GLYPH ? `:rb_energy_${amount}:` : raw
  })

const segments = computed(() => {
  const out = []
  for (const [i, chunk] of expand(props.text).split("**").entries()) {
    if (!chunk) continue
    out.push({ bold: i % 2 === 1, parts: parseCardText(chunk) })
  }
  return out
})
</script>

<template>
  <span>
    <component :is="segment.bold ? 'b' : 'span'" v-for="(segment, s) in segments" :key="s">
      <template v-for="(part, i) in segment.parts" :key="i">
        <span v-if="part.type === 'text'">{{ part.value }}</span>
        <span v-else-if="part.type === 'keyword'" class="rb-kw" :class="[part.family, { arrow: part.arrow }]">{{
          part.label
        }}</span>
        <span
          v-else-if="part.kind === 'ink'"
          class="rb-glyph ink"
          :style="{ '--glyph': `url(${part.src})` }"
          role="img"
          :aria-label="part.label"
          :title="part.label"
        ></span>
        <img
          v-else
          class="rb-glyph"
          :class="part.kind"
          :src="part.src"
          :alt="part.label"
          :title="part.label"
          width="18"
          height="18"
          loading="lazy"
        />
      </template>
    </component>
  </span>
</template>
