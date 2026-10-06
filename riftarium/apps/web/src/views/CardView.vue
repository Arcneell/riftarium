<script setup>
import { computed, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, cardThumb, DOMAINS, TYPES, RARITIES } from "../api.js"
import CardCollectionPanel from "../cards/CardCollectionPanel.vue"
import { DOMAIN_RUNE, glyphUrl, isFoil, powerRuneGlyphs, variantLabel } from "../cardText.js"
import { PRICE_SOURCE_NOTE, cardmarketUrl, formatEur, usePricesMeta } from "../prices.js"
import { applySeo } from "../seo.js"
import { setPageCrumb } from "../shell/pageCrumb.js"
import RiftChip from "../ui/RiftChip.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftStat from "../ui/RiftStat.vue"
import RiftText from "../ui/RiftText.vue"

const route = useRoute()
const router = useRouter()
const card = ref(null)
const error = ref("")

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
const domainLabel = computed(() => card.value?.domains?.map((d) => DOMAINS[d]?.label || d).join(" / ") || "")
const runeGlyph = computed(() => glyphUrl(`rune_${DOMAIN_RUNE[card.value?.domains?.[0]] || "rainbow"}`))
const kicker = computed(() =>
  [TYPES[card.value?.type] || card.value?.type, domainLabel.value].filter(Boolean).join(" · ")
)
const hasEnergy = computed(() => card.value?.energy !== null && card.value?.energy !== undefined)
const hasMight = computed(() => card.value?.might !== null && card.value?.might !== undefined)
const powerRunes = computed(() => powerRuneGlyphs(card.value))
const mightSrc = glyphUrl("might")

/* Prix indicatif : rien n'est affiché tant que la carte n'a pas de prix. */
const pricesMeta = usePricesMeta()
const priceMain = computed(() => formatEur(card.value?.price_eur))
/* Cartes n'existant qu'en foil : le prix principal EST le prix foil, inutile de doubler. */
const priceFoil = computed(() =>
  card.value?.price_foil_eur !== card.value?.price_eur ? formatEur(card.value?.price_foil_eur) : null
)

/* Jeton de séquence : deux navigations rapprochées (variantes, retour arrière)
   lancent deux chargements ; seul le dernier a le droit d'écrire dans l'état. */
let seq = 0

watch(
  () => route.params.id,
  async (id) => {
    /* Transition sortante : l'id devient undefined, pas de requête parasite GET /api/cards/undefined. */
    if (!id) return
    const mine = ++seq
    card.value = null
    error.value = ""
    try {
      const loaded = await api(`/api/cards/${id}`)
      if (mine !== seq) return
      card.value = loaded
      setPageCrumb(loaded.name)
      applySeo({
        title: `${loaded.name} — Carte Riftbound`,
        description: `${loaded.name} (${loaded.set_id}) : ${TYPES[loaded.type] || loaded.type} Riftbound. Fiche, visuel officiel et variantes sur Riftarium.`,
        path: route.path,
        image: loaded.image_url
      })
    } catch (e) {
      if (mine === seq) error.value = e.message
    }
  },
  { immediate: true }
)

/* Le panneau de collection ne modifie pas la carte : il émet le changement, appliqué ici. */
function onCollectionChange(patch) {
  if (card.value) Object.assign(card.value, patch)
}

/* replace : passer d'une variante à l'autre ne pollue pas l'historique, le retour ramène à la liste. */
function openVariant(id) {
  if (id !== card.value?.id) router.replace(`/cartes/${id}`)
}
</script>

<template>
  <section class="fiche-page">
    <div class="fiche-wrap">
      <p class="fiche-back">
        <!-- Un retour d'historique est une action, pas une adresse : un bouton, pas un `href="#"`. -->
        <button v-if="backLink.useBack" type="button" class="fiche-back-link" @click="router.back()">
          ← {{ backLink.label }}
        </button>
        <RouterLink v-else class="fiche-back-link" to="/cartes">← Cartothèque</RouterLink>
      </p>
      <p v-if="error" class="fiche-error" role="alert">{{ error }}</p>

      <article v-if="card" class="fiche" :class="{ landscape }">
        <div class="fiche-visual">
          <div class="fiche-art" :class="{ landscape }" tabindex="-1">
            <img :src="cardThumb(card.image_url, landscape ? 1100 : 720)" :alt="`Carte Riftbound : ${card.name}`" />
            <span v-if="foil" class="fiche-foil" aria-hidden="true"></span>
          </div>

          <div v-if="variants.length > 1" class="fiche-variants" role="group" aria-label="Variantes">
            <RiftChip
              v-for="item in variants"
              :key="item.id"
              :label="variantLabel(item)"
              :selected="item.id === card.id"
              @toggle="openVariant(item.id)"
            />
          </div>

          <div v-if="priceMain" class="fiche-price">
            <p class="fiche-price-title">Prix indicatif</p>
            <p class="fiche-price-line">
              <b class="fiche-price-amount">{{ priceMain }}</b>
              <span v-if="priceFoil" class="fiche-price-foil">foil : {{ priceFoil }}</span>
            </p>
            <p class="fiche-price-note">
              {{ pricesMeta.currency_note || PRICE_SOURCE_NOTE
              }}<template v-if="pricesMeta.updated_day"> Mise à jour : {{ pricesMeta.updated_day }}.</template>
              Ni cote officielle ni offre d'achat.
            </p>
            <a class="fiche-price-link" :href="cardmarketUrl(card.name)" target="_blank" rel="noopener">
              Voir sur Cardmarket ↗
            </a>
          </div>

          <CardCollectionPanel :card="card" @change="onCollectionChange" />

          <p class="fiche-credit">
            {{ (card.riftbound_id || "").toUpperCase() }}
            <span v-if="card.artist"> · Illustration : {{ card.artist }}</span>
            · © Riot Games
          </p>
        </div>

        <div class="fiche-copy">
          <p class="fiche-kicker">
            <img class="rb-glyph rune" :src="runeGlyph" alt="" width="20" height="20" />
            <span>{{ kicker }}</span>
          </p>
          <h1 class="fiche-title">{{ card.name }}</h1>

          <div v-if="hasEnergy || hasMight || powerRunes.length" class="fiche-stats">
            <RiftStat
              v-if="hasEnergy"
              label="Énergie"
              :glyph="glyphUrl(`energy_${card.energy}`)"
              :glyph-alt="`${card.energy} énergie`"
              glyph-kind="energy"
            />
            <RiftStat v-if="hasMight" label="Puissance" :value="card.might" :glyph="mightSrc" ink />
            <RiftStat v-if="powerRunes.length" label="Pouvoir">
              <img
                v-for="(rune, i) in powerRunes"
                :key="i"
                class="rb-glyph rune"
                :src="rune.src"
                :alt="rune.label"
                :title="rune.label"
                width="26"
                height="26"
              />
            </RiftStat>
          </div>

          <RiftPanel v-if="card.text" title="Capacité">
            <RiftText tag="p" class="card-text" :text="card.text" />
          </RiftPanel>

          <p v-if="card.flavour" class="fiche-flavour">« {{ card.flavour }} »</p>

          <dl class="fiche-meta">
            <div>
              <dt>Set</dt>
              <dd>{{ card.set_id }}</dd>
            </div>
            <div>
              <dt>Numéro</dt>
              <dd>{{ (card.riftbound_id || "").toUpperCase() }}</dd>
            </div>
            <div>
              <dt>Rareté</dt>
              <dd>{{ RARITIES[card.rarity] || card.rarity }}</dd>
            </div>
            <div v-if="card.artist">
              <dt>Illustration</dt>
              <dd>{{ card.artist }}</dd>
            </div>
          </dl>
        </div>
      </article>
    </div>
  </section>
