import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { useBreakpoint } from "../composables/useBreakpoint.js"
import { fold } from "../search/search.js"
import { loadRulesDocuments } from "./rulesStore.js"

/* Logique du lecteur du texte officiel (`/regles/officielles`) : chargement,
   index de recherche, localisation des renvois, navigation et lien profond
   (`?doc=&section=&rule=`, ou `?doc=&ref=<numéro>` depuis l'aide avancée). */

/* Repli des accents sur la chaîne entière : la version caractère par caractère
   bloquait le thread au montage (une décomposition NFD et une expression
   régulière par lettre, sur des dizaines de milliers de règles indexées).
   La longueur est conservée tant que la source est en NFC sans signe combinant
   (c'est le cas de rules-fr.json) : snippet() s'appuie dessus pour retrouver, dans
   le texte d'origine, une position trouvée dans le texte replié. */
export const normalize = fold
export const bare = (number) => number.replace(/\.$/, "")

const MAX_HITS = 40

function snippet(entry, tokens) {
  const folded = normalize(entry.text)
  const first =
    tokens
      .map((token) => folded.indexOf(token))
      .filter((pos) => pos >= 0)
      .sort((a, b) => a - b)[0] ?? 0
  const start = Math.max(0, first - 60)
  const slice = entry.text.slice(start, start + 190)
  return (start > 0 ? "… " : "") + slice + (start + 190 < entry.text.length ? " …" : "")
}

