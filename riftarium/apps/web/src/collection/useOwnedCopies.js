import { computed, reactive, ref, toValue, watch } from "vue"
import { api, session } from "../api.js"
import { readDefaults, writeDefaults } from "./collectionDefaults.js"

/* Exemplaires possédés d'une carte : lots, total, compteur +/−, lots détaillés.
   `cardId` est une ref (ou un getter) ; `onChange({ id, owned_qty })` prévient le parent
   après chaque mutation réussie. `autoload: false` laisse l'appelant charger les lots
   à la demande (compteur de vignette : premier « − »). */
export function useOwnedCopies(cardId, { onChange, autoload = true } = {}) {
  const entries = ref([])
  const loading = ref(false)
  const busy = ref(false)
  const error = ref("")
  const defaults = reactive(readDefaults())
  const total = computed(() => entries.value.reduce((sum, entry) => sum + entry.qty, 0))

  /* Jeton de séquence unique pour chargements et mutations : seule la dernière opération
     (ou la dernière carte) a le droit d'écrire dans l'état. */
  let seq = 0

  function setDefaults(patch) {
    Object.assign(defaults, patch)
    writeDefaults({ condition: defaults.condition, lang: defaults.lang })
  }

  async function load() {
    const id = toValue(cardId)
    const mine = ++seq
    entries.value = []
    error.value = ""
    loading.value = false
    if (!session.token || !id) return
    loading.value = true
    try {
      const state = await api(`/api/collection/${id}`)
      if (mine !== seq) return
      entries.value = state.entries
    } catch (e) {
      if (mine === seq) error.value = e.message
    } finally {
      if (mine === seq) loading.value = false
    }
  }

  if (autoload) watch(() => toValue(cardId), load, { immediate: true })
  else
    watch(
      () => toValue(cardId),
      () => ++seq
    )

  /* Une mutation lancée pendant une autre est ignorée. Retourne vrai si elle est passée. */
  async function mutate(request) {
    if (busy.value) return false
    const id = toValue(cardId)
    if (!id) return false
    const mine = ++seq
    loading.value = false
    busy.value = true
    error.value = ""
    try {
      const state = await request(id)
      /* Réponse tardive (carte changée, autre opération depuis) : on l'oublie. */
      if (mine !== seq) return false
      entries.value = state.entries
      onChange?.({ id, owned_qty: state.total_qty })
      return true
    } catch (e) {
      if (mine === seq) error.value = e.message
      return false
    } finally {
      busy.value = false
    }
  }

  const post = (qty, condition, lang) => (id) =>
    api(`/api/collection/${id}/entries`, { method: "POST", body: { qty, condition, lang } })
  const patch = (entry, qty) => () => api(`/api/collection/entries/${entry.id}`, { method: "PATCH", body: { qty } })

  const increment = () => mutate(post(1, defaults.condition, defaults.lang))
  const addLot = ({ qty, condition, lang }) => mutate(post(qty, condition, lang))
  const removeLot = (entry) => mutate(patch(entry, 0))

  function decrement() {
    if (!total.value) return false
    const preferred = entries.value.find((e) => e.condition === defaults.condition && e.lang === defaults.lang)
    const entry = preferred ?? entries.value.reduce((best, e) => (e.id > best.id ? e : best))
    return mutate(patch(entry, entry.qty - 1))
  }

  return { entries, total, loading, busy, error, defaults, setDefaults, load, increment, decrement, addLot, removeLot }
}
