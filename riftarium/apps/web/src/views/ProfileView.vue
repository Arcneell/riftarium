<script setup>
import { computed, onMounted, reactive, ref } from "vue"
import { useRouter } from "vue-router"
import { api, session, setSession } from "../api.js"
import { BANNERS } from "../banners.js"
import AchievementMedal from "../components/AchievementMedal.vue"
import ModalDialog from "../components/ModalDialog.vue"
import PageBanner from "../components/PageBanner.vue"
import UserAvatar from "../components/UserAvatar.vue"
import {
  PRIVACY_TOGGLES,
  achievementPercent,
  achievementProgress,
  formatMemberSince,
  formatUnlockedAt,
  getMyAchievements,
  groupAchievements,
  isUnlocked,
  profilePath,
  tierLabel,
  updatePrivacy
} from "../social.js"

const router = useRouter()

const me = ref(null)
const avatars = ref([])
const loading = ref(true)
const error = ref("")
const exporting = ref(false)

const identity = reactive({ handle: "", bio: "", password: "", saving: false, error: "", ok: "" })
const account = reactive({ email: "", password: "", saving: false, error: "", ok: "" })
const verification = reactive({ sending: false, ok: "", error: "" })
const secret = reactive({ current: "", next: "", confirm: "", saving: false, error: "", ok: "" })
const danger = reactive({ open: false, password: "", handle: "", deleting: false, error: "" })
const avatarBusy = ref(false)

/* Hauts faits : le catalogue complet, groupé par famille, débloqués en tête. */
const achievements = ref([])
const achievementsLoading = ref(true)
const achievementsError = ref("")

/* Confidentialité : quatre interrupteurs enregistrés à la volée (PATCH /api/auth/me). */
const privacy = reactive({ saving: "", error: "", ok: "" })
for (const toggle of PRIVACY_TOGGLES) privacy[toggle.key] = false

const memberSince = computed(() => formatMemberSince(me.value?.created_at))
const unlockedCount = computed(() => achievements.value.reduce((sum, group) => sum + group.unlocked, 0))
const achievementCount = computed(() => achievements.value.reduce((sum, group) => sum + group.total, 0))

function applyProfile(profile) {
  me.value = profile
  identity.handle = profile.handle
  identity.bio = profile.bio || ""
  account.email = profile.email
  setSession(session.token, profile.handle, profile.avatar_url)
  /* Tient le bandeau global (App.vue) au courant du statut de vérification. */
  if ("email_verified" in profile) session.emailVerified = profile.email_verified
  if ("is_admin" in profile) session.isAdmin = profile.is_admin
  /* Le contrat n'envoie les quatre booléens que depuis la migration 0010 : sans
     eux, on retombe sur « masqué », jamais sur une case cochée par défaut. */
  for (const toggle of PRIVACY_TOGGLES) privacy[toggle.key] = Boolean(profile[toggle.key])
}

