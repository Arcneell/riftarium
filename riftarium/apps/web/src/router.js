import { createRouter, createWebHistory } from "vue-router"
import { session } from "./api.js"
import { applyRouteSeo } from "./seo.js"
import HomeView from "./views/HomeView.vue"

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      component: HomeView,
      meta: {
        title: "Riftarium — Cartes, decks et règles Riftbound",
        description:
          "Cartothèque, deck builder, règles officielles et collection pour Riftbound. Site fan-made gratuit, en français."
      }
    },
    {
      path: "/cartes",
      component: () => import("./views/CardsView.vue"),
      meta: {
        title: "Cartes Riftbound",
        description:
          "Toutes les cartes Riftbound, variantes incluses. Recherche et filtres par domaine, type, rareté et set."
      }
    },
    {
      path: "/cartes/:id",
      component: () => import("./views/CardView.vue"),
      meta: {
        title: "Carte Riftbound",
        description: "Fiche de carte Riftbound : texte, visuel officiel, variantes et collection."
      }
    },
    {
      path: "/regles",
      component: () => import("./views/RulesHubView.vue"),
      meta: {
        title: "Règles Riftbound",
        description: "Guide du débutant, aide avancée et texte officiel des règles Riftbound en français."
      }
    },
    {
      path: "/regles/debutant",
      component: () => import("./views/BeginnerGuideView.vue"),
      meta: {
        title: "Apprendre à jouer à Riftbound",
        description: "Guide animé du débutant Riftbound : plateau, tour, combat et score, en quelques minutes."
      }
    },
    {
      path: "/regles/avancee",
      component: () => import("./views/AdvancedHelpView.vue"),
      meta: {
        title: "Aide avancée Riftbound",
        description: "Mécaniques Riftbound expliquées : timing, combat, champs de bataille, mots-clés."
      }
    },
    {
      path: "/regles/avancee/:slug",
      component: () => import("./views/AdvancedTopicView.vue"),
      meta: {
        title: "Aide Riftbound",
        description: "Explication d'une mécanique Riftbound, avec exemples et texte officiel."
      }
    },
    {
      path: "/regles/officielles",
      component: () => import("./views/RulesView.vue"),
      meta: {
        title: "Règles officielles Riftbound",
        description: "Texte intégral des règles du jeu et des règles de tournoi Riftbound, en français."
      }
    },
    {
      path: "/collection",
      component: () => import("./views/CollectionView.vue"),
      meta: {
        auth: true,
        noindex: true,
        title: "Ma collection",
        description: "Inventaire personnel de cartes Riftbound."
      }
    },
    {
      path: "/decks",
      component: () => import("./views/DecksView.vue"),
      meta: { auth: true, noindex: true, title: "Mes decks", description: "Vos decks Riftbound sur Riftarium." }
    },
    {
      path: "/decks/:id",
      component: () => import("./views/DeckEditView.vue"),
      meta: {
        title: "Deck Riftbound",
        description: "Liste de deck Riftbound partagée sur Riftarium."
      }
    },
    {
      path: "/communaute",
      component: () => import("./views/CommunityView.vue"),
      meta: {
        title: "Decks de la communauté Riftbound",
        description: "Decks Riftbound publiés par les joueurs : légendes, domaines, formats officiel ou non officiel."
      }
    },
    {
      path: "/connexion",
      component: () => import("./views/AuthView.vue"),
      meta: { noindex: true, title: "Connexion", description: "Connexion ou inscription à Riftarium." }
    },
    {
      path: "/profil",
      component: () => import("./views/ProfileView.vue"),
      meta: { auth: true, noindex: true, title: "Mon profil", description: "Compte Riftarium." }
    },
    {
      path: "/mentions-legales",
      component: () => import("./views/LegalView.vue"),
      meta: {
        legal: "mentions",
        title: "Mentions légales",
        description: "Éditeur, hébergeur OVH et mentions Riot Games."
      }
    },
    {
      path: "/confidentialite",
      component: () => import("./views/LegalView.vue"),
      meta: {
        legal: "privacy",
        title: "Politique de confidentialité",
        description: "Données personnelles traitées par Riftarium."
      }
    },
    {
      path: "/cgu",
      component: () => import("./views/LegalView.vue"),
      meta: { legal: "terms", title: "Conditions d'utilisation", description: "Conditions d'utilisation de Riftarium." }
    },
    {
      path: "/cookies",
      component: () => import("./views/LegalView.vue"),
      meta: {
        legal: "cookies",
        title: "Cookies et traceurs",
        description: "Traceurs utilisés par Riftarium : session uniquement, pas de publicité."
      }
    },
    {
      path: "/signalement",
      component: () => import("./views/LegalView.vue"),
      meta: {
        legal: "report",
        title: "Signaler un contenu",
        description: "Signaler un contenu illicite ou abusif sur Riftarium."
      }
    }
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

router.afterEach((to) => {
  applyRouteSeo(to)
})
