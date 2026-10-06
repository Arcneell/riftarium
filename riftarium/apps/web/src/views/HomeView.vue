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
const sets = ref(null)

onMounted(async () => {
  /* Deux appels indépendants : les cartes en panne ne privent pas le mur de ses sets. */
  const [setsResult, cardsResult] = await Promise.allSettled([api("/api/sets"), api("/api/cards?size=1")])
  if (setsResult.status === "fulfilled") {
    sets.value = setsResult.value
    setCount.value = setsResult.value.length
  }
  if (cardsResult.status === "fulfilled") cardCount.value = cardsResult.value.total
  /* en cas d'échec, les chiffres restent masqués : le splash se suffit à lui-même */
})
</script>

<template>
  <HomeSplash :art="art" :card-count="cardCount" :set-count="setCount" />
  <CardWall :sets="sets" />
  <HomeBlocks />
</template>
