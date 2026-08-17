import { createRouter, createWebHistory } from "vue-router";
import { session } from "./api.js";

import HomeView from "./views/HomeView.vue";
import CardsView from "./views/CardsView.vue";
import CardView from "./views/CardView.vue";
import CollectionView from "./views/CollectionView.vue";
import DecksView from "./views/DecksView.vue";
import DeckEditView from "./views/DeckEditView.vue";
import CommunityView from "./views/CommunityView.vue";
import AuthView from "./views/AuthView.vue";
import RulesView from "./views/RulesView.vue";

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/", component: HomeView },
    { path: "/cartes", component: CardsView },
    { path: "/cartes/:id", component: CardView },
    { path: "/regles", component: RulesView },
    { path: "/collection", component: CollectionView, meta: { auth: true } },
    { path: "/decks", component: DecksView, meta: { auth: true } },
    { path: "/decks/:id", component: DeckEditView, meta: { auth: true } },
    { path: "/communaute", component: CommunityView },
    { path: "/connexion", component: AuthView }
  ],
  scrollBehavior: () => ({ top: 0 })
});

router.beforeEach(to => {
  if (to.meta.auth && !session.token) {
    return { path: "/connexion", query: { suite: to.fullPath } };
  }
});
