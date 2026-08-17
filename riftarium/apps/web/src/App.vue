<script setup>
import { ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { session, setSession } from "./api.js";
import Logo from "./components/Logo.vue";

const router = useRouter();
const route = useRoute();
const menuOpen = ref(false);

watch(() => route.fullPath, () => { menuOpen.value = false; });

function logout() {
  setSession(null, null);
  router.push("/");
}
</script>

<template>
  <header class="top">
    <div class="top-in">
      <RouterLink class="brand" to="/" aria-label="Riftarium — accueil">
        <Logo />
        <span class="brand-name">Riftarium</span>
      </RouterLink>
      <button class="burger" @click="menuOpen = !menuOpen"
              :aria-expanded="menuOpen" aria-label="Menu">☰</button>
      <nav class="nav" :class="{ open: menuOpen }" aria-label="Navigation principale">
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
    <RouterView v-slot="{ Component }">
      <Transition name="page" mode="out-in">
        <component :is="Component" />
      </Transition>
    </RouterView>
  </main>

  <footer>
    <div class="wrap">
      <p class="legal-title">Mentions légales</p>
      <p><strong>Riftarium</strong> est un projet fan-made, communautaire et à but non lucratif. Il n'est ni affilié à, ni soutenu, ni sponsorisé par Riot Games.</p>
      <p>Riftarium a été créé en vertu de la politique juridique de Riot Games intitulée « Jargon juridique » relative à l'utilisation d'actifs de Riot Games. Riot Games ne soutient ni ne sponsorise ce projet.</p>
      <p>Riftbound, League of Legends, les visuels de cartes, illustrations et textes officiels sont la propriété de © Riot Games, Inc. Les visuels sont servis depuis le CDN officiel de Riot, jamais copiés ni redistribués. Chaque carte mentionne son code collector et son illustrateur.</p>
      <p>Données de cartes : API communautaire <a href="https://api.riftcodex.com/docs" target="_blank" rel="noopener">Riftcodex</a>. Textes de cartes en anglais pour le moment. Visuels d'arrière-plan officiels Riftbound © Riot Games, crédités sur chaque page.</p>
    </div>
  </footer>
</template>
