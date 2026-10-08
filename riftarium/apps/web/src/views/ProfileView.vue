<script setup>
import { computed, onMounted, reactive, ref } from "vue"
import { useRouter } from "vue-router"
import { api, session, setSession } from "../api.js"
import ProfileAchievements from "../social/ProfileAchievements.vue"
import ProfileHero from "../social/ProfileHero.vue"
import ProfileIdentity from "../social/ProfileIdentity.vue"
import ProfilePrivacy from "../social/ProfilePrivacy.vue"
import ProfileSecurity from "../social/ProfileSecurity.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftField from "../ui/RiftField.vue"
import RiftModal from "../ui/RiftModal.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import RiftStat from "../ui/RiftStat.vue"
import {
  PRIVACY_TOGGLES,
  formatMemberSince,
  getMyAchievements,
  groupAchievements,
  profilePath,
  updatePrivacy
} from "../social.js"

const router = useRouter()

const me = ref(null)
const avatars = ref([])
const loading = ref(true)
/* `loadError` = le profil n'a pas pu être lu, il n'y a rien à afficher ;
   `actionError` = une action a échoué alors que la page est là (portrait, export).
   Les mélanger effaçait toute la page sur un simple 429. */
const loadError = ref("")
const actionError = ref("")
const exporting = ref(false)
const avatarBusy = ref(false)
const danger = reactive({ open: false, password: "", handle: "", deleting: false, error: "" })

/* Hauts faits : le catalogue complet, groupé par famille, débloqués en tête. */
const achievements = ref([])
const achievementsLoading = ref(true)
const achievementsError = ref("")

/* Confidentialité : quatre interrupteurs enregistrés à la volée (PATCH /api/auth/me). */
const privacy = reactive({ saving: "", error: "", ok: "" })
const privacyValues = reactive({})
for (const toggle of PRIVACY_TOGGLES) privacyValues[toggle.key] = false

const memberSince = computed(() => formatMemberSince(me.value?.created_at))
const heroMeta = computed(() => [memberSince.value ? `Membre depuis ${memberSince.value}` : ""])
const kpis = computed(() => {
  const stats = me.value?.stats || {}
  return [
    { label: "Cartes uniques", value: stats.unique_cards },
    { label: "Exemplaires", value: stats.total_cards },
    { label: "Decks", value: stats.decks },
    { label: "Decks publics", value: stats.public_decks },
    { label: "Likes reçus", value: stats.likes_received }
  ]
})

/* Les formulaires (sous-composants) gardent leur saisie : une réponse d'action
   rafraîchit le profil affiché sans écraser un pseudo ou une bio en cours. */
function applyProfile(profile) {
  me.value = profile
  setSession(session.token, profile.handle, profile.avatar_url)
  /* Tient le bandeau global (App.vue) au courant du statut de vérification. */
  if ("email_verified" in profile) session.emailVerified = profile.email_verified
  if ("is_admin" in profile) session.isAdmin = profile.is_admin
  /* Le contrat n'envoie les quatre booléens que depuis la migration 0010 : sans
     eux, on retombe sur « masqué », jamais sur une case cochée par défaut. */
  for (const toggle of PRIVACY_TOGGLES) privacyValues[toggle.key] = Boolean(profile[toggle.key])
  return profile
}

