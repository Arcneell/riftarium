<script setup>
import { onMounted, ref } from "vue";
import { api } from "../api.js";

const sets = ref([]);
const cardCount = ref(null);

const FAN = [
  { hash: "a7fe105f40df66525be51bd18e25506945a7b027-744x1039.png", alt: "Jinx, Rebel", style: "left:2%; top:60px; rotate:-9deg; z-index:1" },
  { hash: "cfa28e1abcac1db780d11e82985e13ee5978290d-744x1039.png", alt: "Ahri, Inquisitive", style: "left:30%; top:18px; rotate:1deg; z-index:2" },
  { hash: "7b71cf13a07074a6eccbe88ae6c74133d989cb68-744x1039.png", alt: "Darius, Executioner", style: "left:58%; top:52px; rotate:9deg; z-index:1" }
];
const cardImg = hash => `https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/${hash}?auto=format&fit=max&w=460&accountingTag=RB`;

onMounted(async () => {
  try {
    const [setsData, health] = await Promise.all([api("/api/sets"), api("/api/health")]);
    sets.value = setsData;
    cardCount.value = health.cards;
  } catch { /* la page reste lisible sans les chiffres */ }
});
</script>

<template>
  <section class="hero-splash"
           style="--splash: url('https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png?auto=format&w=1920')">
    <div class="wrap hero-grid">
      <div>
        <p class="eyebrow">Compagnon Riftbound</p>
        <h1>La Faille,<br />dans votre poche.</h1>
        <p class="lead" style="margin-top:20px">
          Parcourez les 1 315 cartes du jeu, suivez votre collection,
          montez des decks valides en tournoi et partagez-les.
          Gratuit, sans pub, fait par des joueurs.
        </p>
        <div style="display:flex; gap:16px; margin-top:34px; flex-wrap:wrap">
          <RouterLink class="btn btn-gold" to="/cartes">Explorer les cartes</RouterLink>
          <RouterLink class="btn" to="/decks">Monter un deck</RouterLink>
        </div>
      </div>
      <div class="hero-fan" aria-hidden="true">
        <img v-for="card in FAN" :key="card.hash" v-tilt class="fan-card"
             :src="cardImg(card.hash)" :alt="''" :style="card.style" loading="eager" />
      </div>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>

  <section style="padding-top:56px">
    <div class="wrap">
      <div class="stat-row" v-if="cardCount !== null">
        <div class="stat" v-reveal>Cartes<b>{{ cardCount }}</b></div>
        <div class="stat" v-for="(s, i) in sets" :key="s.set_id" v-reveal="i + 1">{{ s.name }}<b>{{ s.card_count }}</b></div>
      </div>
    </div>
  </section>

  <section>
    <div class="wrap cols-2">
      <div class="panel" v-reveal>
        <p class="eyebrow">Les données</p>
        <h3 style="margin-bottom:10px">D'où viennent les cartes ?</h3>
        <p class="muted" style="font-size:.95rem">
          De l'API communautaire Riftcodex, synchronisée chaque jour.
          Les images viennent directement du CDN de Riot, rien n'est copié.
          Les textes sont en anglais tant que Riot n'a pas ouvert son API :
          la demande est en cours.
        </p>
      </div>
      <div class="panel" v-reveal="1">
        <p class="eyebrow">La suite</p>
        <h3 style="margin-bottom:10px">Ce qui arrive</h3>
        <p class="muted" style="font-size:.95rem">
          Scanner ses cartes avec la caméra du téléphone, connaître la valeur
          de sa collection via Cardmarket, et un vrai fil communautaire pour
          poster ses pulls et ses résultats de tournoi.
        </p>
      </div>
    </div>
  </section>
</template>
