import { nextTick } from "vue"
import { onBeforeRouteLeave, useRoute } from "vue-router"

/* Mémorise la position de défilement par URL complète (filtres et page inclus)
   pour retrouver sa place au retour d'une fiche carte, une fois la grille rechargée.
   Le scrollBehavior du routeur ne suffit pas : la grille arrive après un fetch,
   la page est encore vide quand la position sauvegardée est appliquée. */
export function useScrollMemory() {
  const route = useRoute()

  onBeforeRouteLeave(() => {
    try {
      sessionStorage.setItem(`scroll:${route.fullPath}`, String(Math.round(window.scrollY)))
    } catch {
      /* stockage indisponible : tant pis pour la restauration */
    }
  })

  /* À appeler une fois la grille chargée et rendue. */
  async function restoreScroll() {
    let saved
    const key = `scroll:${route.fullPath}`
    try {
      saved = Number(sessionStorage.getItem(key))
      sessionStorage.removeItem(key)
    } catch {
      saved = 0
    }
    if (!saved) return
    await nextTick()
    window.scrollTo({ top: saved })
  }

  return { restoreScroll }
}
