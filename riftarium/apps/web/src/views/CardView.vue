<script setup>
import { computed, ref, watch } from "vue"
import { useRoute, useRouter } from "vue-router"
import { api, cardThumb, session, DOMAINS, TYPES, RARITIES } from "../api.js"
import { glyphUrl, isFoil, powerRuneGlyphs, variantLabel } from "../cardText.js"
import CardText from "../components/CardText.vue"

const route = useRoute()
const router = useRouter()
const card = ref(null)
const error = ref("")
const qty = ref(0)
const saved = ref("")

const foil = computed(() => isFoil(card.value))
const variants = computed(() => card.value?.variants || [])
const landscape = computed(() => card.value?.orientation === "landscape")
const domainLabel = computed(() => card.value?.domains?.map((d) => DOMAINS[d]?.label || d).join(" / ") || "—")
const domainColor = computed(() => DOMAINS[card.value?.domains?.[0]]?.color)
const energySrc = computed(() =>
  card.value?.energy === null || card.value?.energy === undefined ? "" : glyphUrl(`energy_${card.value.energy}`)
)
const powerRunes = computed(() => powerRuneGlyphs(card.value))
const mightSrc = glyphUrl("might")

watch(
  () => route.params.id,
  async (id) => {
    card.value = null
    error.value = ""
    saved.value = ""
    try {
      card.value = await api(`/api/cards/${id}`)
      qty.value = card.value.owned_qty ?? 0
    } catch (e) {
      error.value = e.message
    }
  },
  { immediate: true }
)

async function addToCollection() {
  saved.value = ""
  try {
    const response = await api(`/api/collection/${card.value.id}`, {
      method: "PUT",
      body: { qty: qty.value }
    })
    saved.value = `C'est noté : ${response.qty} exemplaire(s).`
    card.value.owned_qty = response.qty
  } catch (e) {
    error.value = e.message
  }
}

function openVariant(id) {
  if (id !== card.value?.id) router.push(`/cartes/${id}`)
}
</script>

<template>
  <section class="card-detail">
    <div class="wrap cards-wrap">
      <p class="card-back"><RouterLink to="/cartes">← Cartothèque</RouterLink></p>
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

          <div class="panel sheet-collection" v-if="session.token">
            <h3>Dans ma collection</h3>
            <div class="sheet-qty">
              <input type="number" min="0" max="999" v-model.number="qty" aria-label="Quantité possédée" />
              <button class="btn btn-gold btn-sm" @click="addToCollection">Enregistrer</button>
              <span v-if="saved" class="success">{{ saved }}</span>
            </div>
          </div>
          <p v-else class="muted sheet-login">
            <RouterLink to="/connexion">Connectez-vous</RouterLink> pour suivre vos exemplaires.
          </p>
        </div>
      </article>
    </div>
  </section>
</template>
