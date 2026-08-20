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
      /* Accessible sans compte : le scan identifie la carte, l'ajout à la collection demande la connexion. */
      path: "/scan",
      component: () => import("./views/ScanView.vue"),
      meta: {
        noindex: true,
        title: "Scanner une carte",
        description: "Identifier une carte Riftbound avec l'appareil photo et l'ajouter à sa collection."
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
      path: "/mot-de-passe-oublie",
      component: () => import("./views/ForgotPasswordView.vue"),
      meta: {
        noindex: true,
        title: "Mot de passe oublié",
        description: "Recevoir un e-mail de réinitialisation du mot de passe Riftarium."
      }
    },
    {
      path: "/reinitialisation",
      component: () => import("./views/ResetPasswordView.vue"),
      meta: {
        noindex: true,
        title: "Réinitialiser le mot de passe",
        description: "Choisir un nouveau mot de passe pour votre compte Riftarium."
      }
    },
    {
      path: "/verification-email",
      component: () => import("./views/VerifyEmailView.vue"),
      meta: {
        noindex: true,
        title: "Vérification de l'adresse e-mail",
        description: "Confirmation de l'adresse e-mail d'un compte Riftarium."
      }
    },
    {
      path: "/profil",
      component: () => import("./views/ProfileView.vue"),
      meta: { auth: true, noindex: true, title: "Mon profil", description: "Compte Riftarium." }
    },
    {
      /* Console d'administration masquée : pour tout visiteur non admin (connecté ou non),
         la porte rend la page 404 du site — mêmes titre et description, zéro indice.
         Jamais dans le sitemap. Le code de la console n'est chargé que pour un admin. */
      path: "/admin",
      component: () => import("./views/AdminGateView.vue"),
      meta: {
        noindex: true,
        title: "Page introuvable",
        description: "Cette page n'existe pas sur Riftarium."
      }
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
    },
    {
      /* Attrape-tout : toute adresse inconnue affiche la page 404 (non indexée). */
      path: "/:pathMatch(.*)*",
      component: () => import("./views/NotFoundView.vue"),
      meta: {
        noindex: true,
        title: "Page introuvable",
        description: "Cette page n'existe pas sur Riftarium."
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

/* Fréquentation anonyme : seule la rubrique est comptée, jamais l'URL complète ni la query.
   null = pas de ping (la console d'administration n'est comptée nulle part). */
function sectionOf(path) {
  if (path === "/") return "home"
  if (path.startsWith("/admin")) return null
  if (path.startsWith("/cartes/")) return "carte"
  if (path.startsWith("/cartes")) return "cartes"
  if (path.startsWith("/regles")) return "regles"
  if (path.startsWith("/decks/")) return "deck"
  if (path.startsWith("/decks")) return "decks"
  if (path.startsWith("/communaute")) return "communaute"
  if (path.startsWith("/collection")) return "collection"
  if (path.startsWith("/scan")) return "scan"
  if (path.startsWith("/profil")) return "profil"
  return "autre"
}

/* Ping best-effort : jamais bloquant, erreurs avalées, jamais en environnement de test. */
function recordVisit(path) {
  if (import.meta.env.MODE === "test") return
  const section = sectionOf(path)
  if (!section) return
  try {
    fetch("/api/metrics/hit", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "omit",
      keepalive: true,
      body: JSON.stringify({ section })
    }).catch(() => {})
  } catch {
    /* fetch indisponible : tant pis, la mesure est facultative */
  }
}

router.afterEach((to) => {
  applyRouteSeo(to)
  recordVisit(to.path)
})
