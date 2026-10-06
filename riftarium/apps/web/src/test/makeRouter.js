import { createMemoryHistory, createRouter } from "vue-router"

/* Routeur mémoire pour les tests de la coquille : mêmes chemins que l'application,
   composants vides. `initial` est la page sur laquelle le test démarre. */
const Empty = { template: "<div />" }

export const APP_PATHS = [
  "/",
  "/cartes",
  "/cartes/:id",
  "/decks",
  "/decks/:id",
  "/communaute",
  "/collection",
  "/wishlist",
  "/regles",
  "/regles/debutant",
  "/regles/debutant/plateau",
  "/regles/debutant/:slug",
  "/regles/avancee",
  "/regles/avancee/:slug",
  "/regles/officielles",
  "/salon/:code?",
  "/historique",
  "/statistiques",
  "/profil",
  "/u/:handle",
  "/amis",
  "/admin",
  "/connexion",
  "/mentions-legales",
  "/confidentialite",
  "/cgu",
  "/cookies",
  "/signalement",
  "/:pathMatch(.*)*"
]

export async function makeRouter(initial = "/", paths = APP_PATHS) {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: paths.map((path) => ({ path, component: Empty }))
  })
  router.push(initial)
  await router.isReady()
  return router
}
