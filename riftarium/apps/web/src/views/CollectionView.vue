<script setup>
import { onMounted, ref } from "vue";
import { api, cardThumb } from "../api.js";

const collection = ref({ total_cards: 0, unique_cards: 0, items: [] });
const error = ref("");

async function load() {
  try {
    collection.value = await api("/api/collection");
  } catch (e) {
    error.value = e.message;
  }
}

async function setQty(item, delta) {
  const qty = Math.max(0, item.qty + delta);
  try {
    await api(`/api/collection/${item.card.id}`, {
      method: "PUT",
      body: { qty, condition: item.condition, lang: item.lang }
    });
    await load();
  } catch (e) {
    error.value = e.message;
  }
}

onMounted(load);
</script>

<template>
  <div class="page-banner"
       style="--banner: url('https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/2282ecab240f601b611ae89b5ade895e1b6b2de4-4676x2630.jpg?auto=format&w=1600')">
    <div class="wrap">
      <p class="eyebrow">Collection</p>
      <h2>Mon inventaire</h2>
      <p class="lead">Vos cartes, leurs états, leurs langues. L'estimation Cardmarket et le scan arrivent.</p>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </div>

  <section style="padding-top:40px">
    <div class="wrap">
      <div class="stat-row">
        <div class="stat" v-reveal>Cartes<b>{{ collection.total_cards }}</b></div>
        <div class="stat" v-reveal="1">Uniques<b>{{ collection.unique_cards }}</b></div>
        <div class="stat" v-reveal="2">Valeur estimée<b>—</b></div>
      </div>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="panel" v-if="collection.items.length" v-reveal>
        <table>
          <thead><tr><th></th><th>Carte</th><th>Code</th><th>Qté</th><th>État</th><th>Langue</th><th></th></tr></thead>
          <tbody>
            <tr v-for="item in collection.items" :key="item.card.id">
              <td style="width:52px"><img class="row-thumb" :src="cardThumb(item.card.image_url, 84)" :alt="''" loading="lazy" decoding="async" /></td>
              <td><RouterLink :to="`/cartes/${item.card.id}`">{{ item.card.name }}</RouterLink></td>
              <td class="num">{{ item.card.riftbound_id.toUpperCase() }}</td>
              <td class="num">{{ item.qty }}</td>
              <td>{{ item.condition }}</td>
              <td>{{ item.lang }}</td>
              <td style="white-space:nowrap">
                <button class="btn btn-ghost btn-sm" @click="setQty(item, 1)" aria-label="Ajouter un exemplaire">+</button>
                <button class="btn btn-ghost btn-sm" @click="setQty(item, -1)" aria-label="Retirer un exemplaire">−</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-else class="muted">
        Collection vide. Ouvrez une <RouterLink to="/cartes">fiche carte</RouterLink> et notez combien d'exemplaires vous possédez.
      </p>
    </div>
  </section>
</template>