</template>

<style scoped>
/* La règle globale `section { padding: 88px 0 }` de l'ancien style ne doit pas s'appliquer ici. */
.fiche-page {
  padding: var(--space-5) 0 var(--space-7);
}
.fiche-wrap {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 var(--space-4);
}
.fiche-back {
  margin: 0 0 var(--space-4);
}
.fiche-back-link {
  padding: 0;
  border: 0;
  background: none;
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bronze-light);
  cursor: pointer;
}
.fiche-back-link:hover {
  color: var(--ink);
}
.fiche-error {
  color: var(--blood-text);
}
.fiche {
  display: grid;
  grid-template-columns: minmax(280px, 400px) minmax(0, 1fr);
  gap: var(--space-6);
  align-items: start;
}
.fiche.landscape {
  grid-template-columns: minmax(0, 1fr);
}
.fiche-visual,
.fiche-copy {
  display: grid;
  gap: var(--space-4);
  min-width: 0;
}
.fiche.landscape .fiche-visual {
  max-width: 720px;
}
.fiche-art {
  position: relative;
  overflow: hidden;
  border-radius: var(--radius-card);
}
.fiche-art img {
  display: block;
  width: 100%;
  height: auto;
}
.fiche-foil {
  position: absolute;
  inset: 0;
  background: linear-gradient(115deg, transparent 30%, rgba(255, 236, 200, 0.35) 48%, transparent 66%);
  background-size: 250% 100%;
  background-position: 120% 0;
  mix-blend-mode: screen;
  pointer-events: none;
  opacity: 0;
  transition:
    opacity var(--t-base),
    background-position 900ms ease;
}
.fiche-art:hover .fiche-foil,
.fiche-art:focus-within .fiche-foil {
  opacity: 1;
  background-position: -60% 0;
}
.fiche-variants {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
.fiche-price {
  display: grid;
  gap: var(--space-1);
  padding: var(--space-3) var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.fiche-price p {
  margin: 0;
}
.fiche-price-title {
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.fiche-price-line {
  display: flex;
  align-items: baseline;
  gap: var(--space-3);
}
.fiche-price-amount {
  font-family: var(--font-display);
  font-size: 26px;
  color: var(--bronze-light);
}
.fiche-price-foil {
  font-family: var(--font-label);
  font-size: 14px;
  color: var(--ink-muted);
}
.fiche-price-note {
  font-size: 12px;
  color: var(--ink-muted);
}
.fiche-price-link {
  justify-self: start;
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.fiche-credit {
  margin: 0;
  font-size: 12px;
  color: var(--ink-muted);
}
.fiche-kicker {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin: 0;
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
/* Neutralise le h1 doré animé hérité de l'ancien style global. */
.fiche-title {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(2rem, 4.4vw, 3rem);
  font-weight: 700;
  line-height: 1.1;
  background: none;
  color: var(--ink);
  animation: none;
}
.fiche-stats {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-3);
}
.fiche-flavour {
  margin: 0;
  font-style: italic;
  color: var(--ink-muted);
}
.fiche-meta {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: var(--space-3);
  margin: 0;
}
.fiche-meta dt {
  font-family: var(--font-label);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.fiche-meta dd {
  margin: 0;
  color: var(--ink);
}
@media (max-width: 900px) {
  .fiche {
    grid-template-columns: minmax(0, 1fr);
  }
  .fiche-visual {
    max-width: 400px;
  }
}
@media (prefers-reduced-motion: reduce) {
  .fiche-foil {
    display: none;
  }
}
</style>
