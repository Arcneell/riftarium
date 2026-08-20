<script setup>
import { computed, reactive, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, cardThumb, session, CONDITIONS, DOMAINS, LANGS, TYPES, RARITIES } from "../api.js"
import { glyphUrl, isFoil, powerRuneGlyphs, variantLabel } from "../cardText.js"
import { PRICE_SOURCE_NOTE, cardmarketUrl, formatEur, usePricesMeta } from "../prices.js"
import { applySeo } from "../seo.js"
import CardText from "../components/CardText.vue"

const route = useRoute()
const router = useRouter()
const card = ref(null)
const error = ref("")
const entries = ref([]) // lots possédés : [{ id, qty, condition, lang }]
const draft = reactive({ qty: 1, condition: "NM", lang: "EN" })
const busy = ref(false)
const saved = ref("")

const totalOwned = computed(() => entries.value.reduce((total, entry) => total + entry.qty, 0))

/* Retour contextuel : revient à la collection (ou à la liste filtrée) telle qu'on l'a quittée. */
const backLink = computed(() => {
  void route.fullPath // history.state n'est pas réactif : on réévalue à chaque navigation
  const back = window.history.state?.back
  if (typeof back === "string" && back.startsWith("/collection")) return { label: "Ma collection", useBack: true }
  return { label: "Cartothèque", useBack: typeof back === "string" && back.startsWith("/cartes") }
})

const foil = computed(() => isFoil(card.value))
const variants = computed(() => card.value?.variants || [])
const landscape = computed(() => card.value?.orientation === "landscape")
const domainLabel = computed(() => card.value?.domains?.map((d) => DOMAINS[d]?.label || d).join(" / ") || "—")
const domainColor = computed(() => DOMAINS[card.value?.domains?.[0]]?.text)
const energySrc = computed(() =>
  card.value?.energy === null || card.value?.energy === undefined ? "" : glyphUrl(`energy_${card.value.energy}`)
)
const powerRunes = computed(() => powerRuneGlyphs(card.value))
const mightSrc = glyphUrl("might")

/* Prix indicatif : rien n'est affiché tant que la carte n'a pas de prix. */
const pricesMeta = usePricesMeta()
const priceMain = computed(() => formatEur(card.value?.price_eur))
/* Cartes n'existant qu'en foil : le prix principal EST le prix foil, inutile de doubler. */
const priceFoil = computed(() =>
  card.value?.price_foil_eur !== card.value?.price_eur ? formatEur(card.value?.price_foil_eur) : null
)

watch(
  () => route.params.id,
  async (id) => {
    /* Transition sortante : l'id devient undefined, pas de requête parasite GET /api/cards/undefined. */
    if (!id) return
    card.value = null
    error.value = ""
    saved.value = ""
    try {
      card.value = await api(`/api/cards/${id}`)
      entries.value = []
      if (session.token) {
        const owned = await api(`/api/collection/${card.value.id}`)
        entries.value = owned.entries
      }
      applySeo({
        title: `${card.value.name} — Carte Riftbound`,
        description: `${card.value.name} (${card.value.set_id}) : ${TYPES[card.value.type] || card.value.type} Riftbound. Fiche, visuel officiel et variantes sur Riftarium.`,
        path: route.path,
        image: card.value.image_url
      })
    } catch (e) {
      error.value = e.message
    }
  },
  { immediate: true }
)

function applyState(state, message) {
  entries.value = state.entries
  card.value.owned_qty = state.total_qty
  saved.value = message
}

async function mutate(request, message) {
  if (busy.value) return
  busy.value = true
  saved.value = ""
  error.value = ""
  try {
    applyState(await request(), message)
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = false
  }
}

function addEntry() {
  mutate(
    () =>
      api(`/api/collection/${card.value.id}/entries`, {
        method: "POST",
        body: { qty: draft.qty, condition: draft.condition, lang: draft.lang }
      }),
    "Lot ajouté."
  ).then(() => {
    draft.qty = 1
  })
}

