<script setup>
import "./console.css"
import { computed, nextTick, reactive, ref, watch } from "vue"
import { api } from "../api.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"
import RiftModal from "../ui/RiftModal.vue"
import { buildQuery, formatDate, formatDateTime, PAGE_SIZE, usePagedList, useRowAction } from "./useAdmin.js"

/* Durées de suspension proposées (876000 h ≈ 100 ans : « définitif »). */
const PERMANENT_HOURS = 876000
const SUSPEND_DURATIONS = [
  { hours: 24, label: "24 heures" },
  { hours: 168, label: "7 jours" },
  { hours: 720, label: "30 jours" },
  { hours: PERMANENT_HOURS, label: "Définitif" }
]

const {
  state: users,
  load: loadUsers,
  schedule: scheduleUsers,
  pageCount
} = usePagedList((s) => `/api/admin/users?${buildQuery({ q: s.q.trim(), page: s.page, page_size: PAGE_SIZE })}`, {
  q: ""
})
const { busyKey, rowError, run } = useRowAction()

watch(
  () => users.q,
  () => {
    users.page = 1
    scheduleUsers()
  }
)
watch(() => users.page, scheduleUsers)

/* Premier affichage, puis chaque retour sur l'onglet : la liste est rechargée, la
   recherche et la page sont conservées (le panneau reste monté, masqué). */
const props = defineProps({ active: { type: Boolean, default: true } })
loadUsers()
watch(
  () => props.active,
  (active) => {
    if (active) loadUsers()
  }
)

function liftSuspension(user) {
  run(`user:${user.id}`, () => api(`/api/admin/users/${user.id}/suspend`, { method: "DELETE" }), loadUsers)
}

/* --- Modale de suspension. Une suspension définitive demande une confirmation
   explicite : la première validation ne fait qu'afficher l'étape de confirmation. --- */
const suspend = reactive({ user: null, hours: 24, reason: "", confirming: false, busy: false, error: "" })
const suspendTitle = computed(() => (suspend.confirming ? "Confirmer la suspension définitive" : "Suspendre le compte"))

function openSuspend(user) {
  suspend.user = user
  suspend.hours = 24
  suspend.reason = ""
  suspend.confirming = false
  suspend.error = ""
}

function closeSuspend() {
  if (suspend.busy) return
  suspend.user = null
  suspend.confirming = false
}

const confirmBox = ref(null)
const durationSelect = ref(null)

/* Le formulaire disparaît au profit de l'avertissement : le focus y est posé (jamais sur
   « Suspendre définitivement », pour qu'un Entrée réflexe n'envoie rien). */
async function requestSuspend() {
  if (suspend.busy || !suspend.user) return
  if (Number(suspend.hours) === PERMANENT_HOURS && !suspend.confirming) {
    suspend.confirming = true
    suspend.error = ""
    await nextTick()
    confirmBox.value?.focus()
    return
  }
  submitSuspend()
}

/* Retour au formulaire : le motif et la durée saisis sont conservés. */
async function backToForm() {
  if (suspend.busy) return
  suspend.confirming = false
  suspend.error = ""
  await nextTick()
  durationSelect.value?.focus()
}

async function submitSuspend() {
  if (suspend.busy || !suspend.user) return
  suspend.busy = true
  suspend.error = ""
  try {
    await api(`/api/admin/users/${suspend.user.id}/suspend`, {
      method: "POST",
      body: { hours: Number(suspend.hours), reason: suspend.reason.trim() }
    })
    suspend.user = null
    suspend.confirming = false
    await loadUsers()
  } catch (e) {
    suspend.error = e.message
  } finally {
    suspend.busy = false
  }
}

/* --- Modale de suppression d'un compte (pseudo à retaper) --- */
const removal = reactive({ user: null, confirm: "", busy: false, error: "" })

function openRemoval(user) {
  removal.user = user
  removal.confirm = ""
  removal.error = ""
}

async function submitRemoval() {
  if (removal.busy || !removal.user) return
  if (removal.confirm.trim() !== removal.user.handle) {
    removal.error = "Le pseudo saisi ne correspond pas."
    return
  }
  removal.busy = true
  removal.error = ""
  try {
    await api(`/api/admin/users/${removal.user.id}`, { method: "DELETE" })
    removal.user = null
    await loadUsers()
  } catch (e) {
    removal.error = e.message
  } finally {
    removal.busy = false
  }
}
</script>

