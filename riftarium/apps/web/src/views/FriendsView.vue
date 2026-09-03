<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { BANNERS } from "../banners.js"
import PageBanner from "../components/PageBanner.vue"
import UserAvatar from "../components/UserAvatar.vue"
import { createRoom, formatPlayedAt } from "../play.js"
import { pageUrl } from "../seo.js"
import { followUser, getFollows, profilePath, searchUsers, unfollowUser } from "../social.js"

const SEARCH_DEBOUNCE_MS = 300
/* L'API refuse les requêtes plus courtes : inutile de les envoyer. */
const MIN_QUERY = 2
/* Durée d'affichage de l'accusé « Lien copié ». */
const COPIED_RESET_MS = 2000

const following = ref([])
const followers = ref([])
const loading = ref(true)
const error = ref("")
/* Pseudo en cours d'action ; toutes les actions sont désactivées pendant ce temps
   (une seule requête sociale à la fois, la liste est rafraîchie après). */
const busy = ref("")

const query = ref("")
const results = ref([])
const searching = ref(false)

/* Un seul salon d'invitation à la fois : le code qui vient d'être créé et le lien à partager. */
const invite = ref({ handle: "", code: "", link: "", copied: false, error: "" })
const inviting = ref(false)

let searchTimer = null
let searchSeq = 0
let copiedTimer = null

const followedHandles = computed(() => new Set(following.value.map((user) => user.handle)))
const empty = computed(() => !loading.value && !error.value && !following.value.length && !followers.value.length)

async function load() {
  loading.value = true
  error.value = ""
  try {
    const payload = await getFollows()
    following.value = payload?.following || []
    followers.value = payload?.followers || []
  } catch (e) {
    error.value = e.message
    following.value = []
    followers.value = []
  } finally {
    loading.value = false
  }
}

/* Jeton de séquence : une réponse lente ne doit pas écraser le résultat d'une
   frappe plus récente (ni rallumer « Recherche… » après coup). */
async function runSearch(term) {
  const seq = ++searchSeq
  searching.value = true
  try {
    const payload = await searchUsers(term)
    if (seq !== searchSeq) return
    results.value = Array.isArray(payload) ? payload : payload?.items || []
  } catch {
    /* Recherche indisponible (429 compris) : la liste reste vide, sans message alarmant. */
    if (seq === searchSeq) results.value = []
  } finally {
    if (seq === searchSeq) searching.value = false
  }
}

watch(query, (value) => {
  clearTimeout(searchTimer)
  const term = value.trim()
  if (term.length < MIN_QUERY) {
    /* Requête abandonnée : la réponse d'une recherche encore en vol est périmée. */
    searchSeq += 1
    results.value = []
    searching.value = false
    return
  }
  searchTimer = setTimeout(() => runSearch(term), SEARCH_DEBOUNCE_MS)
})

async function follow(user) {
  if (busy.value) return
  busy.value = user.handle
  error.value = ""
  try {
    await followUser(user.handle)
    if (!followedHandles.value.has(user.handle)) following.value = [...following.value, { ...user }]
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = ""
  }
}

async function unfollow(user) {
  if (busy.value) return
  busy.value = user.handle
  error.value = ""
  try {
    await unfollowUser(user.handle)
    following.value = following.value.filter((item) => item.handle !== user.handle)
    if (invite.value.handle === user.handle) invite.value = { handle: "", code: "", link: "", copied: false, error: "" }
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = ""
  }
}

/* Inviter, c'est ouvrir un salon de duel et partager son code : le site ne pousse
   aucune notification, c'est le joueur qui transmet le lien par son propre canal. */
async function inviteToRoom(user) {
  if (inviting.value) return
  inviting.value = true
  invite.value = { handle: user.handle, code: "", link: "", copied: false, error: "" }
  try {
    const room = await createRoom("duel")
    invite.value.code = room.code
    invite.value.link = pageUrl(`/salon/${room.code}`)
  } catch (e) {
    invite.value.error = e.message
  } finally {
    inviting.value = false
  }
}

async function copyInvite() {
  if (!invite.value.link) return
  try {
    await navigator.clipboard.writeText(invite.value.link)
    invite.value.copied = true
    /* « Lien copié » est un accusé de réception, pas un état : il s'effface au bout
       de deux secondes pour que le bouton redevienne cliquable dans sa forme normale. */
    clearTimeout(copiedTimer)
    copiedTimer = setTimeout(() => {
      invite.value.copied = false
    }, COPIED_RESET_MS)
  } catch {
    invite.value.error = "Copie impossible : sélectionnez le lien à la main."
  }
}

onMounted(load)
onBeforeUnmount(() => {
  clearTimeout(searchTimer)
  clearTimeout(copiedTimer)
})
</script>

