<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session, setSession } from "./api.js"
import Logo from "./components/Logo.vue"
import UserAvatar from "./components/UserAvatar.vue"
import TraceursNotice from "./components/TraceursNotice.vue"
import { LEGAL_NAV, RIOT_DISCLAIMER_EN, RIOT_DISCLAIMER_FR, CONTACT_EMAIL, CONTACT_MAILTO } from "./legal.js"

const router = useRouter()
const route = useRoute()
const menuOpen = ref(false)

watch(
  () => route.fullPath,
  () => {
    menuOpen.value = false
  }
)

/* Session expirée (401 renvoyé par l'API) : direction la connexion, en gardant la page en cours. */
function onSessionExpired() {
  if (route.path === "/connexion") return
  router.push({ path: "/connexion", query: { suite: route.fullPath } })
}

onMounted(async () => {
  window.addEventListener("riftarium:session-expired", onSessionExpired)
  if (!session.token) return
  try {
    const me = await api("/api/auth/me")
    setSession("1", me.handle, me.avatar_url)
  } catch {
    /* 401 déjà géré par api() */
  }
})

onBeforeUnmount(() => {
  window.removeEventListener("riftarium:session-expired", onSessionExpired)
})

async function logout() {
  try {
    await api("/api/auth/logout", { method: "POST" })
  } catch {
    /* on ferme la session locale même si le cookie a déjà expiré */
  }
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
          <RouterLink class="nav-profile" to="/profil" :title="`Profil de ${session.handle}`">
            <UserAvatar :src="session.avatarUrl" :handle="session.handle" :size="28" />
            <span>{{ session.handle }}</span>
          </RouterLink>
          <button class="btn btn-ghost btn-sm" @click="logout">Déconnexion</button>
        </template>
        <RouterLink v-else class="btn btn-gold btn-sm" to="/connexion">Connexion</RouterLink>
      </nav>
      <span class="beta-mark">bêta</span>
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
    <div class="footer-in">
      <div class="footer-grid">
        <div>
          <div class="footer-brand"><Logo /><b>Riftarium</b></div>
          <p>
            Un site fan-made pour tout retrouver sur Riftbound : les cartes, les règles officielles, sa collection et
            ses decks. Développé par un joueur, sur son temps libre. Gratuit, au code source accessible.
          </p>
          <p class="footer-contact">
            Contact :
            <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a>
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
            <li v-if="session.token"><RouterLink to="/profil">Mon profil</RouterLink></li>
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
            <li>
              <a href="https://playriftbound.com/fr-fr/" target="_blank" rel="noopener">Site officiel Riftbound</a>
            </li>
          </ul>
        </div>
        <div>
          <h4>Légal</h4>
          <ul>
            <li v-for="item in LEGAL_NAV" :key="item.key">
              <RouterLink :to="item.path">{{ item.label }}</RouterLink>
            </li>
          </ul>
        </div>
      </div>
      <p>{{ RIOT_DISCLAIMER_EN }}</p>
      <p>{{ RIOT_DISCLAIMER_FR }}</p>
      <p>
        Riftbound, League of Legends, les visuels de cartes, illustrations et textes officiels sont la propriété de ©
        Riot Games, Inc. Les visuels sont servis depuis le CDN officiel de Riot, jamais copiés ni redistribués. En bêta,
        les textes de cartes proviennent de l'API communautaire Riftcodex en attendant l'API officielle Riot. Chaque
        carte mentionne son code collector et son illustrateur.
      </p>
    </div>
  </footer>
  <TraceursNotice />
</template>
