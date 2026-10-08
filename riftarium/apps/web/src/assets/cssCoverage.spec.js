// Garde-fou : toute classe statique d'un gabarit .vue doit avoir une règle CSS quelque part
// (src/styles/*.css, une autre feuille .css de src/ ou un bloc <style> de .vue). Né d'une
// régression : le nettoyage de l'ancienne feuille globale (67f7a46) avait supprimé des styles
// encore utilisés par les pages deck et profil. Cette feuille, src/assets/main.css, a disparu
// avec la refonte « Forge noxienne » : le second bloc vérifie qu'elle ne revient pas.
import { describe, it, expect } from "vitest"
import fs from "node:fs"
import path from "node:path"

// Chemins relatifs à la racine vitest (import.meta.url est une URL http sous jsdom).
const SRC = path.resolve("src")
const INDEX_HTML = path.resolve("index.html")

// Classes volontairement sans règle. Une classe qui reçoit un jour une règle, ou qui
// disparaît des gabarits, doit sortir de cette liste ; le second test le rappelle.
const UNSTYLED_ALLOWLIST = new Map([
  // Crochets de test : sélecteurs visés par une spec, sans style propre.
  ["shell", "App.vue : racine de la coquille, visée par App.spec et sw.spec"],
  ["bandeau-ok", "TraceursNotice : bouton d'acquittement visé par sa spec"],
  ["bandeau-verif", "EmailVerifyNotice : racine du bandeau visée par sa spec"],
  ["bandeau-verif-renvoi", "EmailVerifyNotice : bouton de renvoi visé par sa spec"],
  ["bandeau-horsligne", "App.vue : bandeau hors ligne visé par App.spec"],
  ["rail-label", "AppRail : libellés du rail visés par sa spec"],
  ["topbar-account", "AppTopbar : zone de compte visée par sa spec"],
  ["rift-text", "RiftText : racine visée par ses specs et celles de CardHoverPreview"],
  ["souhait-remove", "WishlistView : bouton de retrait visé par sa spec"],
  ["console-row", "Administration : lignes visées par AdminView.spec"],
  ["console-deck-name", "Administration : nom du deck visé par AdminView.spec"],
  // Modificateur de glyphe : `rb-glyph rune` (CardView) distingue une rune d'un glyphe
  // d'énergie, comme glyphKind dans RiftChip ; les specs ciblent `img.rb-glyph.rune`.
  ["rune", "marqueur de glyphe de rune, visé par les specs des filtres et de RiftText"]
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
  const cssTexts = walk(SRC)
    .filter((f) => f.endsWith(".css"))
    .map((f) => fs.readFileSync(f, "utf8"))
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
    const stale = [...UNSTYLED_ALLOWLIST.keys()].filter((c) => defined.has(c) || !used.has(c))
    expect(stale).toEqual([])
  })
})

describe("ancienne feuille globale", () => {
  it("main.css n'existe plus et n'est importé nulle part", () => {
    expect(fs.existsSync(path.join(SRC, "assets", "main.css"))).toBe(false)
    // Import JS ou CSS (`import "…/main.css"`, `@import`) et lien HTML : les commentaires
    // qui citent encore l'ancien nom ne comptent pas.
    const IMPORT_RE = /(?:import\s*(?:\(\s*)?|@import\s+(?:url\()?\s*|href=)["'][^"']*main\.css["']/
    const sources = [...walk(SRC).filter((f) => /\.(js|vue|css)$/.test(f) && !f.endsWith(".spec.js")), INDEX_HTML]
    const importers = sources.filter((f) => IMPORT_RE.test(fs.readFileSync(f, "utf8")))
    expect(importers.map((f) => path.relative(SRC, f))).toEqual([])
  })
})