export function useRulesReader() {
  const route = useRoute()
  const router = useRouter()
  const breakpoint = useBreakpoint()

  const documents = ref(null)
  const error = ref("")
  const doc = ref("core")
  const sectionId = ref(null)
  const ruleId = ref(null)
  const openChapters = ref(new Set())
  const searchQuery = ref("")
  const searchHits = ref([])
  let searchIndex = []
  let locate = new Map()
  let searchTimer = null

  /* --- index de recherche et localisation des renvois --- */
  function buildIndex() {
    searchIndex = []
    locate = new Map()
    for (const [docKey, document] of Object.entries(documents.value)) {
      for (const chapter of document.chapters) {
        locate.set(`${docKey}:${bare(chapter.number)}`, { doc: docKey, section: chapter.sections[0]?.id })
        for (const section of chapter.sections) {
          locate.set(`${docKey}:${bare(section.number)}`, { doc: docKey, section: section.id })
          for (const entry of section.entries) {
            locate.set(`${docKey}:${bare(entry.number)}`, { doc: docKey, section: section.id, rule: entry.id })
            searchIndex.push({
              doc: docKey,
              docTitle: document.title,
              section: section.id,
              path: `${chapter.title} › ${section.number} ${section.title}`,
              number: entry.number,
              id: entry.id,
              text: entry.text,
              haystack: normalize(`${entry.number} ${entry.text}`)
            })
          }
        }
      }
    }
  }

  const currentDoc = computed(() => documents.value?.[doc.value])
  const sections = computed(
    () =>
      currentDoc.value?.chapters.flatMap((chapter) => chapter.sections.map((section) => ({ ...section, chapter }))) ??
      []
  )
  const currentSection = computed(() => sections.value.find((section) => section.id === sectionId.value))
  const sectionIndex = computed(() => sections.value.findIndex((section) => section.id === sectionId.value))
  const previousSection = computed(() => sections.value[sectionIndex.value - 1])
  const nextSection = computed(() => sections.value[sectionIndex.value + 1])

  function scrollToRule(rule, smooth = true) {
    requestAnimationFrame(() => {
      document
        .getElementById(`r-${rule}`)
        ?.scrollIntoView?.({ block: "center", ...(smooth ? { behavior: "smooth" } : {}) })
    })
  }

  /* Numéro de règle ou de section : d'abord le document donné, puis les autres. */
  function resolveRef(docKey, number) {
    return locate.get(`${docKey}:${number}`) ?? locate.get(`core:${number}`) ?? locate.get(`tournament:${number}`)
  }

  /* Change de section et met l'URL à jour (doc, section, rule). `smooth: false` : défilement
     instantané (chargement par lien profond). */
  function go(docKey, section, rule = null, smooth = true) {
    doc.value = docKey
    sectionId.value = section ?? sections.value[0]?.id
    ruleId.value = rule
    const chapter = currentSection.value?.chapter
    if (chapter) openChapters.value.add(chapter.id)
    router.replace({ query: { doc: docKey, section: sectionId.value, ...(rule ? { rule } : {}) } })
    const behavior = smooth ? "smooth" : "instant"
    if (rule) {
      scrollToRule(rule, smooth)
    } else if (breakpoint.value !== "desktop") {
      /* Sommaire en feuille (< 1 024 px) : on amène le lecteur sur le texte, pas en haut de page. */
      requestAnimationFrame(() => {
        document.querySelector(".officiel-text")?.scrollIntoView?.({ block: "start", behavior })
      })
    } else {
      window.scrollTo({ top: 0, behavior })
    }
  }

  function switchDoc(docKey) {
    if (docKey !== doc.value) go(docKey, documents.value[docKey].chapters[0].sections[0].id)
  }

  /* Numéro de règle ou de section : d'abord le document courant, puis les autres.
     Numéro introuvable : rien ne se passe. */
  function followRef(number) {
    const hit = resolveRef(doc.value, number)
    if (hit) go(hit.doc, hit.section, hit.rule ?? null)
  }

  /* --- recherche --- */
  function runSearch() {
    const trimmed = searchQuery.value.trim()
    if (trimmed.length < 2) {
      searchHits.value = []
      return
    }
    const tokens = normalize(trimmed).split(/\s+/).filter(Boolean)
    searchHits.value = searchIndex
      .filter((entry) => tokens.every((token) => entry.haystack.includes(token)))
      .slice(0, MAX_HITS)
      .map((entry) => ({ ...entry, snippet: snippet(entry, tokens) }))
  }

  function onSearchInput() {
    clearTimeout(searchTimer)
    searchTimer = setTimeout(runSearch, 180)
  }

  function clearSearch() {
    clearTimeout(searchTimer)
    searchQuery.value = ""
    searchHits.value = []
  }

  function pickHit(hit) {
    clearSearch()
    go(hit.doc, hit.section, hit.id)
  }

  function toggleChapter(chapterId) {
    /* `ref` enveloppe le Set dans un proxy réactif : `add` / `delete` déclenchent
       eux-mêmes le rendu, inutile de recréer le Set à chaque clic. */
    if (openChapters.value.has(chapterId)) openChapters.value.delete(chapterId)
    else openChapters.value.add(chapterId)
  }

  /* Applique l'URL à l'état de la page (montage, ou navigation sur la même page :
     un résultat de recherche globale ne remonte pas le composant).
     - `?doc=&section=&rule=` : état posé tel quel, sans router.replace ;
     - `?doc=&ref=<numéro>` (aide avancée) : le renvoi est résolu dans `doc`, puis go()
       remplace l'URL par doc / section / rule ; numéro introuvable : début du document. */
  function applyQuery(smooth) {
    const q = route.query
    const docKey = documents.value[q.doc] ? q.doc : "core"
    const chapters = documents.value[docKey].chapters
    if (typeof q.ref === "string" && q.ref) {
      doc.value = docKey
      const hit = resolveRef(docKey, q.ref)
      if (hit) go(hit.doc, hit.section, hit.rule ?? null, false)
      else go(docKey, chapters[0].sections[0].id, null, false)
      return
    }
    const wanted = chapters.flatMap((c) => c.sections).find((s) => s.id === q.section)
    const nextSectionId = wanted?.id ?? chapters[0].sections[0].id
    const nextRule = q.rule ?? null
    if (docKey === doc.value && nextSectionId === sectionId.value && nextRule === ruleId.value) return
    doc.value = docKey
    sectionId.value = nextSectionId
    ruleId.value = nextRule
    const chapter = chapters.find((c) => c.sections.some((s) => s.id === nextSectionId))
    if (chapter) openChapters.value.add(chapter.id)
    if (nextRule) scrollToRule(nextRule, smooth)
  }
  watch(
    () => [route.query.doc, route.query.section, route.query.rule, route.query.ref],
    () => {
      if (documents.value) applyQuery(true)
    }
  )

  async function load() {
    error.value = ""
    try {
      documents.value = await loadRulesDocuments()
      buildIndex()
      applyQuery(false)
    } catch {
      error.value = "Impossible de charger les règles. Réessayez dans un instant."
    }
  }

  onMounted(load)
  onBeforeUnmount(() => clearTimeout(searchTimer))

  return {
    documents,
    error,
    load,
    breakpoint,
    doc,
    sectionId,
    ruleId,
    openChapters,
    currentDoc,
    sections,
    currentSection,
    previousSection,
    nextSection,
    searchQuery,
    searchHits,
    onSearchInput,
    clearSearch,
    go,
    switchDoc,
    followRef,
    pickHit,
    toggleChapter
  }
}
