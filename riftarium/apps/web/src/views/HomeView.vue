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
  { icon: "cards", chip: "var(--mind)", title: "Cartothèque", text: "Retrouvez une carte, relisez-la, gardez-la sous la main — sans tout étaler sur la table.", to: "/cartes", go: "Parcourir" },
  { icon: "book", chip: "var(--order)", title: "Règles", text: "Un doute en pleine partie ? Les règles sont là, comme si vous posiez la question à quelqu'un.", to: "/regles", go: "Consulter" },
  { icon: "layers", chip: "var(--fury)", title: "Deck builder", text: "Montez un deck à l'écran. Le site vous dit s'il tient pour un tournoi, ou laissez-vous faire.", to: "/decks", go: "Construire" },
  { icon: "box", chip: "var(--body)", title: "Collection", text: "Notez ce que vous avez vraiment. Plus besoin de tout recompter à chaque booster.", to: "/collection", go: "Inventorier" },
  { icon: "users", chip: "var(--chaos)", title: "Communauté", text: "Regardez ce que les autres jouent, inspirez-vous, donnez un coup de pouce.", to: "/communaute", go: "Découvrir" },
  { icon: "code", chip: "var(--calm)", title: "Fait par un joueur", text: "Un projet libre, sans pub ni boutique. Si quelque chose manque, dites-le.", href: "https://github.com/Arcneell/riftarium", go: "Voir sur GitHub" }
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
        <p class="eyebrow">Un compagnon pour Riftbound</p>
        <h1>Pour jouer,<br />pas pour s'éparpiller.</h1>
        <p class="lead" style="margin-top:20px">
          Riftarium rassemble ce dont on a besoin autour de la table :
          connaître ses cartes, suivre sa collection, construire un deck
          et retrouver une règle entre deux tours.
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
      <p class="eyebrow" v-reveal>Les cartes</p>
      <h2 v-reveal>Feuilletez le jeu, comme sur la table</h2>
    </div>
    <CardRiver />
    <div class="wrap" style="text-align:center; margin-top:36px" v-reveal>
      <RouterLink class="btn btn-gold" to="/cartes">Explorer la cartothèque</RouterLink>
    </div>
  </section>

  <section>
    <div class="wrap">
      <p class="eyebrow" v-reveal>Autour de la table</p>
      <h2 v-reveal style="margin-bottom:36px">Ce que le site vous propose</h2>
      <div class="modules">
        <component :is="module.to ? 'RouterLink' : 'a'"
                   v-for="(module, i) in MODULES" :key="module.title"
                   class="module" v-reveal="i % 3"
                   :to="module.to" :href="module.href"
                   :target="module.href ? '_blank' : undefined"
                   :style="{ '--chip': module.chip }">
          <span class="m-icon"><Icon :name="module.icon" :size="24" /></span>
          <h3>{{ module.title }}</h3>
          <p>{{ module.text }}</p>
          <span class="m-go">{{ module.go }} <Icon name="arrow" :size="14" /></span>
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
        <p class="eyebrow">Pendant la partie</p>
        <h2>Une règle, tout de suite</h2>
        <p class="lead" style="margin-bottom:18px">
          Plus besoin de chercher dans un document. Dites ce qui vous bloque —
          un effet, une interaction, un doute — et la réponse est là,
          avec ce qui l'entoure.
        </p>
        <p class="muted" style="margin-bottom:26px">
          Ça tient dans une pause entre deux tours, sur téléphone comme sur ordinateur.
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
        <h3 style="margin-bottom:10px">Pour jouer, simplement</h3>
        <p class="muted" style="font-size:.95rem">
          Riftarium n'est pas un magasin et n'appartient pas à Riot.
          C'est un compagnon gratuit, fait pour s'y retrouver autour du jeu.
        </p>
      </div>
      <div class="panel" v-reveal="1">
        <h3 style="margin-bottom:10px">Un projet de joueur</h3>
        <p class="muted" style="font-size:.95rem">
          Le site est développé sur du temps libre, et le code est ouvert.
          Si une idée vous vient, ou si quelque chose cloche, elle a sa place
          sur <a href="https://github.com/Arcneell/riftarium" target="_blank" rel="noopener">GitHub</a>.
        </p>
      </div>
    </div>
  </section>
</template>