<template>
  <PageBanner :art="BANNERS.community" title="Mes amis" />

  <section>
    <div class="wrap friends-page">
      <div class="panel friends-search">
        <h2>Trouver un joueur</h2>
        <label class="search filter-search" for="friends-q">
          <Icon name="search" :size="18" />
          <input
            id="friends-q"
            v-model="query"
            type="search"
            inputmode="search"
            enterkeyhint="search"
            autocapitalize="none"
            autocorrect="off"
            spellcheck="false"
            :placeholder="`Pseudo (${MIN_QUERY} caractères minimum)…`"
            aria-label="Rechercher un joueur par pseudo"
          />
        </label>
        <p v-if="searching" class="muted mono">Recherche…</p>
        <ul v-else-if="results.length" class="friend-list">
          <li v-for="user in results" :key="user.id || user.handle" class="friend-row">
            <UserAvatar :src="user.avatar_url" :handle="user.handle" :size="36" />
            <RouterLink class="friend-name" :to="profilePath(user.handle)">{{ user.handle }}</RouterLink>
            <button
              v-if="followedHandles.has(user.handle)"
              type="button"
              class="btn btn-ghost btn-sm"
              :disabled="Boolean(busy)"
              @click="unfollow(user)"
            >
              Ne plus suivre
            </button>
            <button v-else type="button" class="btn btn-gold btn-sm" :disabled="Boolean(busy)" @click="follow(user)">
              Suivre
            </button>
          </li>
        </ul>
        <p v-else-if="query.trim().length >= MIN_QUERY" class="muted mono">Aucun joueur à ce pseudo.</p>
      </div>

      <p v-if="error" class="error">{{ error }}</p>
      <p v-else-if="loading" class="muted">Chargement de vos amis…</p>

      <template v-else>
        <div class="panel friends-panel">
          <h2>
            Suivis <span class="mono muted">({{ following.length }})</span>
          </h2>
          <ul v-if="following.length" class="friend-list">
            <li v-for="user in following" :key="user.id || user.handle" class="friend-row">
              <UserAvatar :src="user.avatar_url" :handle="user.handle" :size="36" />
              <span class="friend-ident">
                <RouterLink class="friend-name" :to="profilePath(user.handle)">{{ user.handle }}</RouterLink>
                <span v-if="formatPlayedAt(user.last_match_at)" class="mono muted friend-when">
                  Dernière partie : {{ formatPlayedAt(user.last_match_at) }}
                </span>
              </span>
              <button type="button" class="btn btn-gold btn-sm" :disabled="inviting" @click="inviteToRoom(user)">
                Inviter dans un salon
              </button>
              <button type="button" class="btn btn-ghost btn-sm" :disabled="Boolean(busy)" @click="unfollow(user)">
                Ne plus suivre
              </button>
            </li>
          </ul>
          <p v-else class="muted">
            Personne pour l'instant. Cherchez un pseudo ci-dessus, ou suivez un adversaire depuis votre
            <RouterLink to="/historique">historique</RouterLink>.
          </p>
        </div>

        <div v-if="invite.handle" class="panel friends-invite">
          <h2>Salon pour {{ invite.handle }}</h2>
          <p v-if="invite.error" class="error">{{ invite.error }}</p>
          <template v-else-if="invite.code">
            <p class="mono friends-invite-code">{{ invite.code }}</p>
            <p class="muted">Transmettez ce code (ou le lien) à {{ invite.handle }}.</p>
            <div class="friends-invite-actions">
              <RouterLink class="btn btn-gold btn-sm" :to="`/salon/${invite.code}`">Ouvrir le salon</RouterLink>
              <button type="button" class="btn btn-ghost btn-sm" @click="copyInvite">Copier le lien</button>
              <span v-if="invite.copied" class="mono muted" role="status">Lien copié</span>
            </div>
            <p class="mono muted friends-invite-link">{{ invite.link }}</p>
          </template>
          <p v-else class="muted">Création du salon…</p>
        </div>

        <div class="panel friends-panel">
          <h2>
            Abonnés <span class="mono muted">({{ followers.length }})</span>
          </h2>
          <ul v-if="followers.length" class="friend-list">
            <li v-for="user in followers" :key="user.id || user.handle" class="friend-row">
              <UserAvatar :src="user.avatar_url" :handle="user.handle" :size="36" />
              <RouterLink class="friend-name" :to="profilePath(user.handle)">{{ user.handle }}</RouterLink>
              <button
                v-if="!followedHandles.has(user.handle)"
                type="button"
                class="btn btn-ghost btn-sm"
                :disabled="Boolean(busy)"
                @click="follow(user)"
              >
                Suivre en retour
              </button>
            </li>
          </ul>
          <p v-else class="muted">Personne ne vous suit encore.</p>
        </div>

        <p v-if="empty" class="muted friends-note">
          Suivre un joueur reste privé : rien n'est publié, rien n'est notifié.
        </p>
      </template>
    </div>
  </section>
</template>
