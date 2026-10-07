<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import UserAvatar from "../components/UserAvatar.vue"
import { createRoom, formatPlayedAt } from "../play.js"
import { pageUrl } from "../seo.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
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
  <div class="wrap cards-wrap amis">
    <h1 class="amis-titre">Mes amis</h1>

    <RiftPanel class="amis-recherche" title="Trouver un joueur">
      <RiftField
        v-model="query"
        search
        label="Rechercher un joueur par pseudo"
        hide-label
        inputmode="search"
        enterkeyhint="search"
        autocapitalize="none"
        autocorrect="off"
        spellcheck="false"
        :placeholder="`Pseudo (${MIN_QUERY} caractères minimum)…`"
      />
      <p v-if="searching" class="amis-etat" role="status">Recherche…</p>
      <ul v-else-if="results.length" class="amis-liste">
        <li v-for="user in results" :key="user.id || user.handle" class="amis-row">
          <UserAvatar :src="user.avatar_url" :handle="user.handle" :size="36" />
          <span class="amis-ident">
            <RouterLink class="amis-nom" :to="profilePath(user.handle)" :title="user.handle">
              {{ user.handle }}
            </RouterLink>
          </span>
          <span class="amis-actions">
            <RiftButton
              v-if="followedHandles.has(user.handle)"
              variant="ghost"
              size="sm"
              :disabled="Boolean(busy)"
              @click="unfollow(user)"
            >
              Suivi
            </RiftButton>
            <RiftButton v-else size="sm" :disabled="Boolean(busy)" @click="follow(user)">Suivre</RiftButton>
          </span>
        </li>
      </ul>
      <p v-else-if="query.trim().length >= MIN_QUERY" class="amis-etat">Aucun joueur à ce pseudo.</p>
    </RiftPanel>

    <p v-if="error" class="amis-erreur" role="alert">{{ error }}</p>

    <div v-else-if="loading" class="amis-squelette" role="status">
      <span class="sr-only">Chargement de vos amis…</span>
      <RiftSkeleton block />
      <RiftSkeleton :lines="3" />
    </div>

    <template v-else>
      <RiftPanel class="amis-panel">
        <template #title>
          Je suis <span class="amis-compte">({{ following.length }})</span>
        </template>
        <ul v-if="following.length" class="amis-liste">
          <li v-for="user in following" :key="user.id || user.handle" class="amis-row">
            <UserAvatar :src="user.avatar_url" :handle="user.handle" :size="36" />
            <span class="amis-ident">
              <RouterLink class="amis-nom" :to="profilePath(user.handle)" :title="user.handle">
                {{ user.handle }}
              </RouterLink>
              <span v-if="formatPlayedAt(user.last_match_at)" class="amis-quand">
                Dernière partie : {{ formatPlayedAt(user.last_match_at) }}
              </span>
            </span>
            <span class="amis-actions">
              <RiftButton size="sm" :disabled="inviting" @click="inviteToRoom(user)">Inviter dans un salon</RiftButton>
              <RiftButton variant="ghost" size="sm" :disabled="Boolean(busy)" @click="unfollow(user)">
                Ne plus suivre
              </RiftButton>
            </span>
          </li>
        </ul>
        <RiftEmpty
          v-else
          title="Personne pour l'instant"
          text="Cherchez un pseudo ci-dessus, ou suivez un adversaire depuis votre historique."
        >
          <RiftButton variant="secondary" size="sm" to="/historique">Ouvrir l'historique</RiftButton>
        </RiftEmpty>
      </RiftPanel>

      <RiftPanel v-if="invite.handle" class="amis-invite" :title="`Salon pour ${invite.handle}`" accent="var(--bronze)">
        <p v-if="invite.error" class="amis-erreur" role="alert">{{ invite.error }}</p>
        <template v-else-if="invite.code">
          <p class="amis-invite-code">{{ invite.code }}</p>
          <p class="amis-texte">Transmettez ce code (ou le lien) à {{ invite.handle }}.</p>
          <div class="amis-actions">
            <RiftButton size="sm" :to="`/salon/${invite.code}`">Ouvrir le salon</RiftButton>
            <RiftButton variant="secondary" size="sm" @click="copyInvite">Copier le lien</RiftButton>
            <span v-if="invite.copied" class="amis-quand" role="status">Lien copié</span>
          </div>
          <p class="amis-quand amis-invite-link">{{ invite.link }}</p>
        </template>
        <p v-else class="amis-texte" role="status">Création du salon…</p>
      </RiftPanel>

      <RiftPanel class="amis-panel">
        <template #title>
          Ils me suivent <span class="amis-compte">({{ followers.length }})</span>
        </template>
        <ul v-if="followers.length" class="amis-liste">
          <li v-for="user in followers" :key="user.id || user.handle" class="amis-row">
            <UserAvatar :src="user.avatar_url" :handle="user.handle" :size="36" />
            <span class="amis-ident">
              <RouterLink class="amis-nom" :to="profilePath(user.handle)" :title="user.handle">
                {{ user.handle }}
              </RouterLink>
            </span>
            <span class="amis-actions">
              <template v-if="followedHandles.has(user.handle)">
                <RiftButton size="sm" :disabled="inviting" @click="inviteToRoom(user)">
                  Inviter dans un salon
                </RiftButton>
                <RiftButton variant="ghost" size="sm" :disabled="Boolean(busy)" @click="unfollow(user)">
                  Ne plus suivre
                </RiftButton>
              </template>
              <RiftButton v-else variant="secondary" size="sm" :disabled="Boolean(busy)" @click="follow(user)">
                Suivre en retour
              </RiftButton>
            </span>
          </li>
        </ul>
        <RiftEmpty v-else title="Personne ne vous suit encore" />
      </RiftPanel>

      <p v-if="empty" class="amis-note">Suivre un joueur reste privé : rien n'est publié, rien n'est notifié.</p>
    </template>
  </div>
