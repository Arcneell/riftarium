import { createRouter, createWebHistory } from "vue-router"
import { session } from "./api.js"
import HomeView from "./views/HomeView.vue"

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomeView },
    { path: "/cartes", component: () => import("./views/CardsView.vue") },
    { path: "/cartes/:id", component: () => import("./views/CardView.vue") },
    { path: "/regles", component: () => import("./views/RulesHubView.vue") },
    { path: "/regles/debutant", component: () => import("./views/BeginnerGuideView.vue") },
    { path: "/regles/avancee", component: () => import("./views/AdvancedHelpView.vue") },
    { path: "/regles/avancee/:slug", component: () => import("./views/AdvancedTopicView.vue") },
    { path: "/regles/officielles", component: () => import("./views/RulesView.vue") },
    { path: "/collection", component: () => import("./views/CollectionView.vue"), meta: { auth: true } },
    { path: "/decks", component: () => import("./views/DecksView.vue"), meta: { auth: true } },
    { path: "/decks/:id", component: () => import("./views/DeckEditView.vue") },
    { path: "/communaute", component: () => import("./views/CommunityView.vue") },
    { path: "/connexion", component: () => import("./views/AuthView.vue") },
    { path: "/profil", component: () => import("./views/ProfileView.vue"), meta: { auth: true } }
  ],
  /* Ne remonte pas quand seule la query change (étapes du guide, filtres). */
  scrollBehavior: (to, from, savedPosition) => {
    if (to.path === from.path) return false
    return savedPosition || { top: 0 }
  }
})

router.beforeEach((to) => {
  if (to.meta.auth && !session.token) {
    return { path: "/connexion", query: { suite: to.fullPath } }
  }
})
