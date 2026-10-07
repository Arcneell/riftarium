import { computed, reactive, ref } from "vue"
import { session } from "../api.js"
import { readDefaults, writeDefaults } from "./collectionDefaults.js"

/* Saisie rapide (membres) : interrupteur mémorisé pour la session et préférences d'ajout.
   `defaults` est un objet réactif unique, à passer à tous les compteurs : le prochain « + »
   de n'importe quelle vignette ou pochette suit le choix de la feuille de préférence. */
const QUICK_KEY = "riftarium_quick_add"

function readQuick() {
  try {
    return sessionStorage.getItem(QUICK_KEY) === "1"
  } catch {
    return false
  }
}

export function useQuickAdd() {
  const quick = ref(readQuick())
  const quickOn = computed(() => quick.value && !!session.token)
  const defaults = reactive(readDefaults())

  function toggleQuick() {
    quick.value = !quick.value
    try {
      sessionStorage.setItem(QUICK_KEY, quick.value ? "1" : "0")
    } catch {
      /* stockage bloqué : l'interrupteur ne survit pas au rechargement */
    }
  }

  function setDefaults(patch) {
    Object.assign(defaults, patch)
    writeDefaults({ condition: defaults.condition, lang: defaults.lang })
  }

  return { quickOn, toggleQuick, defaults, setDefaults }
}