</template>

<style scoped>
.amis {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
.amis p {
  margin: 0;
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.amis-titre {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.amis-erreur {
  color: var(--blood-text);
}
.amis-note,
.amis-etat,
.amis-texte,
.amis-quand {
  color: var(--ink-muted);
}
.amis-etat {
  margin-top: var(--space-3);
}
.amis-note {
  text-align: center;
}
.amis-squelette {
  display: grid;
  gap: var(--space-3);
}
.amis-squelette :deep(.rift-skeleton-block) {
  height: 84px;
}
.amis-compte {
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.12em;
  color: var(--ink-muted);
}
.amis-panel {
  min-width: 0;
}
.amis-recherche :deep(.rift-field) {
  margin-bottom: var(--space-3);
}
.amis-nom {
  color: var(--bronze-light);
}
.amis-nom:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}

/* ---------- Lignes ---------- */
.amis-liste {
  display: grid;
  gap: var(--space-2);
  margin: 0;
  padding: 0;
  list-style: none;
}
.amis-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-2) var(--space-3);
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
}
.amis-ident {
  display: grid;
  min-width: 0;
}
.amis-nom {
  display: block;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-weight: 600;
}
.amis-quand {
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.amis-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: var(--space-2);
}

/* ---------- Invitation ---------- */
.amis-invite-code {
  font-family: var(--font-label);
  font-size: 32px;
  font-weight: 700;
  letter-spacing: 0.3em;
  color: var(--bronze-light);
}
.amis-invite .amis-actions {
  justify-content: flex-start;
  margin: var(--space-3) 0;
}
.amis-invite-link {
  overflow-wrap: anywhere;
}

@media (max-width: 639px) {
  .amis-row {
    grid-template-columns: auto minmax(0, 1fr);
  }
  .amis-row .amis-actions {
    grid-column: 1 / -1;
    justify-content: flex-start;
  }
}
</style>
