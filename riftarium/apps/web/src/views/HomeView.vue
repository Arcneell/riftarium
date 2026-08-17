<script setup>
import { onMounted, ref } from "vue";
import { api } from "../api.js";

const sets = ref([]);
const cardCount = ref(null);

onMounted(async () => {
  try {
    const [setsData, health] = await Promise.all([api("/api/sets"), api("/api/health")]);
    sets.value = setsData;
    cardCount.value = health.cards;
  } catch { /* la page reste utilisable sans stats */ }
});
</script>

<template>
  <section class="hero-splash"
           style="--splash: url('https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png?auto=format&w=1920')">
    <div class="wrap">
      <p class="eyebrow">Compagnon communautaire Riftbound</p>
      <h1>Toutes vos cartes.<br />Tous vos decks.<br />Une seule communauté.</h1>
      <p class="lead" style="margin-top:16px">
        Cartothèque complète, collection personnelle, deck builder avec validation des règles
        officielles et decks partagés par la communauté — pour débutants comme pour experts.
      </p>
      <div style="display:flex; gap:14px; margin-top:28px; flex-wrap:wrap">
        <RouterLink class="btn btn-gold" to="/cartes">Explorer les cartes</RouterLink>
        <RouterLink class="btn btn-ghost" to="/decks">Construire un deck</RouterLink>
      </div>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>

  <div class="divider" role="presentation"><i></i></div>

  <section style="padding-top:34px">
    <div class="wrap">
      <div class="stat-row" v-if="cardCount !== null">
        <div class="stat">Cartes référencées<b>{{ cardCount }}</b></div>
        <div class="stat" v-for="s in sets" :key="s.set_id">{{ s.name }}<b>{{ s.card_count }}</b></div>
      </div>
    </div>
  </section>

  <section>
    <div class="wrap cols-2">
      <div class="panel">
        <p class="eyebrow">Données</p>
        <h3>Source communautaire, visuels officiels</h3>
        <p class="muted" style="font-size:.92rem; margin-top:8px">
          Les cartes proviennent de l'API communautaire Riftcodex et sont synchronisées en base locale.
          Les visuels restent servis par le CDN officiel de Riot. Textes en anglais pour le moment —
          le français arrivera avec l'API officielle Riot.
        </p>
      </div>
      <div class="panel">
        <p class="eyebrow">Feuille de route</p>
        <h3>Prochaines étapes</h3>
        <p class="muted" style="font-size:.92rem; margin-top:8px">
          Scan mobile de cartes (PWA + caméra), estimation Cardmarket, fil communautaire complet
          (pulls, tournois) et textes officiels FR via l'API Riot — voir REFONTE.md du dépôt.
        </p>
      </div>
    </div>
  </section>
</template>
