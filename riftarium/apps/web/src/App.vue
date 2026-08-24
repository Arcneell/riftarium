<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session, setSession } from "./api.js"
import Logo from "./components/Logo.vue"
import UserAvatar from "./components/UserAvatar.vue"
import TraceursNotice from "./components/TraceursNotice.vue"
import EmailVerifyNotice from "./components/EmailVerifyNotice.vue"
import {
  LEGAL_NAV,
  CLOSED_BETA,
  SHOW_DONATIONS,
  RIOT_DISCLAIMER_EN,
  RIOT_GENERAL_DISCLAIMER_EN,
  CONTACT_EMAIL,
  CONTACT_MAILTO
} from "./legal.js"

const router = useRouter()
const route = useRoute()
const menuOpen = ref(false)

/* Le tiroir et son voile sont en position: fixed, mais l'en-tête porte un
   backdrop-filter : il devient bloc conteneur et les bornerait à la hauteur de la
   barre (panneau coupé au bout de quelques dizaines de pixels). Sous 980 px, on
   les sort donc dans <body> ; au-dessus, la barre reprend sa place dans l'en-tête. */
const drawerQuery = typeof window !== "undefined" ? window.matchMedia("(max-width: 980px)") : null
const drawerMode = ref(drawerQuery?.matches ?? false)

function onDrawerQuery(event) {
  drawerMode.value = event.matches
  if (!event.matches) menuOpen.value = false
}

watch(
  () => route.fullPath,
  () => {
    menuOpen.value = false
  }
)

/* Tiroir latéral : tant qu'il est ouvert, la page derrière ne défile plus
   (sinon le scroll « traverse » le panneau sur iOS et Android). */
watch(menuOpen, (open) => {
  document.body.classList.toggle("nav-locked", open)
})

function onKeydown(event) {
  if (event.key === "Escape") menuOpen.value = false
}

/* Session expirée (401 renvoyé par l'API) : direction la connexion, en gardant la page en cours. */
function onSessionExpired() {
  if (route.path === "/connexion") return
  router.push({ path: "/connexion", query: { suite: route.fullPath } })
}

onMounted(async () => {
  window.addEventListener("riftarium:session-expired", onSessionExpired)
  window.addEventListener("keydown", onKeydown)
  drawerQuery?.addEventListener("change", onDrawerQuery)
  if (!session.token) return
  try {
    const me = await api("/api/auth/me")
    setSession("1", me.handle, me.avatar_url)
    session.emailVerified = me.email_verified ?? null
    session.isAdmin = me.is_admin ?? false
  } catch {
    /* 401 déjà géré par api() */
  }
})

onBeforeUnmount(() => {
  window.removeEventListener("riftarium:session-expired", onSessionExpired)
  window.removeEventListener("keydown", onKeydown)
  drawerQuery?.removeEventListener("change", onDrawerQuery)
  document.body.classList.remove("nav-locked")
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
      <button
        class="burger"
        type="button"
        @click="menuOpen = !menuOpen"
        :aria-expanded="menuOpen"
        aria-controls="nav-principale"
        aria-label="Menu"
      >
        <Icon name="menu" :size="20" />
      </button>
      <Teleport to="body" :disabled="!drawerMode">
        <Transition name="scrim">
          <div v-if="menuOpen" class="nav-scrim" @click="menuOpen = false"></div>
        </Transition>
        <nav id="nav-principale" class="nav" :class="{ open: menuOpen }" aria-label="Navigation principale">
          <button class="nav-close" type="button" @click="menuOpen = false" aria-label="Fermer le menu">
            <Icon name="x" :size="20" />
          </button>
          <RouterLink to="/cartes">Cartes</RouterLink>
          <RouterLink to="/regles">Règles</RouterLink>
          <RouterLink to="/collection">Collection</RouterLink>
          <RouterLink to="/decks">Decks</RouterLink>
          <RouterLink to="/communaute">Communauté</RouterLink>
          <template v-if="session.token">
            <RouterLink to="/wishlist">Wishlist</RouterLink>
            <RouterLink v-if="session.isAdmin" class="nav-admin" to="/admin">Administration</RouterLink>
            <RouterLink class="nav-profile" to="/profil" :title="`Profil de ${session.handle}`">
              <UserAvatar :src="session.avatarUrl" :handle="session.handle" :size="28" />
              <span>{{ session.handle }}</span>
            </RouterLink>
            <button class="btn btn-ghost btn-sm" @click="logout">Déconnexion</button>
          </template>
          <RouterLink v-else class="btn btn-gold btn-sm" to="/connexion">Connexion</RouterLink>
        </nav>
      </Teleport>
      <span class="beta-mark" :title="CLOSED_BETA ? 'Bêta fermée, non indexée, accès sur invitation' : 'Bêta'">{{
        CLOSED_BETA ? "bêta fermée" : "bêta"
      }}</span>
    </div>
  </header>
  <div class="prism"></div>
  <EmailVerifyNotice />

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
          <p v-if="CLOSED_BETA" class="footer-contact">
            Bêta fermée : le site n'est pas annoncé publiquement et n'est pas indexé. Accès sur invitation, pour tests
            et retours de bugs.
          </p>
          <p class="footer-contact">
            Contact :
            <a :href="CONTACT_MAILTO">{{ CONTACT_EMAIL }}</a>
          </p>
        </div>
        <div>
          <p class="foot-head">Explorer</p>
          <ul>
            <li><RouterLink to="/cartes">Cartothèque</RouterLink></li>
            <li><RouterLink to="/regles/debutant">Apprendre à jouer</RouterLink></li>
            <li><RouterLink to="/regles">Règles</RouterLink></li>
            <li><RouterLink to="/decks">Deck builder</RouterLink></li>
            <li><RouterLink to="/scan">Scanner une carte</RouterLink></li>
            <li><RouterLink to="/communaute">Decks de la communauté</RouterLink></li>
            <li v-if="session.token"><RouterLink to="/wishlist">Ma wishlist</RouterLink></li>
            <li v-if="session.token"><RouterLink to="/profil">Mon profil</RouterLink></li>
          </ul>
        </div>
        <div>
          <p class="foot-head">Le projet</p>
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
            <li v-if="SHOW_DONATIONS">
              <a href="https://ko-fi.com/arcneell" target="_blank" rel="noopener" class="footer-support"
                >☕ Soutenir le projet (Ko-fi)</a
              >
            </li>
          </ul>
        </div>
        <div>
          <p class="foot-head">Légal</p>
          <ul>
            <li v-for="item in LEGAL_NAV" :key="item.key">
              <RouterLink :to="item.path">{{ item.label }}</RouterLink>
            </li>
          </ul>
        </div>
      </div>
      <!-- Avertissements Riot dans leur version anglaise, la seule que la politique
           « Legal Jibber Jabber » impose de reproduire. La traduction française
           reste sur les pages légales, où elle a la place d'être lue. -->
      <div class="footer-legal">
        <p>{{ RIOT_GENERAL_DISCLAIMER_EN }}</p>
        <p>{{ RIOT_DISCLAIMER_EN }}</p>
        <p class="footer-legal-wide">
          Visuels et textes officiels © Riot Games, Inc., servis depuis le CDN de Riot. Détail sur les
          <RouterLink to="/mentions-legales">mentions légales</RouterLink>.
        </p>
      </div>
    </div>
  </footer>
  <TraceursNotice />
</template>
