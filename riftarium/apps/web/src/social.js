import { api } from "./api.js"

/* Profils publics, hauts faits et amis : appels de l'API `/api/users`,
   `/api/me/achievements`, `/api/me/follows` et mise en forme partagée par les
   pages Profil public, Amis et Mon profil.
   Contrat : docs/profils-et-hauts-faits.md — source de vérité API / mobile / web. */

/* Le pseudo arrive de l'URL ou d'une saisie : encodé avant d'entrer dans le chemin. */
const userPath = (handle, suffix = "") => `/api/users/${encodeURIComponent(handle)}${suffix}`

/** Adresse du profil public d'un joueur — le seul endroit qui écrit `/u/`. */
export function profilePath(handle) {
  return `/u/${encodeURIComponent(handle || "")}`
}

/* ---------- Profils publics (lecture, connecté ou non) ---------- */

/** `PublicProfileOut` : identité, visibilité, et sections nulles si masquées. 404 si inconnu. */
export function getPublicProfile(handle) {
  return api(userPath(handle))
}

/* L'API plafonne la taille de page comme ailleurs : on borne ici plutôt que de laisser passer un 422. */
function pageParams(page, size, max = 50) {
  return new URLSearchParams({
    page: String(Math.max(1, Number(page) || 1)),
    size: String(Math.min(max, Math.max(1, Number(size) || 20)))
  })
}

/** Collection publique : `{total, page, size, items: [{card, total_qty}]}`. 403 si masquée. */
export function getUserCollection(handle, { q = "", setId = "", page = 1, size = 24 } = {}) {
  const params = pageParams(page, size, 60)
  if (q) params.set("q", q)
  if (setId) params.set("set_id", setId)
  return api(userPath(handle, `/collection?${params}`))
}

/** Historique public : mêmes `HistoryItem` que `/api/play/history`, du point de vue du profil. */
export function getUserHistory(handle, page = 1, size = 20) {
  return api(userPath(handle, `/history?${pageParams(page, size)}`))
}

/** Jusqu'à 10 comptes dont le pseudo commence par `q` (≥ 2 caractères côté API). */
export function searchUsers(q) {
  return api(`/api/users/search?q=${encodeURIComponent(q)}`)
}

/* ---------- Amis (compte connecté) ---------- */

/** `{following: [...], followers: [...]}`. */
export function getFollows() {
  return api("/api/me/follows")
}

export function followUser(handle) {
  return api(userPath(handle, "/follow"), { method: "PUT" })
}

export function unfollowUser(handle) {
  return api(userPath(handle, "/follow"), { method: "DELETE" })
}

/* ---------- Hauts faits et confidentialité (compte connecté) ---------- */

/** Tout le catalogue, débloqué ou non, avec `current` / `threshold` / `unlocked_at`. */
export function getMyAchievements() {
  return api("/api/me/achievements")
}

/** Enregistre un ou plusieurs réglages de confidentialité. Renvoie le `user_out` à jour. */
export function updatePrivacy(patch) {
  return api("/api/auth/me", { method: "PATCH", body: patch })
}

/* Les quatre réglages du contrat, dans l'ordre d'affichage. Tout est masqué par
   défaut côté API sauf les decks et les hauts faits : le libellé dit ce qui
   devient visible, jamais ce qui est « autorisé ». */
export const PRIVACY_TOGGLES = [
  {
    key: "show_achievements",
    label: "Mes hauts faits",
    hint: "Les médailles débloquées apparaissent sur votre profil public."
  },
  {
    key: "show_stats",
    label: "Mes statistiques de duels",
    hint: "Bilan des parties suivies, meilleures légendes et historique."
  },
  {
    key: "show_collection",
    label: "Ma collection",
    hint: "Progression par set et cartes possédées, sans les prix ni les états."
  },
  {
    key: "show_decks",
    label: "Mes decks publics",
    hint: "La liste sur le profil. Un deck public reste accessible par son lien dans tous les cas."
  }
]

/* ---------- Mise en forme ---------- */

/* Quatre paliers, du plus commun au plus rare. Le prisme reprend le dégradé du site. */
const TIERS = { bronze: "Bronze", silver: "Argent", gold: "Or", prism: "Prisme" }

export function tierLabel(tier) {
  return TIERS[tier] || TIERS.bronze
}

const FAMILIES = { duels: "Duels", collection: "Collection", decks: "Decks", social: "Communauté" }
/* Ordre d'affichage des familles ; une famille inconnue passe à la fin. */
const FAMILY_ORDER = Object.keys(FAMILIES)

export function familyLabel(family) {
  return FAMILIES[family] || "Autres"
}

