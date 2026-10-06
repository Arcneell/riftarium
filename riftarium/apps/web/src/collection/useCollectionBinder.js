import { computed, ref, watch } from "vue"
import { api } from "../api.js"

const SPREAD_SIZE = 18 // 2 pages de 3×3 : une double page = une page d'API

export const GHOST_FILTERS = [
  { value: "", label: "Tout" },
  { value: "1", label: "Possédées" },
  { value: "0", label: "Manquantes" }
]

/* Une page de classeur = 9 pochettes, complétées par des pochettes vides. */
function padPage(list) {
  const out = [...list]
  while (out.length < 9) out.push(null)
  return out
}

/* Logique du classeur : double page de 9 pochettes, cartes manquantes en fantôme.
   `active()` : le classeur est affiché ; `isBlocked()` : une modale capte les flèches.
   Aucun écouteur global ici : le composant attache `onKeydown` et le retire. */
export function useCollectionBinder({ active, isBlocked }) {
  const binderSet = ref("")
  const binderPage = ref(1)
  const binderOwned = ref("") // "" tout · "1" possédées · "0" manquantes
  const binderLoading = ref(false)
  const binderError = ref("")
  /* Instantané affiché : remplacé seulement quand la réponse arrive, pour que
     l'animation de tournage parte d'une page pleine vers une page pleine. */
  const spread = ref(null) // { key, items, page, pages, total }
  const turnDir = ref(1) // 1 : on avance (ou change de set), -1 : on recule

  let seq = 0

  async function loadBinder() {
    if (!binderSet.value || !active()) return
    const mine = ++seq
    binderLoading.value = true
    binderError.value = ""
    try {
      const params = new URLSearchParams({
        set_id: binderSet.value,
        page: String(binderPage.value),
        size: String(SPREAD_SIZE)
      })
      if (binderOwned.value) params.set("owned", binderOwned.value)
      const data = await api(`/api/cards?${params}`)
      if (mine !== seq) return
      spread.value = {
        key: `${binderSet.value}|${binderOwned.value}|${data.page}`,
        items: data.items,
        page: data.page,
        pages: Math.max(1, Math.ceil(data.total / SPREAD_SIZE)),
        total: data.total
      }
    } catch (e) {
      if (mine === seq) binderError.value = e.message
    } finally {
      if (mine === seq) binderLoading.value = false
    }
  }

  watch([binderSet, binderPage, binderOwned], loadBinder)

  function selectSet(setId) {
    if (setId === binderSet.value) return
    turnDir.value = 1
    binderSet.value = setId
    binderPage.value = 1
  }

  function setGhostFilter(value) {
    if (value === binderOwned.value) return
    turnDir.value = 1
    binderOwned.value = value
    binderPage.value = 1
  }

  function turnPage(delta) {
    const next = binderPage.value + delta
    if (next < 1 || (spread.value && next > spread.value.pages)) return
    turnDir.value = delta
    binderPage.value = next
  }

  /* Flèches gauche/droite : on feuillette au clavier, sauf dans un champ de saisie. */
  function onKeydown(event) {
    if (!active() || !spread.value || isBlocked()) return
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return
    const target = event.target
    if (target && (/^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName) || target.isContentEditable)) return
    if (event.key === "ArrowRight") {
      event.preventDefault()
      turnPage(1)
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      turnPage(-1)
    }
  }

  const leftCards = computed(() => padPage(spread.value ? spread.value.items.slice(0, 9) : []))
  const rightCards = computed(() => padPage(spread.value ? spread.value.items.slice(9, 18) : []))

  return {
    binderSet,
    binderPage,
    binderOwned,
    binderLoading,
    binderError,
    spread,
    turnDir,
    leftCards,
    rightCards,
    selectSet,
    setGhostFilter,
    turnPage,
    loadBinder,
    onKeydown
  }
}
