<script setup>
import { onMounted, ref } from "vue";
import { api } from "../api.js";
import CardRiver from "../components/CardRiver.vue";

const cardCount = ref(null);
const setCount = ref(null);

const FAN = [
  { hash: "a7fe105f40df66525be51bd18e25506945a7b027-744x1039.png", style: "left:2%; top:60px; rotate:-9deg; z-index:1" },
  { hash: "cfa28e1abcac1db780d11e82985e13ee5978290d-744x1039.png", style: "left:30%; top:18px; rotate:1deg; z-index:2" },
  { hash: "7b71cf13a07074a6eccbe88ae6c74133d989cb68-744x1039.png", style: "left:58%; top:52px; rotate:9deg; z-index:1" }
];
const cardImg = hash => `https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/${hash}?auto=format&fit=max&w=460&accountingTag=RB`;

const MODULES = [
  { icon: "🃏", chip: "var(--mind)", title: "Cartothèque", text: "Toutes les cartes du jeu, avec filtres par domaine, type, rareté et set.", to: "/cartes", go: "Parcourir" },
  { icon: "📖", chip: "var(--order)", title: "Règles", text: "Le texte officiel complet, avec sommaire, recherche et renvois cliquables.", to: "/regles", go: "Consulter" },
  { icon: "🛠️", chip: "var(--fury)", title: "Deck builder", text: "Construction en visuel, validation des règles de tournoi en direct.", to: "/decks", go: "Construire" },
  { icon: "📦", chip: "var(--body)", title: "Collection", text: "Vos exemplaires, leur état et leur langue, carte par carte.", to: "/collection", go: "Inventorier" },
  { icon: "💬", chip: "var(--chaos)", title: "Communauté", text: "Les decks publiés par les autres joueurs, à copier ou à voter.", to: "/communaute", go: "Découvrir" },
  { icon: "⚙️", chip: "var(--calm)", title: "Code source", text: "Le site est open source. Idées et rapports de bug bienvenus.", href: "https://github.com/Arcneell/riftarium", go: "Voir sur GitHub" }
];

onMounted(async () => {
  try {
    const [sets, health] = await Promise.all([api("/api/sets"), api("/api/health")]);
    setCount.value = sets.length;
    cardCount.value = health.cards;
  } catch { /* les chiffres arriveront au prochain chargement */ }
});
</script>

<template>
  <section class="hero-splash"
           style="--splash: url('https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png?auto=format&w=1920')">
    <div class="wrap hero-grid">
      <div>
        <p class="eyebrow">Compagnon Riftbound non officiel</p>
        <h1>Tout Riftbound,<br />au même endroit.</h1>
        <p class="lead" style="margin-top:20px">
          Les cartes, les règles officielles, votre collection et vos decks.
          Un seul site, sur PC comme sur téléphone.
        </p>
        <div style="display:flex; gap:16px; margin-top:34px; flex-wrap:wrap">
          <RouterLink class="btn btn-gold" to="/cartes">Voir les cartes</RouterLink>
          <RouterLink class="btn" to="/regles">Lire les règles</RouterLink>
        </div>
      </div>
      <div class="hero-fan" aria-hidden="true">
        <img v-for="card in FAN" :key="card.hash" v-tilt class="fan-card"
             :src="cardImg(card.hash)" alt="" :style="card.style" loading="eager" />
      </div>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>

  <div class="wrap" v-reveal>
    <div class="figures">
      <div class="figure"><b>{{ cardCount ?? "—" }}</b><span>cartes</span></div>
      <div class="figure"><b>{{ setCount ?? "—" }}</b><span>sets</span></div>
      <div class="figure"><b>2 137</b><span>règles du jeu</span></div>
      <div class="figure"><b>812</b><span>règles de tournoi</span></div>
    </div>
  </div>

  <section style="padding-bottom:40px">
    <div class="wrap" style="margin-bottom:36px">
      <p class="eyebrow" v-reveal>La cartothèque</p>
      <h2 v-reveal>1 315 cartes, six sets, un moteur de recherche</h2>
    </div>
    <CardRiver />
    <div class="wrap" style="text-align:center; margin-top:36px" v-reveal>
      <RouterLink class="btn btn-gold" to="/cartes">Explorer la cartothèque</RouterLink>
    </div>
  </section>

  <section>
    <div class="wrap">
      <p class="eyebrow" v-reveal>Le site en six briques</p>
      <h2 v-reveal style="margin-bottom:36px">Ce que vous trouverez ici</h2>
      <div class="modules">
        <component :is="module.to ? 'RouterLink' : 'a'"
                   v-for="(module, i) in MODULES" :key="module.title"
                   class="module" v-reveal="i % 3"
                   :to="module.to" :href="module.href"
                   :target="module.href ? '_blank' : undefined"
                   :style="{ '--chip': module.chip }">
          <span class="m-icon">{{ module.icon }}</span>
          <h3>{{ module.title }}</h3>
          <p>{{ module.text }}</p>
          <span class="m-go">{{ module.go }} →</span>
        </component>
      </div>
    </div>
  </section>

  <div class="interlude" role="img" aria-label="Illustration officielle Riftbound"
       style="--art: url('https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/91a720561b6cd9c649a9148782f34d96e78cd894-4320x2430.jpg?auto=format&w=1800')">
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </div>

  <section>
    <div class="wrap cols-2">
      <div v-reveal>
        <p class="eyebrow">À l'origine du projet</p>
        <h2>Les règles, sans PDF</h2>
        <p class="lead" style="margin-bottom:18px">
          Riftarium a d'abord été un lecteur de règles. Le texte officiel y est
          découpé règle par règle, avec un sommaire, une recherche qui ignore
          les accents et des renvois cliquables entre les règles.
        </p>
        <p class="muted" style="margin-bottom:26px">
          Pratique en pleine partie : tapez un mot-clé ou un numéro,
          la règle s'affiche avec son contexte.
        </p>
        <RouterLink class="btn btn-gold" to="/regles">Ouvrir les règles</RouterLink>
      </div>
      <div class="panel" v-reveal="1">
        <p class="eyebrow">Règle 002 — la Règle d'or</p>
        <p style="font-family:var(--font-display); font-size:1.25rem; line-height:1.5; color:var(--ink-strong)">
          « Ce qui est inscrit sur une carte a priorité sur ce qui est inscrit
          dans les règles du jeu. »
        </p>
        <p class="muted mono" style="font-size:.74rem; margin-top:14px">Règles du jeu Riftbound · © Riot Games</p>
      </div>
    </div>
  </section>

  <section style="padding-top:32px; padding-bottom:104px">
    <div class="wrap cols-2">
      <div class="panel" v-reveal>
        <h3 style="margin-bottom:10px">Les données</h3>
        <p class="muted" style="font-size:.95rem">
          Les cartes viennent de l'API communautaire Riftcodex et les images du
          CDN de Riot. Les textes de cartes sont en anglais pour l'instant ;
          une demande d'accès à l'API officielle est en cours pour le français.
        </p>
      </div>
      <div class="panel" v-reveal="1">
        <h3 style="margin-bottom:10px">Développé par un joueur</h3>
        <p class="muted" style="font-size:.95rem">
          Riftarium est un projet personnel, développé seul et hébergé sans
          contrepartie. Le code est sur
          <a href="https://github.com/Arcneell/riftarium" target="_blank" rel="noopener">GitHub</a> —
          les idées et les rapports de bug sont bienvenus.
        </p>
      </div>
    </div>
  </section>
</template>
