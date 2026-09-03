import { BANNERS } from "./banners.js"
import { CLOSED_BETA } from "./legal.js"

const SITE_ORIGIN = "https://riftarium.re"
export const SITE_NAME = "Riftarium"
export const DEFAULT_TITLE = "Riftarium — Cartes, decks et règles Riftbound"
export const DEFAULT_DESCRIPTION =
  "Bêta fermée. Cartothèque, deck builder, règles officielles et collection pour Riftbound. Site fan-made gratuit, en français, non affilié à Riot Games."

function origin() {
  if (typeof window !== "undefined" && /^https?:/.test(window.location.origin)) return window.location.origin
  return SITE_ORIGIN
}

export function pageUrl(path = "/") {
  const suffix = path.startsWith("/") ? path : `/${path}`
  return `${origin().replace(/\/$/, "")}${suffix === "/" ? "/" : suffix}`
}

function upsertMeta(attr, key, value) {
  if (!value) return
  let el = document.head.querySelector(`meta[${attr}="${key}"]`)
  if (!el) {
    el = document.createElement("meta")
    el.setAttribute(attr, key)
    document.head.appendChild(el)
  }
  el.setAttribute("content", value)
}

function upsertLink(rel, href, extras = {}) {
  const extraSel = extras.hreflang ? `[hreflang="${extras.hreflang}"]` : ""
  let el = document.head.querySelector(`link[rel="${rel}"]${extraSel}`)
  if (!el) {
    el = document.createElement("link")
    el.setAttribute("rel", rel)
    for (const [name, val] of Object.entries(extras)) el.setAttribute(name, val)
    document.head.appendChild(el)
  }
  el.setAttribute("href", href)
}

export function applySeo({ title, description, path = "/", noindex = false, image } = {}) {
  const fullTitle = !title ? DEFAULT_TITLE : title.includes(SITE_NAME) ? title : `${title} · ${SITE_NAME}`
  const desc = description || DEFAULT_DESCRIPTION
  const url = pageUrl(path)
  const img = image || BANNERS.home

  document.title = fullTitle
  upsertMeta("name", "description", desc)
  upsertMeta("name", "robots", noindex || CLOSED_BETA ? "noindex, nofollow" : "index, follow")
  upsertMeta("property", "og:title", fullTitle)
  upsertMeta("property", "og:description", desc)
  upsertMeta("property", "og:url", url)
  upsertMeta("property", "og:image", img)
  upsertMeta("property", "og:type", "website")
  upsertMeta("property", "og:locale", "fr_FR")
  upsertMeta("property", "og:site_name", SITE_NAME)
  upsertMeta("name", "twitter:card", "summary_large_image")
  upsertMeta("name", "twitter:title", fullTitle)
  upsertMeta("name", "twitter:description", desc)
  upsertMeta("name", "twitter:image", img)
  upsertLink("canonical", url)
  upsertLink("alternate", url, { hreflang: "fr" })
}

export function applyRouteSeo(route) {
  applySeo({
    title: route.meta.title,
    description: route.meta.description,
    path: route.path,
    noindex: Boolean(route.meta.noindex)
  })
}
