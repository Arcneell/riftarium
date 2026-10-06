<script setup>
import { onMounted, ref } from "vue"
import { api } from "../api.js"
import CardWall from "../home/CardWall.vue"
import HomeBlocks from "../home/HomeBlocks.vue"
import { pickSplash } from "../home/homeData.js"
import HomeSplash from "../home/HomeSplash.vue"

/* Accueil Forge noxienne : splash cinématique, mur de cartes du dernier set, blocs
   Forgés (visiteur ou membre). L'illustration change à chaque visite. */
const art = pickSplash()
const cardCount = ref(null)
const setCount = ref(null)

onMounted(async () => {
  try {
    const [sets, cards] = await Promise.all([api("/api/sets"), api("/api/cards?size=1")])
    setCount.value = sets.length
    cardCount.value = cards.total
  } catch {
    /* les chiffres restent masqués : le splash se suffit à lui-même */
  }
})
</script>

<template>
  <HomeSplash :art="art" :card-count="cardCount" :set-count="setCount" />
  <CardWall />
  <HomeBlocks />
</template>
