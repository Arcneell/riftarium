<script setup>
import { onMounted, ref } from "vue";
import { api } from "../api.js";

const sets = ref([]);
const cardCount = ref(null);

const FAN = [
  { hash: "a7fe105f40df66525be51bd18e25506945a7b027-744x1039.png", style: "left:2%; top:60px; rotate:-9deg; z-index:1" },
  { hash: "cfa28e1abcac1db780d11e82985e13ee5978290d-744x1039.png", style: "left:30%; top:18px; rotate:1deg; z-index:2" },
  { hash: "7b71cf13a07074a6eccbe88ae6c74133d989cb68-744x1039.png", style: "left:58%; top:52px; rotate:9deg; z-index:1" }
];
const cardImg = hash => `https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live/${hash}?auto=format&fit=max&w=460&accountingTag=RB`;

const MODULES = [
  { icon: "🃏", chip: "var(--mind)", title: "Cartothèque", text: "Les 1 315 cartes des six sets, avec recherche et filtres par domaine, type ou rareté.", to: "/cartes", go: "Parcourir les cartes" },
  { icon: "📖", chip: "var(--order)", title: "Règles officielles", text: "Le texte intégral des règles du jeu et des règles de tournoi, avec sommaire, recherche et renvois cliquables.", href: "/regles/regles.html", go: "Lire les règles" },
  { icon: "🎓", chip: "var(--calm)", title: "Guide du débutant", text: "Les règles reformulées simplement pour apprendre à jouer, chapitre par chapitre.", href: "/regles/debuter.html", go: "Apprendre à jouer" },
  { icon: "📦", chip: "var(--body)", title: "Collection", text: "Notez ce que vous possédez, en quel état et en quelle langue. L'estimation des prix arrive.", to: "/collection", go: "Gérer ma collection" },
  { icon: "🛠️", chip: "var(--fury)", title: "Deck builder", text: "Montez vos decks visuellement, avec la validation des règles de tournoi en direct.", to: "/decks", go: "Monter un deck" },
  { icon: "💬", chip: "var(--chaos)", title: "Communauté", text: "Publiez vos decks, copiez ceux des autres, votez pour vos préférés.", to: "/communaute", go: "Voir les decks publics" }
];

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
        <p class="eyebrow">Tout Riftbound, au même endroit</p>
        <h1>La Faille,<br />dans votre poche.</h1>
        <p class="lead" style="margin-top:20px">
          Les cartes, les règles officielles, votre collection, vos decks :
          Riftarium rassemble tout ce qu'il faut pour jouer à Riftbound,
          que vous découvriez le jeu ou que vous prépariez un tournoi.
        </p>
        <div style="display:flex; gap:16px; margin-top:34px; flex-wrap:wrap">
          <RouterLink class="btn btn-gold" to="/cartes">Explorer les cartes</RouterLink>
          <a class="btn" href="/regles/regles.html">Lire les règles</a>
        </div>
      </div>
      <div class="hero-fan" aria-hidden="true">
        <img v-for="card in FAN" :key="card.hash" v-tilt class="fan-card"
             :src="cardImg(card.hash)" alt="" :style="card.style" loading="eager" />
      </div>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </section>

  <section style="padding-top:48px; padding-bottom:48px">
    <div class="wrap">
      <div class="stat-row">
        <div class="stat" v-reveal>Cartes référencées<b>{{ cardCount ?? "…" }}</b></div>
        <div class="stat" v-reveal="1">Règles du jeu<b>2 137</b></div>
        <div class="stat" v-reveal="2">Règles de tournoi<b>812</b></div>
        <div class="stat" v-for="(s, i) in sets.slice(0, 4)" :key="s.set_id" v-reveal="i + 3">{{ s.name }}<b>{{ s.card_count }}</b></div>
      </div>
    </div>
  </section>

  <section style="padding-top:24px">
    <div class="wrap">
      <p class="eyebrow" v-reveal>Six outils, un seul site</p>
      <h2 v-reveal>Qu'est-ce qu'on trouve ici ?</h2>
      <p class="lead" v-reveal style="margin-bottom:40px">
        Riftarium est né d'un constat simple : pour jouer à Riftbound, il fallait
        jongler entre plusieurs sites. Plus maintenant.
      </p>
      <div class="modules">
        <component :is="module.to ? 'RouterLink' : 'a'"
                   v-for="(module, i) in MODULES" :key="module.title"
                   class="module" v-reveal="i % 3"
                   :to="module.to" :href="module.href"
                   :style="{ '--chip': module.chip }">
          <span class="m-icon">{{ module.icon }}</span>
          <h3>{{ module.title }}</h3>
          <p>{{ module.text }}</p>
          <span class="m-go">{{ module.go }} →</span>
        </component>
      </div>
    </div>
  </section>

  <section>
    <div class="wrap cols-2">
      <div v-reveal>
        <p class="eyebrow">Les règles, d'abord</p>
        <h2>Le texte officiel, enfin lisible</h2>
        <p class="lead" style="margin-bottom:18px">
          Ce site a commencé par là : rendre les 2 137 règles du jeu consultables
          sans ouvrir un PDF. Chaque règle a son lien, chaque renvoi est cliquable,
          et la recherche ignore les accents.
        </p>
        <p class="muted" style="margin-bottom:26px">
          Un doute pendant une partie ? Cherchez « réaction » ou tapez le numéro
          de la règle, vous y êtes en trois secondes. Et si vous débutez, le guide
          reprend tout depuis le début, sans jargon.
        </p>
        <div style="display:flex; gap:14px; flex-wrap:wrap">
          <a class="btn btn-gold" href="/regles/regles.html">Règles complètes</a>
          <a class="btn" href="/regles/debuter.html">Guide du débutant</a>
        </div>
      </div>
      <div class="panel" v-reveal="1">
        <p class="eyebrow">Extrait — Règle d'or</p>
        <p style="font-family:var(--font-display); font-size:1.25rem; line-height:1.5; color:var(--ink-strong)">
          « Ce qui est inscrit sur une carte a priorité sur ce qui est inscrit dans
          les règles du jeu. »
        </p>
        <p class="muted mono" style="font-size:.74rem; margin-top:14px">Règle 002 · Règles du jeu Riftbound · © Riot Games</p>
      </div>
    </div>
  </section>

  <section>
    <div class="wrap cols-2">
      <div class="panel" v-reveal>
        <p class="eyebrow">Les données</p>
        <h3 style="margin-bottom:10px">D'où viennent les cartes ?</h3>
        <p class="muted" style="font-size:.95rem">
          De l'API communautaire Riftcodex, synchronisée en base locale. Les images
          viennent directement du CDN de Riot, rien n'est copié. Les textes de cartes
          sont en anglais tant que Riot n'a pas ouvert son API : la demande est en cours.
        </p>
      </div>
      <div class="panel" v-reveal="1">
        <p class="eyebrow">La suite</p>
        <h3 style="margin-bottom:10px">Ce qui arrive</h3>
        <p class="muted" style="font-size:.95rem">
          Scanner ses cartes avec la caméra du téléphone, connaître la valeur de sa
          collection via Cardmarket, les textes officiels en français, et un vrai fil
          communautaire pour poster ses pulls et ses résultats de tournoi.
        </p>
      </div>
    </div>
  </section>

  <section style="padding-bottom:104px">
    <div class="wrap">
      <div class="panel" v-reveal style="text-align:center; padding:48px 34px">
        <p class="eyebrow" style="justify-content:center">Open source</p>
        <h2>Un joueur au clavier, tout le code sur GitHub</h2>
        <p class="lead" style="margin:0 auto 28px">
          Riftarium est développé par une seule personne, en dehors des heures de boulot.
          Le code est public : une idée, un bug, une envie de contribuer ? C'est par ici.
        </p>
        <div style="display:flex; gap:14px; justify-content:center; flex-wrap:wrap">
          <a class="btn btn-gold" href="https://github.com/Arcneell/riftarium" target="_blank" rel="noopener">Voir le code sur GitHub</a>
          <a class="btn" href="https://github.com/Arcneell/riftarium/issues" target="_blank" rel="noopener">Proposer une idée</a>
        </div>
      </div>
    </div>
  </section>
</template>
