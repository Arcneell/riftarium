import { computed, onBeforeUnmount, reactive, ref } from "vue"
import { api } from "../api.js"

/* Briques communes aux onglets de la console d'administration : formats, statuts
   de modération, listes paginées débouncées et actions par ligne. */

export const PAGE_SIZE = 20

/* Statuts de modération renvoyés par l'API (le POST accepte approved|rejected).
   Couleurs de puce : publié bronze clair, en attente encre atténuée, rejeté sang. */
export const MODERATION = {
  pending: { label: "En attente", color: "var(--ink-muted)" },
  published: { label: "Publié", color: "var(--bronze-light)" },
  approved: { label: "Approuvé", color: "var(--bronze-light)" },
  rejected: { label: "Rejeté", color: "var(--blood-text)" }
}

export const moderationLabel = (status) => MODERATION[status]?.label || status
export const moderationColor = (status) => MODERATION[status]?.color || "var(--ink-muted)"

export const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short", year: "numeric" }) : ""
export const formatDateTime = (iso) =>
  iso
    ? new Date(iso).toLocaleString("fr-FR", {
        day: "numeric",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit"
      })
    : ""

export function buildQuery(params) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value !== "" && value !== null && value !== undefined) query.set(key, value)
  }
  return query.toString()
}

/* Liste paginée : `pathFor(state)` construit l'URL de la page courante. Les réponses
   périmées (numéro de séquence dépassé) sont ignorées ; `schedule` débounce de 250 ms. */
export function usePagedList(pathFor, initial = {}) {
  const state = reactive({ page: 1, total: 0, size: PAGE_SIZE, items: [], loading: false, error: "", ...initial })
  let timer = null
  let seq = 0

  async function load() {
    const current = ++seq
    state.loading = true
    state.error = ""
    try {
      const data = await api(pathFor(state))
      if (current !== seq) return
      state.total = data.total
      state.size = data.size || PAGE_SIZE
      state.items = data.items
      if (state.page > 1 && !data.items.length) state.page = 1
    } catch (e) {
      if (current === seq) state.error = e.message
    } finally {
      if (current === seq) state.loading = false
    }
  }

  function schedule() {
    clearTimeout(timer)
    timer = setTimeout(load, 250)
  }

  const pageCount = computed(() => Math.max(1, Math.ceil(state.total / state.size)))

  onBeforeUnmount(() => clearTimeout(timer))

  return { state, load, schedule, pageCount }
}

/* Actions par ligne : un seul busy à la fois, erreur affichée sur la ligne.
   Pendant une action, TOUTES les lignes sont désactivées (et pas seulement la
   ligne en cours) : la liste est rechargée après coup, un second clic ailleurs
   agirait sur des données en train de changer. En échec, rien n'est rechargé :
   la ligne garde son état. */
export function useRowAction() {
  const busyKey = ref("")
  const rowError = reactive({ key: "", message: "" })

  async function run(key, request, reload) {
    if (busyKey.value) return
    busyKey.value = key
    rowError.key = ""
    rowError.message = ""
    try {
      await request()
      await reload()
    } catch (e) {
      rowError.key = key
      rowError.message = e.message
    } finally {
      busyKey.value = ""
    }
  }

  return { busyKey, rowError, run }
}