function saveEntry(entry) {
  mutate(
    () =>
      api(`/api/collection/entries/${entry.id}`, {
        method: "PATCH",
        body: { qty: entry.qty, condition: entry.condition, lang: entry.lang }
      }),
    "Lot mis à jour."
  )
}

function removeEntry(entry) {
  mutate(() => api(`/api/collection/entries/${entry.id}`, { method: "PATCH", body: { qty: 0 } }), "Lot retiré.")
}

/* Wishlist : un seul clic bascule « je la veux » (qty 1) / retrait complet.
   La quantité fine se règle ensuite sur la page Ma wishlist. */
const wished = computed(() => (card.value?.wished_qty ?? 0) > 0)
const wishBusy = ref(false)

async function toggleWish() {
  if (wishBusy.value || !card.value) return
  wishBusy.value = true
  error.value = ""
  try {
    if (wished.value) {
      await api(`/api/wishlist/${card.value.id}`, { method: "DELETE" })
      card.value.wished_qty = 0
    } else {
      await api(`/api/wishlist/${card.value.id}`, { method: "PUT", body: { qty: 1 } })
      card.value.wished_qty = 1
    }
  } catch (e) {
    error.value = e.message
  } finally {
    wishBusy.value = false
  }
}

/* replace : passer d'une variante à l'autre ne pollue pas l'historique, le retour ramène à la liste. */
function openVariant(id) {
  if (id !== card.value?.id) router.replace(`/cartes/${id}`)
}
</script>

