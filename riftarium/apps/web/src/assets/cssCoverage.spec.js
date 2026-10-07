// Garde-fou : toute classe statique d'un gabarit .vue doit avoir une règle CSS quelque part
// (main.css, src/styles/*.css ou un bloc <style> de .vue). Né d'une régression : le nettoyage
// de main.css (67f7a46) avait supprimé des styles encore utilisés par les pages deck et profil.
// Variable d'environnement CSS_COVERAGE_MAIN_CSS : chemin d'un autre main.css (démonstration).
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"

// Chemin relatif à la racine vitest (import.meta.url est une URL http sous jsdom).
const SRC = path.resolve("src")
// eslint-disable-next-line no-undef
const MAIN_CSS = process.env.CSS_COVERAGE_MAIN_CSS || path.join(SRC, "assets", "main.css")

// Classes volontairement sans règle : crochets de test, états portés par un sélecteur
// composé ou un parent, marqueurs sémantiques. Une classe qui reçoit un jour une règle
// peut (et doit) sortir de cette liste ; le test ci-dessous le rappelle.
const UNSTYLED_ALLOWLIST = new Set([
  // Crochets de test : sélecteurs utilisés par les specs, sans style propre.
  "shell",
  "chart-col",
  "chart-band",
  "chart-bar",
  "chart-segment",
  "traceurs-ack",
  "rail-label",
  "topbar-account",
  "rift-text",
  "guide-fullscreen",
  "friends-panel",
  "profile-privacy",
  "rules-main",
  "souhait-remove",
  // Marqueurs de structure ou de page, sans règle à ce jour (et sans spec qui les vise).
  "classeur-tab-name",
  "footer-contact",
  "admin-wrap",
  "topic-main",
  "learn-main",
  "profile-page",
  "play-room"
])

const walk = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name)
    return e.isDirectory() ? walk(p) : [p]
  })

const stripComments = (css) => css.replace(/\/\*[\s\S]*?\*\//g, " ")
const STYLE_RE = /<style\b[^>]*>([\s\S]*?)<\/style>/g
const SCRIPT_RE = /<script\b[^>]*>[\s\S]*?<\/script>/g
const CLASS_SEL_RE = /\.(-?[_a-zA-Z][\w-]*)/g

function definedClasses(vueFiles) {
  const defined = new Set()
  const cssTexts = [fs.readFileSync(MAIN_CSS, "utf8")]
  for (const f of walk(path.join(SRC, "styles"))) if (f.endsWith(".css")) cssTexts.push(fs.readFileSync(f, "utf8"))
  for (const [, text] of vueFiles) for (const m of text.matchAll(STYLE_RE)) cssTexts.push(m[1])
  for (const css of cssTexts) for (const m of stripComments(css).matchAll(CLASS_SEL_RE)) defined.add(m[1])
  return defined
}

// Classes littérales des gabarits : class="…" hors <script>/<style>, sans les liaisons (:class)
// ni les interpolations {{ }}.
function templateClasses(text) {
  const tpl = text.replace(STYLE_RE, "").replace(SCRIPT_RE, "")
  const found = new Set()
  for (const m of tpl.matchAll(/(?<![\w:.@#-])class="([^"]*)"/g)) {
    if (m[1].includes("{{")) continue
    for (const c of m[1].split(/\s+/)) if (/^-?[_a-zA-Z][\w-]*$/.test(c)) found.add(c)
  }
  return found
}

describe("couverture CSS des classes de gabarit", () => {
  const vueFiles = walk(SRC)
    .filter((f) => f.endsWith(".vue"))
    .map((f) => [path.relative(SRC, f).replaceAll("\\", "/"), fs.readFileSync(f, "utf8")])
  const defined = definedClasses(vueFiles)

  it("chaque classe statique d'un gabarit est définie quelque part", () => {
    const missing = []
    for (const [file, text] of vueFiles)
      for (const c of templateClasses(text))
        if (!defined.has(c) && !UNSTYLED_ALLOWLIST.has(c)) missing.push(`${file} : .${c}`)
    expect(missing).toEqual([])
  })

  it("la liste d'exceptions ne contient que des classes encore sans règle et encore utilisées", () => {
    const used = new Set(vueFiles.flatMap(([, text]) => [...templateClasses(text)]))
    const stale = [...UNSTYLED_ALLOWLIST].filter((c) => defined.has(c) || !used.has(c))
    expect(stale).toEqual([])
  })
})
