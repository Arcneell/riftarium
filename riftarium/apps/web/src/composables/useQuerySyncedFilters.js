import { computed, onBeforeUnmount, reactive, ref, unref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { csvSplit } from "../cardText.js"

/* Filtres d'une page de liste : état réactif ⇄ query string, chargement débouncé,
   compteur de filtres actifs et remise à zéro. Le schéma décrit chaque champ :

   - { kind: "text" }                → chaîne libre ("" par défaut), compte pour 1 filtre actif
   - { kind: "list", param: "set" }  → multi-valeurs sérialisées en CSV, compte pour sa longueur
                                       (`param` : nom du paramètre d'URL s'il diffère de la clé)
   - { kind: "enum", values, default, reset: false }
                                     → valeur contrôlée (tri…), hors compteur, épargnée par reset
   - { kind: "flag" }                → booléen sérialisé en "1", compte pour 1 si actif
   - { kind: "page" }                → numéro de page (≥ 1), hors compteur

   Options :
   - fetcher(state)      : requête API, retourne la donnée affectée à `result` (requis)
   - initialResult       : valeur initiale de `result`
   - pageSize            : taille de page (nombre ou ref) pour calculer `pageCount`
   - debounce            : délai du chargement débouncé (180 ms par défaut)
   - syncUrl             : false pour un état local sans synchronisation d'URL (galerie de l'éditeur)
   - enabled()           : garde appelée avant tout chargement débouncé
   - error               : ref d'erreur partagée avec la vue (créée sinon)
   - clearErrorOnLoad    : false pour ne pas effacer l'erreur au début d'un chargement
   - onLoaded(data)      : hook après affectation du résultat (restauration du scroll…) */
export function useQuerySyncedFilters(schema, options) {
  const {
    fetcher,
    initialResult = { total: 0, items: [] },
    pageSize,
    debounce = 180,
    syncUrl = true,
    enabled,
    error = ref(""),
    clearErrorOnLoad = true,
    onLoaded
  } = options

  const route = useRoute()
  const router = useRouter()
  const keys = Object.keys(schema)

  function defaultOf(field) {
    if (field.kind === "list") return []
    if (field.kind === "flag") return false
    if (field.kind === "page") return 1
    if (field.kind === "enum") return field.default
    return ""
  }

  function fromQuery(query) {
    const next = {}
    for (const key of keys) {
      const field = schema[key]
      const raw = query[field.param || key]
      if (field.kind === "list") next[key] = csvSplit(raw)
      else if (field.kind === "flag") next[key] = raw === "1"
      else if (field.kind === "page") next[key] = Math.max(1, Number(raw) || 1)
      else if (field.kind === "enum") next[key] = field.values.includes(raw) ? raw : field.default
      else next[key] = raw || ""
    }
    return next
  }

  function toQuery() {
    const query = {}
    for (const key of keys) {
      const field = schema[key]
      const param = field.param || key
      const value = state[key]
      if (field.kind === "list") {
        if (value.length) query[param] = value.join(",")
      } else if (field.kind === "flag") {
        if (value) query[param] = "1"
      } else if (field.kind === "page") {
        if (value > 1) query[param] = String(value)
      } else if (field.kind === "enum") {
        if (value !== field.default) query[param] = value
      } else if (value) {
        query[param] = value
      }
    }
    return query
  }

  const state = reactive(fromQuery(syncUrl ? route.query : {}))
  const result = ref(initialResult)
  const loading = ref(false)

  const activeCount = computed(() => {
    let count = 0
    for (const key of keys) {
      const field = schema[key]
      if (field.kind === "list") count += state[key].length
      else if (field.kind === "text" || field.kind === "flag") count += state[key] ? 1 : 0
    }
    return count
  })

  /* `pageSize` est facultatif (galerie sans pagination) : sans repli, Math.ceil(x / undefined)
     vaut NaN et la pagination affiche « page 1 sur NaN ». */
  const pageCount = computed(() => Math.max(1, Math.ceil(result.value.total / (unref(pageSize) || 1))))

  let timer = null
  /* Compteur de séquence : une réponse arrivée après une requête plus récente est ignorée. */
  let lastSeq = 0

  async function load() {
    const seq = ++lastSeq
    loading.value = true
    if (clearErrorOnLoad) error.value = ""
    try {
      const data = await fetcher(state)
      if (seq !== lastSeq) return
      result.value = data
      onLoaded?.(data)
    } catch (e) {
      if (seq !== lastSeq) return
      error.value = e.message
    } finally {
      if (seq === lastSeq) loading.value = false
    }
  }

  function scheduleLoad() {
    if (enabled && !enabled()) return
    clearTimeout(timer)
    timer = setTimeout(load, debounce)
  }

  function setFilter(key, value) {
    state[key] = value
    /* Retour page 1 seulement si le schéma déclare une page : sinon on ajouterait
       une clé `page` parasite à l'état (toQuery et signature n'itèrent que les
       clés du schéma, elle n'irait pas plus loin, mais elle mentirait). */
    if ("page" in schema) state.page = 1
  }

  function reset() {
    for (const key of keys) {
      if (schema[key].reset === false) continue
      state[key] = defaultOf(schema[key])
    }
  }

  /* Empreinte de l'état : les listes sont comparées jointes, comme dans les vues d'origine. */
  const signature = () => keys.map((key) => (schema[key].kind === "list" ? state[key].join() : state[key]))

  /* Les paramètres du schéma présents dans l'URL correspondent-ils à l'état courant ?
     Comparaison clé par clé : JSON.stringify dépend de l'ordre d'insertion, donc
     `?domain=Fury&q=x` face à `?q=x&domain=Fury` déclenchait un replace inutile
     (et une entrée d'historique de plus). Un paramètre répété arrive en tableau
     côté vue-router : on le rejoint comme le CSV de toQuery(). Les paramètres
     étrangers au schéma ne sont pas regardés, et un paramètre vide (`?q=`) vaut
     un paramètre absent : il reste dans l'URL sans déclencher de replace. */
  function sameQuery(current, wanted) {
    return keys.every((key) => {
      const param = schema[key].param || key
      const value = current[param]
      return (Array.isArray(value) ? value.join(",") : (value ?? "")) === (wanted[param] ?? "")
    })
  }

  watch(signature, () => {
    if (syncUrl) {
      const query = toQuery()
      if (!sameQuery(route.query, query)) router.replace({ query })
    }
    scheduleLoad()
  })

  if (syncUrl) {
    /* Navigation historique : l'URL redevient la source de vérité de l'état. */
    watch(
      () => route.query,
      (query) => {
        const next = fromQuery(query)
        const same = keys.every((key) =>
          schema[key].kind === "list" ? next[key].join() === state[key].join() : next[key] === state[key]
        )
        if (same) return
        Object.assign(state, next)
      }
    )
  }

  onBeforeUnmount(() => clearTimeout(timer))

  return {
    state,
    result,
    loading,
    error,
    activeCount,
    pageCount,
    fromQuery,
    toQuery,
    load,
    scheduleLoad,
    setFilter,
    reset
  }
}