async function load() {
  loading.value = true
  loadError.value = ""
  try {
    const [profile, faces] = await Promise.all([api("/api/auth/me"), api("/api/auth/avatars")])
    applyProfile(profile)
    avatars.value = faces
  } catch (e) {
    loadError.value = e.message
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
  const next = !privacyValues[key]
  privacyValues[key] = next
  privacy.saving = key
  privacy.error = ""
  privacy.ok = ""
  try {
    applyProfile(await updatePrivacy({ [key]: next }))
    privacy.ok = "Réglage enregistré"
  } catch (e) {
    privacyValues[key] = !next
    privacy.error = e.message
  } finally {
    privacy.saving = ""
  }
}

async function pickAvatar(cardId) {
  if (avatarBusy.value) return
  avatarBusy.value = true
  actionError.value = ""
  try {
    applyProfile(await api("/api/auth/me", { method: "PATCH", body: { avatar_card_id: cardId } }))
  } catch (e) {
    actionError.value = e.message
  } finally {
    avatarBusy.value = false
  }
}

/* Réseau des formulaires de compte : chaque fonction lève en cas de refus, le
   sous-composant affiche le message sur place. */
const saveIdentity = async (body) => applyProfile(await api("/api/auth/me", { method: "PATCH", body }))
const saveEmail = async (body) => applyProfile(await api("/api/auth/me", { method: "PATCH", body }))

async function savePassword(body) {
  const result = await api("/api/auth/password", { method: "POST", body })
  setSession("1", result.handle, result.avatar_url || me.value?.avatar_url)
}

async function resendVerification() {
  try {
    await api("/api/auth/resend-verification", { method: "POST" })
    return true
  } catch (e) {
    if (e.status === 429) throw new Error("Trop de demandes. Réessayez dans quelques minutes.", { cause: e })
    if (e.status !== 400) throw e
    /* Adresse déjà vérifiée : on met le profil à jour, le rappel disparaît. */
    if (me.value) me.value.email_verified = true
    session.emailVerified = true
    return false
  }
}

async function downloadExport() {
  if (exporting.value) return
  exporting.value = true
  actionError.value = ""
  try {
    const data = await api("/api/auth/export")
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = `riftarium-${data.handle}.json`
    /* Firefox n'honore le clic que sur un lien réellement dans le document, et
       révoquer l'URL tout de suite annule parfois le téléchargement : on nettoie
       au tour de boucle suivant. */
    document.body.append(link)
    link.click()
    setTimeout(() => {
      link.remove()
      URL.revokeObjectURL(url)
    }, 0)
  } catch (e) {
    actionError.value = e.message
  } finally {
    exporting.value = false
  }
}

function closeDanger() {
  danger.open = false
  danger.password = ""
  danger.handle = ""
  danger.error = ""
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
  <div class="wrap cards-wrap profil">
    <template v-if="loadError || loading || !me">
      <h1 class="profil-titre">Mon profil</h1>
      <p v-if="loadError" class="profil-erreur" role="alert">{{ loadError }}</p>
      <div v-else-if="loading" role="status">
        <span class="sr-only">Chargement du profil…</span>
        <RiftSkeleton block />
      </div>
    </template>

    <template v-else>
      <ProfileHero :handle="me.handle" :avatar-url="me.avatar_url || ''" :bio="me.bio || ''" :meta="heroMeta">
        <!-- Les deux pages qui prolongent le compte : ce que les autres voient, et son carnet d'adversaires. -->
        <template #actions>
          <RiftButton variant="secondary" size="sm" :to="profilePath(me.handle)">Voir mon profil public</RiftButton>
          <RiftButton variant="ghost" size="sm" to="/amis">Mes amis</RiftButton>
        </template>
      </ProfileHero>

      <!-- Échec d'une action : le message s'affiche sous l'en-tête, le profil reste là. -->
      <p v-if="actionError" class="profil-erreur" role="alert">{{ actionError }}</p>

      <div class="profil-kpis">
        <RiftStat v-for="kpi in kpis" :key="kpi.label" :label="kpi.label" :value="kpi.value ?? 0" />
      </div>

      <div class="profil-colonnes">
        <div class="profil-colonne">
          <ProfileAchievements :groups="achievements" :loading="achievementsLoading" :error="achievementsError" />
          <ProfilePrivacy
            :values="privacyValues"
            :saving="privacy.saving"
            :error="privacy.error"
            :ok="privacy.ok"
            :public-path="profilePath(me.handle)"
            @toggle="togglePrivacy"
          />
        </div>

        <div class="profil-colonne">
          <ProfileIdentity
            :profile="me"
            :avatars="avatars"
            :picking="avatarBusy"
            :save="saveIdentity"
            @pick="pickAvatar"
          />
          <ProfileSecurity
            :email="me.email"
            :unverified="me.email_verified === false"
            :save-email="saveEmail"
            :save-password="savePassword"
            :resend-verification="resendVerification"
          />

          <RiftPanel title="Vos données" accent="var(--bronze)">
            <p class="profil-texte">
              Export JSON de votre compte (collection, decks, profil) — droit d'accès RGPD. Détail des traitements :
              <RouterLink to="/confidentialite">politique de confidentialité</RouterLink>.
            </p>
            <RiftButton variant="secondary" :disabled="exporting" @click="downloadExport">
              {{ exporting ? "Préparation…" : "Exporter mon compte" }}
            </RiftButton>
          </RiftPanel>

          <RiftPanel class="profil-danger" title="Zone sensible" accent="var(--blood)">
            <p class="profil-texte">
              La suppression efface définitivement votre compte, votre collection et vos decks.
            </p>
            <RiftButton @click="openDanger">Supprimer mon compte</RiftButton>
          </RiftPanel>
        </div>
      </div>
    </template>
  </div>

  <RiftModal v-if="danger.open" title="Supprimer le compte" @close="closeDanger">
    <form class="compte-modal" @submit.prevent="deleteAccount">
      <p class="profil-texte">
        Cette action est irréversible. Saisissez votre mot de passe et votre pseudo
        <strong class="profil-fort">{{ me?.handle }}</strong> pour confirmer.
      </p>
      <RiftField
        v-model="danger.password"
        label="Mot de passe"
        type="password"
        name="delete-password"
        autocomplete="current-password"
        required
      />
      <RiftField
        v-model="danger.handle"
        label="Pseudo"
        name="delete-handle"
        autocomplete="off"
        autocapitalize="none"
        autocorrect="off"
        spellcheck="false"
        required
      />
      <p v-if="danger.error" class="profil-erreur" role="alert">{{ danger.error }}</p>
      <div class="compte-modal-actions">
        <RiftButton variant="ghost" :disabled="danger.deleting" @click="closeDanger">Annuler</RiftButton>
        <RiftButton type="submit" :disabled="danger.deleting">
          {{ danger.deleting ? "Suppression…" : "Supprimer définitivement" }}
        </RiftButton>
      </div>
    </form>
  </RiftModal>
</template>

<style scoped>
.profil {
  display: grid;
  gap: var(--space-4);
  padding-top: var(--space-5);
  padding-bottom: var(--space-6);
}
/* main.css colore et anime les h1 : on neutralise pour la page. */
.profil-titre {
  margin: 0;
  background: none;
  color: var(--ink);
  animation: none;
  font-weight: 700;
}
.profil-erreur {
  margin: 0;
  color: var(--blood-text);
}
.profil-texte {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
}
.profil-fort {
  color: var(--ink);
  overflow-wrap: anywhere;
}
.profil-kpis {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: var(--space-3);
}
/* Deux colonnes au-dessus de 1 024 px : hauts faits et confidentialité à gauche,
   compte à droite. Une seule en dessous, dans le même ordre. */
.profil-colonnes {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  align-items: start;
  gap: var(--space-4);
}
.profil-colonne {
  display: grid;
  gap: var(--space-4);
  min-width: 0;
}
.profil-danger :deep(.rift-panel-title) {
  color: var(--blood-text);
}
.compte-modal {
  display: grid;
  gap: var(--space-4);
}
.compte-modal .profil-texte {
  margin: 0;
  color: var(--ink);
}
.compte-modal-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: var(--space-2);
}

@media (min-width: 1024px) {
  .profil-colonnes {
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  }
}
</style>