<template>
  <div>
    <div class="console-toolbar">
      <RiftField
        v-model="users.q"
        class="console-search"
        label="Rechercher un utilisateur"
        hide-label
        search
        placeholder="Pseudo ou e-mail…"
        inputmode="search"
        enterkeyhint="search"
        autocapitalize="off"
        autocorrect="off"
        spellcheck="false"
      />
      <span class="console-mono console-count" aria-live="polite">
        {{ users.total }} compte(s) <span v-if="users.loading">— chargement…</span>
      </span>
    </div>
    <p v-if="users.error" class="console-error" role="alert">{{ users.error }}</p>

    <table v-if="users.items.length" class="console-table">
      <thead>
        <tr>
          <th scope="col">Compte</th>
          <th scope="col">Statut</th>
          <th scope="col">Activité</th>
          <th scope="col">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="user in users.items" :key="user.id" class="console-row">
          <td class="console-id-cell" data-label="Compte">
            <div class="console-id">
              <span class="console-id-name">{{ user.handle }}</span>
              <span class="console-mono">{{ user.email }}</span>
              <span class="console-mono">inscrit le {{ formatDate(user.created_at) }}</span>
            </div>
          </td>
          <td data-label="Statut">
            <div class="console-chips">
              <RiftChip v-if="user.is_admin" static selected label="Admin" color="var(--bronze-light)" />
              <RiftChip v-if="user.email_verified" static label="E-mail vérifié" />
              <RiftChip
                v-if="user.suspended_until"
                static
                selected
                color="var(--blood-text)"
                :label="`Suspendu jusqu'au ${formatDateTime(user.suspended_until)}`"
                :title="user.suspension_reason || undefined"
              />
            </div>
          </td>
          <td class="console-mono" data-label="Activité">
            {{ user.decks_count }} decks · {{ user.collection_count }} cartes
          </td>
          <td class="console-actions-cell" data-label="Actions">
            <div class="console-actions">
              <RiftButton variant="ghost" size="sm" :disabled="Boolean(busyKey)" @click="openSuspend(user)">
                Suspendre
              </RiftButton>
              <RiftButton
                v-if="user.suspended_until"
                variant="ghost"
                size="sm"
                :disabled="Boolean(busyKey)"
                @click="liftSuspension(user)"
              >
                Lever la suspension
              </RiftButton>
              <RiftButton
                variant="ghost"
                size="sm"
                class="console-danger"
                :disabled="Boolean(busyKey)"
                @click="openRemoval(user)"
              >
                Supprimer
              </RiftButton>
            </div>
            <p v-if="rowError.key === `user:${user.id}`" class="console-row-error" role="alert">
              {{ rowError.message }}
            </p>
          </td>
        </tr>
      </tbody>
    </table>
    <RiftEmpty
      v-if="!users.loading && !users.items.length && !users.error"
      title="Aucun compte ne correspond à la recherche."
    />

    <nav v-if="pageCount > 1" class="console-pager" aria-label="Pages des comptes">
      <RiftButton variant="secondary" size="sm" :disabled="users.page <= 1" @click="users.page--">
        ← Précédent
      </RiftButton>
      <span class="console-mono">page {{ users.page }} / {{ pageCount }}</span>
      <RiftButton variant="secondary" size="sm" :disabled="users.page >= pageCount" @click="users.page++">
        Suivant →
      </RiftButton>
    </nav>

    <RiftModal v-if="suspend.user" :title="suspendTitle" @close="closeSuspend">
      <form v-if="!suspend.confirming" class="console-form" @submit.prevent="requestSuspend">
        <p>
          Le compte <strong>{{ suspend.user.handle }}</strong> ne pourra plus se connecter pendant la durée choisie. Le
          motif lui sera affiché.
        </p>
        <label class="console-label">
          Motif (obligatoire)
          <textarea v-model="suspend.reason" class="console-input" rows="3" maxlength="500" required></textarea>
        </label>
        <label class="console-label">
          Durée
          <select ref="durationSelect" v-model.number="suspend.hours" class="console-input">
            <option v-for="duration in SUSPEND_DURATIONS" :key="duration.hours" :value="duration.hours">
              {{ duration.label }}
            </option>
          </select>
        </label>
        <p v-if="suspend.error" class="console-error" role="alert">{{ suspend.error }}</p>
        <div class="console-modal-actions">
          <RiftButton variant="ghost" :disabled="suspend.busy" @click="closeSuspend">Annuler</RiftButton>
          <RiftButton type="submit" :disabled="suspend.busy">
            {{ suspend.busy ? "Suspension…" : "Suspendre" }}
          </RiftButton>
        </div>
      </form>
      <div v-else class="console-form">
        <div ref="confirmBox" class="console-confirm" tabindex="-1">
          <p>
            La suspension définitive de <strong>{{ suspend.user.handle }}</strong> l'empêchera de se reconnecter, sans
            date de fin. Seul un administrateur pourra la lever.
          </p>
          <p class="console-muted">Motif : {{ suspend.reason.trim() }}</p>
        </div>
        <p v-if="suspend.error" class="console-error" role="alert">{{ suspend.error }}</p>
        <div class="console-modal-actions">
          <RiftButton variant="ghost" :disabled="suspend.busy" @click="closeSuspend">Annuler</RiftButton>
          <RiftButton variant="secondary" :disabled="suspend.busy" @click="backToForm">Retour</RiftButton>
          <RiftButton :disabled="suspend.busy" @click="submitSuspend">
            {{ suspend.busy ? "Suspension…" : "Suspendre définitivement" }}
          </RiftButton>
        </div>
      </div>
    </RiftModal>

    <RiftModal v-if="removal.user" title="Supprimer le compte" @close="removal.user = null">
      <form class="console-form" @submit.prevent="submitRemoval">
        <p>
          Cette action est irréversible : le compte, sa collection et ses decks seront effacés. Saisissez le pseudo
          <strong>{{ removal.user.handle }}</strong> pour confirmer.
        </p>
        <RiftField
          v-model="removal.confirm"
          label="Pseudo"
          autocomplete="off"
          autocapitalize="none"
          autocorrect="off"
          spellcheck="false"
          required
        />
        <p v-if="removal.error" class="console-error" role="alert">{{ removal.error }}</p>
        <div class="console-modal-actions">
          <RiftButton variant="ghost" :disabled="removal.busy" @click="removal.user = null">Annuler</RiftButton>
          <RiftButton type="submit" :disabled="removal.busy">
            {{ removal.busy ? "Suppression…" : "Supprimer définitivement" }}
          </RiftButton>
        </div>
      </form>
    </RiftModal>
  </div>
</template>
