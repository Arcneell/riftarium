import { onBeforeUnmount, onMounted, ref, watch } from "vue"

/* Sauvegarde automatique d'un deck en édition : comparaison d'instantanés sérialisés,
   débounce, save de rattrapage au démontage et garde beforeunload.

   - deck    : ref du deck édité
   - saveFn  : envoie le deck au serveur (et rapatrie les champs calculés)
   - options :
     - snapshot() : instantané sérialisé de ce qui doit être sauvegardé (requis)
     - canEdit()  : getter, l'utilisateur peut-il éditer ce deck ? (requis)
     - error      : ref d'erreur partagée avec la vue (requis)
     - debounce   : délai avant sauvegarde (900 ms par défaut) */
export function useDeckAutosave(deck, saveFn, options) {
  const { snapshot, canEdit, error, debounce = 900 } = options

  const saveState = ref("") // "" | "saving" | "saved" | "error"
  /* Session expirée pendant l'édition : on garde le brouillon affiché et modifiable localement. */
  const sessionExpired = ref(false)
  let savedSnapshot = ""
  let saveTimer = null

  /* Après un chargement : l'état courant devient la référence « déjà sauvegardé ». */
  function markSaved() {
    savedSnapshot = snapshot()
  }

  async function save() {
    if (!canEdit() || !deck.value || sessionExpired.value || snapshot() === savedSnapshot) return
    saveState.value = "saving"
    const sent = snapshot()
    try {
      await saveFn()
      savedSnapshot = sent
      saveState.value = "saved"
    } catch (e) {
      saveState.value = "error"
      /* 401 : on ne bascule pas en lecture seule, le brouillon reste affiché et éditable localement. */
      if (e.status === 401) {
        sessionExpired.value = true
        error.value = "Session expirée, reconnectez-vous pour enregistrer vos modifications."
      } else {
        error.value = e.message
      }
    }
  }

  function scheduleSave() {
    clearTimeout(saveTimer)
    saveTimer = setTimeout(save, debounce)
  }

  watch(
    () => (deck.value ? snapshot() : ""),
    (next, previous) => {
      if (!canEdit() || !deck.value || !previous || next === savedSnapshot) return
      if (!sessionExpired.value) error.value = "" // le message « session expirée » reste affiché
      scheduleSave()
    }
  )

  /* Modifications non sauvegardées : le navigateur demande confirmation avant de quitter la page. */
  function onBeforeUnload(event) {
    if (!canEdit() || !deck.value || snapshot() === savedSnapshot) return
    event.preventDefault()
    event.returnValue = "" // requis par les navigateurs historiques
  }

  onMounted(() => window.addEventListener("beforeunload", onBeforeUnload))

  onBeforeUnmount(() => {
    /* Save de rattrapage d'abord, tant que le deck est encore en mémoire. */
    clearTimeout(saveTimer)
    save()
    window.removeEventListener("beforeunload", onBeforeUnload)
  })

  return { saveState, sessionExpired, save, scheduleSave, markSaved }
}