<template>
  <section class="card-detail">
    <div class="wrap cards-wrap">
      <p class="card-back">
        <a v-if="backLink.useBack" href="#" @click.prevent="router.back()">← {{ backLink.label }}</a>
        <RouterLink v-else to="/cartes">← Cartothèque</RouterLink>
      </p>
      <p v-if="error" class="error">{{ error }}</p>

      <article v-if="card" class="card-sheet" :class="{ landscape }">
        <aside class="sheet-visual">
          <div v-tilt class="card-art sheet-art" :class="{ foil, landscape }">
            <img
              class="full"
              :src="cardThumb(card.image_url, landscape ? 1100 : 720)"
              :alt="`Carte Riftbound : ${card.name}`"
            />
            <span v-if="foil" class="card-foil"></span>
          </div>
          <div class="variant-switch" v-if="variants.length > 1">
            <button
              v-for="item in variants"
              :key="item.id"
              class="filter"
              :aria-pressed="item.id === card.id"
              @click="openVariant(item.id)"
            >
              {{ variantLabel(item) }}
            </button>
          </div>
          <p class="card-credit">
            {{ card.riftbound_id.toUpperCase() }}
            <span v-if="card.artist"> · Illustration : {{ card.artist }}</span>
            · © Riot Games
          </p>
        </aside>

        <div class="sheet-copy">
          <p class="eyebrow">
            {{ card.set_id }} · {{ RARITIES[card.rarity] || card.rarity }}
            <span v-if="landscape"> · Terrain</span>
          </p>
          <h1>{{ card.name }}</h1>

          <div class="sheet-tags">
            <span class="sheet-tag">{{ TYPES[card.type] || card.type }}</span>
            <span v-if="card.supertype" class="sheet-tag muted">{{ card.supertype }}</span>
            <span class="sheet-tag" :style="{ color: domainColor }">{{ domainLabel }}</span>
          </div>

          <button
            v-if="session.token"
            type="button"
            class="wish-toggle"
            :class="{ on: wished }"
            :aria-pressed="wished"
            :disabled="wishBusy"
            @click="toggleWish"
          >
            <Icon :name="wished ? 'heart' : 'heart-line'" :size="15" />
            {{ wished ? "Dans ma wishlist" : "Ajouter à la wishlist" }}
          </button>

          <div class="stat-row">
            <div class="stat" v-if="card.energy !== null && card.energy !== undefined">
              Énergie
              <b class="stat-glyphs">
                <img
                  class="rb-glyph energy"
                  :src="energySrc"
                  :alt="`Énergie ${card.energy}`"
                  :title="`Énergie ${card.energy}`"
                />
              </b>
            </div>
            <div class="stat" v-if="card.might !== null && card.might !== undefined">
              Puissance
              <b class="stat-glyphs">
                <span
                  class="rb-glyph ink"
                  :style="{ '--glyph': `url(${mightSrc})` }"
                  role="img"
                  aria-label="Puissance"
                  title="Puissance"
                ></span>
                {{ card.might }}
              </b>
            </div>
            <div class="stat" v-if="powerRunes.length">
              Pouvoir
              <b class="stat-glyphs">
                <img
                  v-for="(rune, i) in powerRunes"
                  :key="i"
                  class="rb-glyph rune"
                  :src="rune.src"
                  :alt="rune.label"
                  :title="rune.label"
                />
              </b>
            </div>
          </div>

          <div class="rules-text" v-if="card.text">
            <CardText :text="card.text" />
          </div>
          <p class="flavour" v-if="card.flavour">« {{ card.flavour }} »</p>

          <div class="price-block" v-if="priceMain">
            <p class="eyebrow">Prix indicatif</p>
            <p class="price-line">
              <b class="price-amount">{{ priceMain }}</b>
              <span v-if="priceFoil" class="price-foil">foil : {{ priceFoil }}</span>
            </p>
            <p class="price-note">
              {{ pricesMeta.currency_note || PRICE_SOURCE_NOTE
              }}<template v-if="pricesMeta.updated_day"> Mise à jour : {{ pricesMeta.updated_day }}.</template>
              Ni cote officielle ni offre d'achat.
            </p>
            <a class="price-link" :href="cardmarketUrl(card.name)" target="_blank" rel="noopener">
              Voir sur Cardmarket ↗
            </a>
          </div>

          <div class="panel sheet-collection" v-if="session.token">
            <h3>
              Dans ma collection
              <span v-if="totalOwned" class="muted">— {{ totalOwned }} exemplaire(s)</span>
            </h3>

            <div v-for="entry in entries" :key="entry.id" class="sheet-qty sheet-entry">
              <input
                type="number"
                min="0"
                max="999"
                v-model.number="entry.qty"
                :aria-label="`Quantité du lot ${entry.condition} ${entry.lang}`"
              />
              <select v-model="entry.condition" aria-label="État du lot">
                <option v-for="(label, code) in CONDITIONS" :key="code" :value="code">{{ code }} · {{ label }}</option>
              </select>
              <select v-model="entry.lang" aria-label="Langue du lot">
                <option v-for="(label, code) in LANGS" :key="code" :value="code">{{ code }} · {{ label }}</option>
              </select>
              <button class="btn btn-gold btn-sm" :disabled="busy" @click="saveEntry(entry)">Enregistrer</button>
              <button class="btn btn-ghost btn-sm" :disabled="busy" @click="removeEntry(entry)">Retirer</button>
            </div>
            <p v-if="!entries.length" class="muted">Aucun exemplaire pour l'instant.</p>

            <div class="sheet-qty sheet-entry sheet-add">
              <input type="number" min="1" max="999" v-model.number="draft.qty" aria-label="Quantité à ajouter" />
              <select v-model="draft.condition" aria-label="État du nouveau lot">
                <option v-for="(label, code) in CONDITIONS" :key="code" :value="code">{{ code }} · {{ label }}</option>
              </select>
              <select v-model="draft.lang" aria-label="Langue du nouveau lot">
                <option v-for="(label, code) in LANGS" :key="code" :value="code">{{ code }} · {{ label }}</option>
              </select>
              <button class="btn btn-ghost btn-sm" :disabled="busy || !draft.qty" @click="addEntry">
                + Ajouter un lot
              </button>
            </div>

            <p v-if="saved" class="success">{{ saved }}</p>
          </div>
          <p v-else class="muted sheet-login">
            <RouterLink to="/connexion">Connectez-vous</RouterLink> pour suivre vos exemplaires.
          </p>
        </div>
      </article>
    </div>
  </section>
</template>
