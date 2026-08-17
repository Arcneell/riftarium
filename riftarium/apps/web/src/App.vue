<script setup>
import { useRouter } from "vue-router";
import { session, setSession } from "./api.js";

const router = useRouter();

function logout() {
  setSession(null, null);
  router.push("/");
}
</script>

<template>
  <header class="top">
    <div class="top-in">
      <RouterLink class="brand" to="/"><span class="brand-mark"></span>RIFT<em>ARIUM</em></RouterLink>
      <nav class="nav" aria-label="Navigation principale">
        <RouterLink to="/cartes">Cartes</RouterLink>
        <RouterLink to="/collection">Collection</RouterLink>
        <RouterLink to="/decks">Decks</RouterLink>
        <RouterLink to="/communaute">Communauté</RouterLink>
        <template v-if="session.token">
          <span class="chip" style="--chip:var(--calm)">{{ session.handle }}</span>
          <button class="btn btn-ghost btn-sm" @click="logout">Déconnexion</button>
        </template>
        <RouterLink v-else class="btn btn-gold btn-sm" to="/connexion">Connexion</RouterLink>
      </nav>
    </div>
  </header>
  <div class="prism"></div>

  <main>
    <RouterView />
  </main>

  <footer>
    <div class="wrap">
      <p class="legal-title">Mentions légales</p>
      <p><strong>Riftarium</strong> est un projet fan-made, communautaire et à but non lucratif. Il n'est ni affilié à, ni soutenu, ni sponsorisé par Riot Games.</p>
      <p>Riftarium a été créé en vertu de la politique juridique de Riot Games intitulée « Jargon juridique » relative à l'utilisation d'actifs de Riot Games. Riot Games ne soutient ni ne sponsorise ce projet.</p>
      <p>Riftbound, League of Legends ainsi que les visuels de cartes, illustrations, symboles et textes officiels affichés sont la propriété de © Riot Games, Inc. Les visuels sont servis depuis le CDN officiel de Riot et ne sont pas redistribués par ce site. Chaque carte mentionne son code collector et son illustrateur.</p>
      <p>Données de cartes fournies par l'API communautaire <a href="https://api.riftcodex.com/docs" target="_blank" rel="noopener">Riftcodex</a>. Textes de cartes disponibles en anglais uniquement pour le moment.</p>
      <p>Illustrations d'arrière-plan (visuels officiels Riftbound) © Riot Games, Inc. — servies depuis le CDN officiel Riot (cmsassets.rgpub.io) et créditées sur chaque page.</p>
    </div>
  </footer>
</template>