async function load() {
  loading.value = true
  error.value = ""
  try {
    const [profile, faces] = await Promise.all([api("/api/auth/me"), api("/api/auth/avatars")])
    applyProfile(profile)
    avatars.value = faces
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

/* Appel à part : un catalogue de hauts faits indisponible ne doit pas priver le
   joueur de ses formulaires de compte. */
async function loadAchievements() {
  achievementsLoading.value = true
  achievementsError.value = ""
  try {
    achievements.value = groupAchievements(await getMyAchievements())
  } catch (e) {
    achievements.value = []
    achievementsError.value = e.message
  } finally {
    achievementsLoading.value = false
  }
}

/* Bascule optimiste : l'interrupteur suit le doigt, et revient en arrière si l'API refuse. */
async function togglePrivacy(key) {
  if (privacy.saving) return
  const next = !privacy[key]
  privacy[key] = next
  privacy.saving = key
  privacy.error = ""
  privacy.ok = ""
  try {
    applyProfile(await updatePrivacy({ [key]: next }))
    privacy.ok = "Réglage enregistré"
  } catch (e) {
    privacy[key] = !next
    privacy.error = e.message
  } finally {
    privacy.saving = ""
  }
}

async function pickAvatar(cardId) {
  if (avatarBusy.value) return
  avatarBusy.value = true
  error.value = ""
  try {
    applyProfile(await api("/api/auth/me", { method: "PATCH", body: { avatar_card_id: cardId } }))
  } catch (e) {
    error.value = e.message
  } finally {
    avatarBusy.value = false
  }
}

async function saveIdentity() {
  if (identity.saving) return
  identity.saving = true
  identity.error = ""
  identity.ok = ""
  const body = { bio: identity.bio }
  if (identity.handle !== me.value.handle) {
    body.handle = identity.handle
    body.current_password = identity.password
  }
  try {
    applyProfile(await api("/api/auth/me", { method: "PATCH", body }))
    identity.password = ""
    identity.ok = "Profil mis à jour"
  } catch (e) {
    identity.error = e.message
  } finally {
    identity.saving = false
  }
}

async function saveEmail() {
  if (account.saving) return
  account.saving = true
  account.error = ""
  account.ok = ""
  try {
    applyProfile(
      await api("/api/auth/me", {
        method: "PATCH",
        body: { email: account.email, current_password: account.password }
      })
    )
    account.password = ""
    account.ok = "Email mis à jour — un e-mail de vérification a été envoyé à la nouvelle adresse."
  } catch (e) {
    account.error = e.message
  } finally {
    account.saving = false
  }
}

async function resendVerification() {
  if (verification.sending) return
  verification.sending = true
  verification.ok = ""
  verification.error = ""
  try {
    await api("/api/auth/resend-verification", { method: "POST" })
    verification.ok = "E-mail de vérification renvoyé. Pensez à vérifier vos indésirables."
  } catch (e) {
    if (e.status === 429) verification.error = "Trop de demandes. Réessayez dans quelques minutes."
    else if (e.status === 400) {
      /* Adresse déjà vérifiée : on met le profil à jour. */
      if (me.value) me.value.email_verified = true
      session.emailVerified = true
    } else verification.error = e.message
  } finally {
    verification.sending = false
  }
}

async function savePassword() {
  if (secret.saving) return
  if (secret.next !== secret.confirm) {
    secret.error = "Les mots de passe ne correspondent pas"
    secret.ok = ""
    return
  }
  secret.saving = true
  secret.error = ""
  secret.ok = ""
  try {
    const result = await api("/api/auth/password", {
      method: "POST",
      body: { current_password: secret.current, new_password: secret.next }
    })
    setSession("1", result.handle, result.avatar_url || me.value?.avatar_url)
    secret.current = ""
    secret.next = ""
    secret.confirm = ""
    secret.ok = "Mot de passe mis à jour"
  } catch (e) {
    secret.error = e.message
  } finally {
    secret.saving = false
  }
}

async function downloadExport() {
  if (exporting.value) return
  exporting.value = true
  error.value = ""
  try {
    const data = await api("/api/auth/export")
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = `riftarium-${data.handle}.json`
    link.click()
    URL.revokeObjectURL(url)
  } catch (e) {
    error.value = e.message
  } finally {
    exporting.value = false
  }
}

function openDanger() {
  danger.open = true
  danger.password = ""
  danger.handle = ""
  danger.error = ""
}

async function deleteAccount() {
  if (danger.deleting) return
  danger.deleting = true
  danger.error = ""
  try {
    await api("/api/auth/me", {
      method: "DELETE",
      body: { password: danger.password, handle: danger.handle }
    })
    setSession(null, null)
    router.push("/")
  } catch (e) {
    danger.error = e.message
  } finally {
    danger.deleting = false
  }
}

onMounted(() => {
  load()
  loadAchievements()
})
</script>

<template>
  <PageBanner :art="BANNERS.auth" title="Mon profil" />

  <section>
    <div class="wrap profile-page">
      <p v-if="error" class="error">{{ error }}</p>
      <p v-else-if="loading" class="muted">Chargement du profil…</p>

      <template v-else-if="me">
        <div class="profile-hero panel">
          <UserAvatar :src="me.avatar_url" :handle="me.handle" :size="92" />
          <div>
            <h3>{{ me.handle }}</h3>
            <p class="muted" v-if="me.bio">{{ me.bio }}</p>
            <p class="muted mono" v-else>Pas encore de bio.</p>
            <p class="muted mono" v-if="memberSince">Membre depuis {{ memberSince }}</p>
          </div>
          <!-- Les deux pages qui prolongent le compte : ce que les autres voient, et son carnet d'adversaires. -->
          <div class="profile-hero-actions">
            <RouterLink class="btn btn-ghost btn-sm" :to="profilePath(me.handle)">Voir mon profil public</RouterLink>
            <RouterLink class="btn btn-ghost btn-sm" to="/amis">Mes amis</RouterLink>
          </div>
        </div>

        <div class="stat-row">
          <div class="stat">
            Cartes uniques
            <b>{{ me.stats.unique_cards }}</b>
          </div>
          <div class="stat">
            Exemplaires
            <b>{{ me.stats.total_cards }}</b>
          </div>
          <div class="stat">
            Decks
            <b>{{ me.stats.decks }}</b>
          </div>
          <div class="stat">
            Decks publics
            <b>{{ me.stats.public_decks }}</b>
          </div>
          <div class="stat">
            Likes reçus
            <b>{{ me.stats.likes_received }}</b>
          </div>
        </div>

        <div class="panel profile-section">
          <h3>
            Hauts faits
            <span v-if="achievementCount" class="mono muted">({{ unlockedCount }} / {{ achievementCount }})</span>
          </h3>
          <p class="muted" style="margin-bottom: 16px">
            Les hauts faits liés aux parties ne comptent que les duels suivis et confirmés — jamais la partie libre.
          </p>
          <p v-if="achievementsError" class="error">{{ achievementsError }}</p>
          <p v-else-if="achievementsLoading" class="muted">Chargement des hauts faits…</p>
          <template v-else>
            <div v-for="group in achievements" :key="group.family" class="medal-family">
              <p class="medal-family-head mono">
                {{ group.label }} <span class="muted">{{ group.unlocked }} / {{ group.total }}</span>
              </p>
              <ul class="medal-grid">
                <li
                  v-for="item in group.items"
                  :key="item.key"
                  class="medal"
                  :class="[`tier-${item.tier || 'bronze'}`, { locked: !isUnlocked(item) }]"
                >
                  <AchievementMedal
                    :achievement-key="item.key"
                    :icon="item.icon"
                    :tier="item.tier"
                    :locked="!isUnlocked(item)"
                  />
                  <span class="medal-body">
                    <b>{{ item.title }}</b>
                    <span class="muted">{{ item.description }}</span>
                    <span v-if="isUnlocked(item)" class="mono medal-meta">
                      {{ tierLabel(item.tier) }}
                      <template v-if="formatUnlockedAt(item.unlocked_at)">
                        · débloqué le {{ formatUnlockedAt(item.unlocked_at) }}
                      </template>
                    </span>
                    <template v-else>
                      <span class="progress-bar medal-bar">
                        <i :style="{ width: `${achievementPercent(item)}%` }"></i>
                      </span>
                      <span class="mono medal-meta">{{ achievementProgress(item) }}</span>
                    </template>
                  </span>
                </li>
              </ul>
            </div>
            <p v-if="!achievements.length" class="muted">Aucun haut fait au catalogue pour l'instant.</p>
          </template>
        </div>

        <div class="profile-grid">
          <div class="panel profile-privacy">
            <h3>Confidentialité</h3>
            <p class="muted" style="margin-bottom: 16px">
              Ce que votre <RouterLink :to="profilePath(me.handle)">profil public</RouterLink> montre aux autres
              joueurs.
            </p>
            <ul class="privacy-list">
              <li v-for="toggle in PRIVACY_TOGGLES" :key="toggle.key">
                <label class="switch">
                  <input
                    type="checkbox"
                    :checked="privacy[toggle.key]"
                    :disabled="Boolean(privacy.saving)"
                    @change="togglePrivacy(toggle.key)"
                  /><i></i>
                  <span class="privacy-label">
                    <b>{{ toggle.label }}</b>
                    <span class="muted">{{ toggle.hint }}</span>
                  </span>
                </label>
              </li>
            </ul>
            <p v-if="privacy.error" class="error">{{ privacy.error }}</p>
            <p v-else-if="privacy.saving" class="muted mono">Enregistrement…</p>
            <p v-else-if="privacy.ok" class="success">{{ privacy.ok }}</p>
          </div>

          <form class="panel" @submit.prevent="saveIdentity">
            <h3>Identité</h3>
            <p class="muted" style="margin-bottom: 16px">Le pseudo apparaît sur vos decks publics.</p>
            <div class="field">
              <label for="profile-handle">Pseudo</label>
              <input
                id="profile-handle"
                type="text"
                v-model="identity.handle"
                autocapitalize="none"
                autocorrect="off"
                spellcheck="false"
                minlength="3"
                maxlength="32"
                autocomplete="username"
                required
              />
            </div>
            <div class="field">
              <label for="profile-bio">Bio</label>
              <textarea
                id="profile-bio"
                v-model="identity.bio"
                maxlength="280"
                placeholder="Main, région, ce que vous cherchez en communauté…"
              ></textarea>
            </div>
            <div class="field" v-if="identity.handle !== me.handle">
              <label for="profile-handle-pwd">Mot de passe actuel</label>
              <input
                id="profile-handle-pwd"
                type="password"
                v-model="identity.password"
                autocomplete="current-password"
                required
              />
            </div>
            <p v-if="identity.error" class="error">{{ identity.error }}</p>
            <p v-if="identity.ok" class="success">{{ identity.ok }}</p>
            <button class="btn btn-gold" type="submit" :disabled="identity.saving">
              {{ identity.saving ? "Enregistrement…" : "Enregistrer" }}
            </button>
          </form>

          <div class="panel">
            <h3>Portrait de légende</h3>
            <p class="muted" style="margin-bottom: 16px">Choisissez un portrait parmi les légendes Riftbound.</p>
            <div class="avatar-scroller" :class="{ busy: avatarBusy }" tabindex="0" aria-label="Choisir un portrait">
              <div class="avatar-grid">
                <button
                  type="button"
                  class="avatar-pick"
                  :class="{ selected: !me.avatar_card_id }"
                  :aria-pressed="!me.avatar_card_id"
                  @click="pickAvatar(null)"
                >
                  <UserAvatar :handle="me.handle" :size="72" />
                  <span>Initiales</span>
                </button>
                <button
                  v-for="face in avatars"
                  :key="face.id"
                  type="button"
                  class="avatar-pick"
                  :class="{ selected: me.avatar_card_id === face.id }"
                  :aria-pressed="me.avatar_card_id === face.id"
                  :title="face.name"
                  @click="pickAvatar(face.id)"
                >
                  <UserAvatar :src="face.image_url" :handle="face.name" :size="72" :orientation="face.orientation" />
                  <span>{{ face.name }}</span>
                </button>
              </div>
            </div>
            <p v-if="!avatars.length" class="muted">Aucune légende disponible pour le moment.</p>
          </div>

          <form class="panel" @submit.prevent="saveEmail">
            <h3>Email</h3>
            <div v-if="me.email_verified === false" class="verify-line">
              <p class="muted">Adresse e-mail non vérifiée.</p>
              <button
                class="btn btn-ghost btn-sm"
                type="button"
                :disabled="verification.sending"
                @click="resendVerification"
              >
                {{ verification.sending ? "Envoi…" : "Renvoyer l'e-mail" }}
              </button>
              <p v-if="verification.ok" class="success">{{ verification.ok }}</p>
              <p v-if="verification.error" class="error">{{ verification.error }}</p>
            </div>
            <div class="field">
              <label for="profile-email">Adresse</label>
              <input id="profile-email" type="email" v-model="account.email" autocomplete="email" required />
            </div>
            <div class="field">
              <label for="profile-email-pwd">Mot de passe actuel</label>
              <input
                id="profile-email-pwd"
                type="password"
                v-model="account.password"
                autocomplete="current-password"
                required
              />
            </div>
            <p v-if="account.error" class="error">{{ account.error }}</p>
            <p v-if="account.ok" class="success">{{ account.ok }}</p>
            <button class="btn btn-gold" type="submit" :disabled="account.saving">
              {{ account.saving ? "Enregistrement…" : "Changer l'email" }}
            </button>
          </form>

          <form class="panel" @submit.prevent="savePassword">
            <h3>Mot de passe</h3>
            <div class="field">
              <label for="profile-pwd-current">Mot de passe actuel</label>
              <input
                id="profile-pwd-current"
                type="password"
                v-model="secret.current"
                autocomplete="current-password"
                required
              />
            </div>
            <div class="field">
              <label for="profile-pwd-new">Nouveau mot de passe</label>
              <input
                id="profile-pwd-new"
                type="password"
                v-model="secret.next"
                minlength="8"
                autocomplete="new-password"
                required
                placeholder="8 caractères minimum"
              />
            </div>
            <div class="field">
              <label for="profile-pwd-confirm">Confirmation</label>
              <input
                id="profile-pwd-confirm"
                type="password"
                v-model="secret.confirm"
                minlength="8"
                autocomplete="new-password"
                required
              />
            </div>
            <p v-if="secret.error" class="error">{{ secret.error }}</p>
            <p v-if="secret.ok" class="success">{{ secret.ok }}</p>
            <button class="btn btn-gold" type="submit" :disabled="secret.saving">
              {{ secret.saving ? "Enregistrement…" : "Changer le mot de passe" }}
            </button>
          </form>

          <div class="panel">
            <h3>Vos données</h3>
            <p class="muted" style="margin-bottom: 16px">
              Export JSON de votre compte (collection, decks, profil) — droit d'accès RGPD. Détail des traitements :
              <RouterLink to="/confidentialite">politique de confidentialité</RouterLink>.
            </p>
            <button class="btn" type="button" :disabled="exporting" @click="downloadExport">
              {{ exporting ? "Préparation…" : "Exporter mon compte" }}
            </button>
          </div>

          <div class="panel profile-danger">
            <h3>Zone sensible</h3>
            <p class="muted" style="margin-bottom: 16px">
              La suppression efface définitivement votre compte, votre collection et vos decks.
            </p>
            <button class="btn btn-danger" type="button" @click="openDanger">Supprimer mon compte</button>
          </div>
        </div>
      </template>
    </div>
  </section>

  <ModalDialog v-if="danger.open" title="Supprimer le compte" @close="danger.open = false">
    <p>
      Cette action est irréversible. Saisissez votre mot de passe et votre pseudo
      <strong>{{ me?.handle }}</strong> pour confirmer.
    </p>
    <form class="modal-form" @submit.prevent="deleteAccount">
      <label>
        Mot de passe
        <input type="password" v-model="danger.password" autocomplete="current-password" required />
      </label>
      <label>
        Pseudo
        <input
          type="text"
          v-model="danger.handle"
          autocomplete="off"
          autocapitalize="none"
          autocorrect="off"
          spellcheck="false"
          required
        />
      </label>
      <p v-if="danger.error" class="error">{{ danger.error }}</p>
      <div class="modal-actions">
        <button type="button" class="btn btn-ghost" :disabled="danger.deleting" @click="danger.open = false">
          Annuler
        </button>
        <button type="submit" class="btn btn-danger" :disabled="danger.deleting">
          {{ danger.deleting ? "Suppression…" : "Supprimer définitivement" }}
        </button>
      </div>
    </form>
  </ModalDialog>
</template>