/* Le contrat fournit un nom d'icône Material, partagé avec l'application mobile.
   Le site n'embarque pas de police d'icônes (CSP stricte, aucune dépendance) et
   son composant Icon.vue ne couvre que la navigation : on rend un glyphe sobre,
   la médaille colorée par le palier portant l'essentiel de l'information. */
const GLYPHS = {
  directions_run: "🏃",
  hexagon: "⬡",
  inventory_2: "🗃️",
  emoji_events: "🏆",
  military_tech: "🎖",
  workspace_premium: "🏅",
  star: "★",
  stars: "★",
  local_fire_department: "🔥",
  bolt: "⚡",
  shield: "🛡",
  swords: "⚔",
  sports_martial_arts: "⚔",
  collections: "🗂",
  collections_bookmark: "🗂",
  style: "🃏",
  auto_awesome: "✦",
  diamond: "◆",
  groups: "👥",
  group: "👥",
  person_add: "👥",
  calendar_month: "📅",
  event_repeat: "📅",
  favorite: "♥",
  verified: "✓",
  gavel: "⚖",
  balance: "⚖",
  architecture: "📐",
  public: "🌍",
  trending_up: "📈"
}

export function achievementGlyph(icon) {
  return GLYPHS[icon] || "🏅"
}

/** Un haut fait est acquis dès que l'API a daté son déblocage. */
export function isUnlocked(item) {
  return Boolean(item?.unlocked_at)
}

/** Avancement en pourcentage (0 → 100), borné. 100 dès le déblocage. */
export function achievementPercent(item) {
  if (isUnlocked(item)) return 100
  const threshold = Number(item?.threshold) || 0
  if (threshold <= 0) return 0
  const current = Math.max(0, Number(item?.current) || 0)
  return Math.round(Math.min(1, current / threshold) * 100)
}

/** « 3 / 10 » — la progression chiffrée sous la médaille. */
export function achievementProgress(item) {
  const current = Math.max(0, Number(item?.current) || 0)
  const threshold = Number(item?.threshold) || 0
  return `${Math.min(current, threshold || current)} / ${threshold}`
}

const DATE_FORMAT = new Intl.DateTimeFormat("fr-FR", { day: "numeric", month: "long", year: "numeric" })
const MONTH_FORMAT = new Intl.DateTimeFormat("fr-FR", { month: "long", year: "numeric" })

function parseDate(iso) {
  if (!iso) return null
  const date = new Date(iso)
  return Number.isNaN(date.getTime()) ? null : date
}

/** « janvier 2026 » — chaîne vide si la date manque ou est illisible. */
export function formatMemberSince(iso) {
  const date = parseDate(iso)
  return date ? MONTH_FORMAT.format(date) : ""
}

/** « 12 août 2026 » — date de déblocage d'un haut fait. */
export function formatUnlockedAt(iso) {
  const date = parseDate(iso)
  return date ? DATE_FORMAT.format(date) : ""
}

/* Les débloqués d'abord (du plus récent au plus ancien), puis les autres du plus
   proche du seuil au plus lointain : ce qui est acquis se voit, ce qui vient
   ensuite se devine. */
function byProgress(a, b) {
  const unlockedA = isUnlocked(a)
  const unlockedB = isUnlocked(b)
  if (unlockedA !== unlockedB) return unlockedA ? -1 : 1
  if (unlockedA) return String(b.unlocked_at).localeCompare(String(a.unlocked_at))
  return achievementPercent(b) - achievementPercent(a)
}

/** Regroupe le catalogue par famille : `[{family, label, items, unlocked, total}]`. */
export function groupAchievements(list) {
  const groups = new Map()
  for (const item of list || []) {
    const family = item?.family || "other"
    if (!groups.has(family)) groups.set(family, [])
    groups.get(family).push(item)
  }
  const rank = (family) => {
    const index = FAMILY_ORDER.indexOf(family)
    return index === -1 ? FAMILY_ORDER.length : index
  }
  return [...groups.entries()]
    .sort(([a], [b]) => rank(a) - rank(b) || a.localeCompare(b))
    .map(([family, items]) => ({
      family,
      label: familyLabel(family),
      items: [...items].sort(byProgress),
      unlocked: items.filter(isUnlocked).length,
      total: items.length
    }))
}

/** Les hauts faits acquis, du plus récent au plus ancien — vue publique. */
export function unlockedFirst(list) {
  return [...(list || [])].sort(byProgress)
}

/** Part possédée d'un set, en pourcentage borné — barres du résumé de collection. */
export function setPercent(row) {
  const total = Number(row?.total) || 0
  if (total <= 0) return 0
  return Math.round(Math.min(1, Math.max(0, (Number(row?.owned) || 0) / total)) * 100)
}
