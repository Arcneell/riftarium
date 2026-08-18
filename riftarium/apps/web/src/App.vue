<script setup>
import { ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { session, setSession } from "./api.js"
import Logo from "./components/Logo.vue"

const router = useRouter()
const route = useRoute()
const menuOpen = ref(false)

watch(
  () => route.fullPath,
  () => {
    menuOpen.value = false
  }
)

function logout() {
  setSession(null, null)
  router.push("/")
}
</script>

<template>
  <header class="top">
    <div class="top-in">
      <RouterLink class="brand" to="/" aria-label="Riftarium — accueil">
        <Logo />
        <span class="brand-name">Riftarium</span>
      </RouterLink>
      <button class="burger" @click="menuOpen = !menuOpen" :aria-expanded="menuOpen" aria-label="Menu">
        <Icon name="menu" :size="20" />
      </button>
      <nav class="nav" :class="{ open: menuOpen }" aria-label="Navigation principale">
        <RouterLink to="/cartes">Cartes</RouterLink>
        <RouterLink to="/regles">Règles</RouterLink>
        <RouterLink to="/collection">Collection</RouterLink>
        <RouterLink to="/decks">Decks</RouterLink>
        <RouterLink to="/communaute">Communauté</RouterLink>
        <template v-if="session.token">
          <span class="chip" style="--chip: var(--calm)">{{ session.handle }}</span>
          <button class="btn btn-ghost btn-sm" @click="logout">Déconnexion</button>
        </template>
        <RouterLink v-else class="btn btn-gold btn-sm" to="/connexion">Connexion</RouterLink>
      </nav>
    </div>
  </header>
  <div class="prism"></div>

  <main>
    <RouterView v-slot="{ Component, route: viewRoute }">
      <Transition name="page" mode="out-in">
        <div class="page" :key="viewRoute.path">
          <component :is="Component" />
        </div>
      </Transition>
    </RouterView>
  </main>

  <footer>
    <div class="footer-grid">
      <div>
        <div class="footer-brand"><Logo /><b>Riftarium</b></div>
        <p>
          Un site fan-made pour tout retrouver sur Riftbound : les cartes, les règles officielles, sa collection et ses
          decks. Développé par un joueur, sur son temps libre. Gratuit et open source.
        </p>
      </div>
      <div>
        <h4>Explorer</h4>
        <ul>
          <li><RouterLink to="/cartes">Cartothèque</RouterLink></li>
          <li><RouterLink to="/regles/debutant">Apprendre à jouer</RouterLink></li>
          <li><RouterLink to="/regles">Règles</RouterLink></li>
          <li><RouterLink to="/decks">Deck builder</RouterLink></li>
          <li><RouterLink to="/communaute">Decks de la communauté</RouterLink></li>
        </ul>
      </div>
      <div>
        <h4>Le projet</h4>
        <ul>
          <li>
            <a href="https://github.com/Arcneell/riftarium" target="_blank" rel="noopener">Code source (GitHub)</a>
          </li>
          <li>
            <a href="https://github.com/Arcneell/riftarium/issues" target="_blank" rel="noopener">Signaler un bug</a>
          </li>
          <li><a href="https://api.riftcodex.com/docs" target="_blank" rel="noopener">Données : API Riftcodex</a></li>
          <li><a href="https://playriftbound.com/fr-fr/" target="_blank" rel="noopener">Site officiel Riftbound</a></li>
        </ul>
      </div>
    </div>
    <div class="footer-legal">
      <div class="wrap">
        <p>
          <strong>Riftarium</strong> est un projet fan-made à but non lucratif, ni affilié à, ni soutenu, ni sponsorisé
          par Riot Games. Créé en vertu de la politique juridique de Riot Games intitulée « Jargon juridique » relative
          à l'utilisation d'actifs de Riot Games.
        </p>
        <p>
          Riftbound, League of Legends, les visuels de cartes, illustrations et textes officiels sont la propriété de ©
          Riot Games, Inc. Les visuels sont servis depuis le CDN officiel de Riot, jamais copiés ni redistribués. Chaque
          carte mentionne son code collector et son illustrateur. Visuels d'arrière-plan officiels crédités sur chaque
          page.
        </p>
      </div>
    </div>
  </footer>
</template>
