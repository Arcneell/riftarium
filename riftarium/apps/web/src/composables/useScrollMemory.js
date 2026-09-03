import { nextTick } from "vue"
import { onBeforeRouteLeave, useRoute } from "vue-router"

/* Fiche d'une carte : la seule destination pour laquelle il vaut la peine de
   retenir sa place dans la grille. */
const CARD_SHEET = /^\/cartes\/[^/]+$/

/* Mémorise la position de défilement par URL complète (filtres et page inclus)
   pour retrouver sa place au retour d'une fiche carte, une fois la grille rechargée.
   Le scrollBehavior du routeur ne suffit pas : la grille arrive après un fetch,
   la page est encore vide quand la position sauvegardée est appliquée.

   La position n'est retenue qu'en partant vers une fiche carte : sinon, revenir
   par le menu principal atterrissait en plein milieu de la grille au lieu du haut
   de page. */
export function useScrollMemory({ shouldRemember = (to) => CARD_SHEET.test(to.path) } = {}) {
  const route = useRoute()

  onBeforeRouteLeave((to) => {
    const key = `scroll:${route.fullPath}`
    try {
      if (shouldRemember(to)) sessionStorage.setItem(key, String(Math.round(window.scrollY)))
      else sessionStorage.removeItem(key)
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
