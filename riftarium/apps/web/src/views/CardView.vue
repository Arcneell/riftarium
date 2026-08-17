<script setup>
import { ref, watch } from "vue"
import { useRoute } from "vue-router"
import { api, cardThumb, session, DOMAINS, TYPES, RARITIES } from "../api.js"

const route = useRoute()
const card = ref(null)
const error = ref("")
const qty = ref(1)
const saved = ref("")

watch(
  () => route.params.id,
  async (id) => {
    card.value = null
    error.value = ""
    saved.value = ""
    try {
      card.value = await api(`/api/cards/${id}`)
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
  } catch (e) {
    error.value = e.message
  }
}
</script>

<template>
  <section style="padding-top: 44px">
    <div class="wrap">
      <p style="margin-bottom: 26px"><RouterLink to="/cartes">← Cartothèque</RouterLink></p>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="card-sheet" v-if="card">
        <div>
          <img
            v-tilt
            class="full"
            :class="{ landscape: card.orientation === 'landscape' }"
            :src="cardThumb(card.image_url, 720)"
            :alt="`Carte Riftbound : ${card.name}`"
          />
          <p class="card-credit">
            {{ card.riftbound_id.toUpperCase() }} · Illustration : {{ card.artist }} · © Riot Games
          </p>
        </div>

        <div>
          <p class="eyebrow">{{ card.set_id }} · {{ RARITIES[card.rarity] || card.rarity }}</p>
          <h1>{{ card.name }}</h1>

          <div class="stat-row">
            <div class="stat">
              Type<b>{{ TYPES[card.type] || card.type }}</b>
            </div>
            <div class="stat">
              Domaine<b :style="{ color: DOMAINS[card.domains?.[0]]?.color }">
                {{ card.domains?.map((d) => DOMAINS[d]?.label || d).join(" / ") || "—" }}</b
              >
            </div>
            <div class="stat" v-if="card.energy !== null">
              Énergie<b>{{ card.energy }}</b>
            </div>
            <div class="stat" v-if="card.might !== null">
              Puissance<b>{{ card.might }}</b>
            </div>
            <div class="stat" v-if="card.power !== null">
              Pouvoir<b>{{ card.power }}</b>
            </div>
          </div>

          <div class="rules-text" v-if="card.text">
            <p>{{ card.text }}</p>
            <p class="muted" style="font-size: 0.8rem; margin-top: 10px">
              Texte anglais (VO). Le français viendra avec l'API Riot.
            </p>
          </div>
          <p class="muted" v-if="card.flavour" style="font-style: italic; margin: 14px 0">« {{ card.flavour }} »</p>

          <div class="panel" style="margin-top: 28px" v-if="session.token">
            <h3 style="margin-bottom: 14px">Dans ma collection</h3>
            <div style="display: flex; gap: 14px; align-items: center; flex-wrap: wrap">
              <input
                type="number"
                min="0"
                max="999"
                v-model.number="qty"
                style="width: 100px"
                aria-label="Quantité possédée"
              />
              <button class="btn btn-gold btn-sm" @click="addToCollection">Enregistrer</button>
              <span v-if="saved" class="success">{{ saved }}</span>
            </div>
          </div>
          <p v-else class="muted" style="margin-top: 28px">
            <RouterLink to="/connexion">Connectez-vous</RouterLink> pour suivre vos exemplaires.
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
