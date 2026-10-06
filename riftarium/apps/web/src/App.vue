<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, session, setSession } from "./api.js"
import EmailVerifyNotice from "./components/EmailVerifyNotice.vue"
import TraceursNotice from "./components/TraceursNotice.vue"
import { useBreakpoint } from "./composables/useBreakpoint.js"
import { useOnline } from "./composables/useOnline.js"
import AccountSheet from "./shell/AccountSheet.vue"
import AppFooter from "./shell/AppFooter.vue"
import AppRail from "./shell/AppRail.vue"
import AppTabbar from "./shell/AppTabbar.vue"
import AppTopbar from "./shell/AppTopbar.vue"
import { activeSection } from "./shell/navigation.js"
import { clearPageCrumb } from "./shell/pageCrumb.js"
import SearchPalette from "./shell/SearchPalette.vue"
import RiftTabs from "./ui/RiftTabs.vue"

const router = useRouter()
const route = useRoute()
const breakpoint = useBreakpoint()
const mobile = computed(() => breakpoint.value === "mobile")
const section = computed(() => activeSection(route.path))

/* Rail replié : choix mémorisé s'il existe, sinon replié sur tablette seulement.
   Stockage indisponible (navigation privée) : le choix vit le temps de la session. */
const RAIL_KEY = "riftarium_rail_collapsed"
function readRailPref() {
  try {
    const value = localStorage.getItem(RAIL_KEY)
    return value === null ? null : value === "1"
  } catch {
    return null
  }
}
const railPref = ref(readRailPref())
const railCollapsed = computed(() => railPref.value ?? breakpoint.value === "tablet")
function toggleRail() {
  railPref.value = !railCollapsed.value
  try {
    localStorage.setItem(RAIL_KEY, railPref.value ? "1" : "0")
  } catch {
    /* stockage bloqué : le choix n'est pas persisté */
  }
}

/* La barre d'onglets du bas est fixe : les éléments flottants ancrés en bas (certains sont
   téléportés hors de .shell) lisent --shell-bottom, posé sur le body par cette classe. */
watch(mobile, (value) => document.body.classList.toggle("has-tabbar", value), { immediate: true })

const searchOpen = ref(false)
const accountOpen = ref(false)

watch(
  () => route.fullPath,
  () => {
    searchOpen.value = false
    accountOpen.value = false
  }
)
watch(
  () => route.path,
  () => clearPageCrumb()
)
/* Feuille du compte réservée au téléphone : on la ferme en quittant ce palier. */
watch(mobile, (value) => {
  if (!value) accountOpen.value = false
})

function isEditable(element) {
  return Boolean(element && (element.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(element.tagName)))
}

/* Ctrl/⌘ K partout ; « / » seulement hors d'un champ (sinon on ne pourrait plus le taper). */
function onKeydown(event) {
  /* Une autre surcouche (zoom, modale, feuille) est active : seule la palette ouverte reste pilotable. */
  const otherOverlay = document.body.classList.contains("nav-locked") && !searchOpen.value
  if (otherOverlay) return
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    event.preventDefault()
    searchOpen.value = !searchOpen.value
    return
  }
  if (event.key === "/" && !searchOpen.value && !isEditable(event.target)) {
    event.preventDefault()
    searchOpen.value = true
  }
}

/* Page dont le code n'est pas en cache et qu'on ouvre sans réseau (router.onError) :
   le bandeau s'efface au retour du réseau ou à la navigation suivante. */
const online = useOnline()
const offlinePage = ref(false)
function onOfflinePage() {
  offlinePage.value = true
}
watch([online, () => route.path], () => {
  offlinePage.value = false
})

/* Session expirée (401 renvoyé par l'API) : direction la connexion, en gardant la page en cours. */
function onSessionExpired() {
  if (route.path === "/connexion") return
  router.push({ path: "/connexion", query: { suite: route.fullPath } })
}

onMounted(async () => {
  window.addEventListener("riftarium:session-expired", onSessionExpired)
  window.addEventListener("riftarium:offline-page", onOfflinePage)
  window.addEventListener("keydown", onKeydown)
  if (!session.token) return
  try {
    const me = await api("/api/auth/me")
    /* Déconnexion (ou 401) survenue pendant l'appel : ne pas ressusciter la session. */
    if (!session.token) return
    setSession("1", me.handle, me.avatar_url)
    session.emailVerified = me.email_verified ?? null
    session.isAdmin = me.is_admin ?? false
  } catch {
    /* 401 déjà géré par api() */
  }
})

onBeforeUnmount(() => {
  document.body.classList.remove("has-tabbar")
  window.removeEventListener("riftarium:session-expired", onSessionExpired)
  window.removeEventListener("riftarium:offline-page", onOfflinePage)
  window.removeEventListener("keydown", onKeydown)
})
</script>

<template>
  <a class="skip-link" href="#contenu">Aller au contenu</a>
  <div class="shell" :class="{ 'shell--mobile': mobile, 'shell--collapsed': !mobile && railCollapsed }">
    <AppRail v-if="!mobile" :collapsed="railCollapsed" @toggle="toggleRail" />
    <div class="shell-main">
      <AppTopbar :mobile="mobile" @search="searchOpen = true" @account="accountOpen = true" />
      <RiftTabs
        v-if="(mobile || railCollapsed) && section?.children"
        :items="section.children"
        :label="section.label"
      />
      <EmailVerifyNotice />
      <div v-if="offlinePage" class="verify-notice" role="status">
        <p>Hors ligne : cette page n'est pas disponible sans connexion. Les règles restent consultables.</p>
      </div>
      <main id="contenu" class="shell-content">
        <RouterView v-slot="{ Component, route: viewRoute }">
          <div class="page" :key="viewRoute.path">
            <component :is="Component" />
          </div>
        </RouterView>
      </main>
      <AppFooter />
    </div>
    <AppTabbar v-if="mobile" />
  </div>
  <SearchPalette v-if="searchOpen" @close="searchOpen = false" />
  <AccountSheet v-if="accountOpen" @close="accountOpen = false" />
  <TraceursNotice />
</template>

<style scoped>
.skip-link {
  position: absolute;
  left: var(--space-2);
  top: -60px;
  z-index: var(--z-overlay);
  padding: var(--space-2) var(--space-3);
  background: var(--blood);
  color: #fff;
}
.skip-link:focus {
  top: var(--space-2);
}
.shell-main {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 100dvh;
  margin-left: var(--rail-w);
}
.shell--collapsed .shell-main {
  margin-left: var(--rail-w-collapsed);
}
.shell--mobile .shell-main {
  margin-left: 0;
  padding-bottom: calc(var(--tabbar-h) + env(safe-area-inset-bottom));
}
.shell-content {
  flex: 1;
}
</style>
