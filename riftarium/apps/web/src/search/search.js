import { api, cardThumb } from "../api.js"
import { loadRulesDocuments } from "../rules/rulesStore.js"
import { TOPICS } from "../rules/topics.js"
import { NAV } from "../shell/navigation.js"

/* Recherche universelle (Ctrl K) : cartes et decks via l'API existante, règles et
   aide via l'index local, pages via la table de navigation. Aucun endpoint dédié :
   un /api/search agrégé ne viendra que si la latence mesurée le justifie. */
export const MIN_QUERY = 2
export const GROUP_LIMIT = 5

export function normalize(text) {
  return String(text ?? "")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim()
}

const wordsOf = (query) => normalize(query).split(/\s+/).filter(Boolean)

/* Destinations hors rubriques, avec des mots-clés pour les trouver autrement que par leur nom. */
const EXTRA_PAGES = [
  { label: "Profil", to: "/profil", keywords: "compte" },
  { label: "Amis", to: "/amis", keywords: "suivis" },
  { label: "Nouveau deck", to: "/decks", keywords: "creer construire deck builder" },
  { label: "Connexion", to: "/connexion", keywords: "inscription compte se connecter" }
]

function pageEntries() {
  const entries = []
  for (const section of NAV) {
    entries.push({ label: section.label, to: section.to })
    for (const child of section.children ?? []) {
      if (child.label !== section.label) entries.push({ label: child.label, to: child.to })
    }
  }
  return [...entries, ...EXTRA_PAGES]
}

export function searchPages(query) {
  const words = wordsOf(query)
  return pageEntries()
    .filter((page) => {
      const haystack = normalize(`${page.label} ${page.keywords ?? ""}`)
      return words.every((word) => haystack.includes(word))
    })
    .slice(0, GROUP_LIMIT)
    .map((page) => ({ id: `page:${page.to}:${page.label}`, label: page.label, hint: "Page", to: page.to }))
}

/* Sujets d'aide d'abord (une page complète par mécanique), puis chaque règle officielle. */
export function buildRulesIndex(documents, topics = TOPICS) {
  const index = topics.map((topic) => ({
    id: `topic:${topic.slug}`,
    label: topic.title,
    hint: "Aide avancée",
    to: `/regles/avancee/${topic.slug}`,
    norm: normalize(`${topic.title} ${topic.summary ?? ""}`)
  }))
  for (const [key, doc] of Object.entries(documents ?? {})) {
    for (const chapter of doc.chapters ?? []) {
      for (const section of chapter.sections ?? []) {
        for (const entry of section.entries ?? []) {
          index.push({
            id: `rule:${key}:${entry.id}`,
            label: `${entry.number} ${section.title}`,
            hint: doc.title,
            to: `/regles/officielles?doc=${key}&section=${section.id}&rule=${entry.id}`,
            norm: normalize(`${section.title} ${entry.text}`)
          })
        }
      }
    }
  }
  return index
}

export function searchRules(index, query) {
  const words = wordsOf(query)
  return index
    .filter((entry) => words.every((word) => entry.norm.includes(word)))
    .slice(0, GROUP_LIMIT)
    .map(({ norm: _norm, ...item }) => item)
}

let rulesIndex = null
async function rulesIndexOnce() {
  if (!rulesIndex) rulesIndex = buildRulesIndex(await loadRulesDocuments())
  return rulesIndex
}

/** Vide l'index des règles — réservé aux tests. */
export function resetSearchCache() {
  rulesIndex = null
}

const settled = (result, map) =>
  result.status === "fulfilled" ? { items: map(result.value), error: false } : { items: [], error: true }

export async function runSearch(query, { signal } = {}) {
  const text = String(query ?? "").trim()
  if (normalize(text).length < MIN_QUERY) return []
  const encoded = encodeURIComponent(text)

  /* allSettled : un groupe en échec (pare-feu, 500) n'empêche pas les autres de s'afficher. */
  const [cards, decks, rules] = await Promise.allSettled([
    api(`/api/cards?q=${encoded}&size=${GROUP_LIMIT}`, { signal }),
    api(`/api/community/decks?q=${encoded}&size=${GROUP_LIMIT}`, { signal }),
    rulesIndexOnce().then((index) => searchRules(index, text))
  ])

  const groups = [
    {
      key: "cards",
      label: "Cartes",
      ...settled(cards, (page) =>
        (page.items ?? []).map((card) => ({
          id: `card:${card.id}`,
          label: card.name,
          hint: String(card.riftbound_id ?? "").toUpperCase(),
          to: `/cartes/${card.id}`,
          image: card.image_url ? cardThumb(card.image_url, 80) : null
        }))
      )
    },
    {
      key: "decks",
      label: "Decks de la communauté",
      ...settled(decks, (page) =>
        (page.items ?? []).map((deck) => ({
          id: `deck:${deck.id}`,
          label: deck.name,
          hint: `par ${deck.owner}`,
          to: `/decks/${deck.id}`
        }))
      )
    },
    { key: "rules", label: "Règles et aide", ...settled(rules, (items) => items) },
    { key: "pages", label: "Pages", items: searchPages(text), error: false }
  ]
  return groups.filter((group) => group.items.length || group.error)
}
