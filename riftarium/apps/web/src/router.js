import { createRouter, createWebHistory } from "vue-router"
import { session } from "./api.js"
import HomeView from "./views/HomeView.vue"

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomeView },
    { path: "/cartes", component: () => import("./views/CardsView.vue") },
    { path: "/cartes/:id", component: () => import("./views/CardView.vue") },
    { path: "/regles", component: () => import("./views/RulesView.vue") },
    { path: "/collection", component: () => import("./views/CollectionView.vue"), meta: { auth: true } },
    { path: "/decks", component: () => import("./views/DecksView.vue"), meta: { auth: true } },
    { path: "/decks/:id", component: () => import("./views/DeckEditView.vue"), meta: { auth: true } },
    { path: "/communaute", component: () => import("./views/CommunityView.vue") },
    { path: "/connexion", component: () => import("./views/AuthView.vue") }
  ],
  scrollBehavior: () => ({ top: 0 })
})

router.beforeEach((to) => {
  if (to.meta.auth && !session.token) {
    return { path: "/connexion", query: { suite: to.fullPath } }
  }
})
