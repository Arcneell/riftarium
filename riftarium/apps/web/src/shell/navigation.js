/* Table unique de la navigation : le rail, la barre d'onglets mobile, les sous-onglets,
   le fil d'Ariane et la recherche universelle (groupe « Pages ») la lisent tous.
   `prefixes` : chemins qui appartiennent à la rubrique (correspondance exacte ou
   suivie de « / », pour que /cartesX ne soit pas pris pour /cartes). */
export const NAV = [
  { key: "home", label: "Accueil", to: "/", icon: "home", prefixes: [] },
  { key: "cards", label: "Cartes", to: "/cartes", icon: "cards", prefixes: ["/cartes"] },
  {
    key: "decks",
    label: "Decks",
    to: "/decks",
    icon: "decks",
    prefixes: ["/decks", "/communaute"],
    children: [
      { label: "Mes decks", to: "/decks" },
      { label: "Communauté", to: "/communaute" }
    ]
  },
  {
    key: "collection",
    label: "Collection",
    to: "/collection",
    icon: "collection",
    prefixes: ["/collection", "/wishlist", "/echanges"],
    /* `badge` : compteur affiché par le rail (demandes d'échange reçues en attente). */
    badge: "trades",
    children: [
      { label: "Collection", to: "/collection" },
      { label: "Wishlist", to: "/wishlist" },
      { label: "Échanges", to: "/echanges", badge: "trades" }
    ]
  },
  {
    key: "rules",
    label: "Règles",
    to: "/regles",
    icon: "rules",
    prefixes: ["/regles"],
    children: [
      { label: "Apprendre", to: "/regles/debutant" },
      { label: "Plateau animé", to: "/regles/debutant/plateau" },
      { label: "Aide avancée", to: "/regles/avancee" },
      { label: "Texte officiel", to: "/regles/officielles" }
    ]
  },
  {
    key: "play",
    label: "Jouer",
    to: "/salon",
    icon: "play",
    prefixes: ["/salon", "/historique", "/statistiques"],
    children: [
      { label: "Salon", to: "/salon" },
      { label: "Historique", to: "/historique" },
      { label: "Statistiques", to: "/statistiques" }
    ]
  }
]

/* Téléphone : cinq onglets, les mêmes que l'app Flutter. Jouer passe par l'avatar. */
export const TABBAR_KEYS = ["home", "cards", "decks", "collection", "rules"]

export const ACCOUNT_LINKS = [
  { label: "Profil", to: "/profil" },
  { label: "Amis", to: "/amis" }
]

const within = (path, prefix) => path === prefix || path.startsWith(`${prefix}/`)

export function activeSection(path) {
  if (path === "/") return NAV[0]
  return NAV.find((section) => section.prefixes.some((prefix) => within(path, prefix))) ?? null
}

export function activeChild(section, path) {
  if (!section?.children) return null
  const matches = section.children.filter((child) => within(path, child.to))
  return matches.sort((a, b) => b.to.length - a.to.length)[0] ?? null
}

/* Rubrique › sous-page › maillon de la page (nom d'une carte, d'un deck…). */
export function breadcrumbOf(path, pageCrumb = null) {
  const crumbs = []
  const section = activeSection(path)
  if (section) {
    crumbs.push({ label: section.label, to: section.to })
    const child = activeChild(section, path)
    /* /decks/:id : le deck peut être celui d'un autre, pas de maillon « Mes decks ». */
    const foreignDeck = child?.to === "/decks" && path !== "/decks"
    if (child && !foreignDeck && child.label !== section.label) crumbs.push({ label: child.label, to: child.to })
  }
  if (pageCrumb) crumbs.push({ label: pageCrumb })
  return crumbs
}
