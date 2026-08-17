<script setup>
import { onMounted, ref } from "vue";
import { api } from "../api.js";

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
  <section>
    <div class="wrap">
      <p class="eyebrow">Collection</p>
      <h2>Mon inventaire</h2>

      <div class="stat-row">
        <div class="stat">Cartes possédées<b>{{ collection.total_cards }}</b></div>
        <div class="stat">Cartes uniques<b>{{ collection.unique_cards }}</b></div>
        <div class="stat">Valeur estimée<b>— €</b></div>
      </div>
      <p class="muted" style="font-size:.8rem; margin-bottom:22px">
        L'estimation Cardmarket et le scan mobile arrivent dans une prochaine version.
        Ajoutez des cartes depuis leur fiche dans la <RouterLink to="/cartes">cartothèque</RouterLink>.
      </p>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="panel" v-if="collection.items.length">
        <table>
          <thead><tr><th>Carte</th><th>Set</th><th>Qté</th><th>État</th><th>Langue</th><th></th></tr></thead>
          <tbody>
            <tr v-for="item in collection.items" :key="item.card.id">
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
      <p v-else class="muted">Collection vide pour l'instant — parcourez la <RouterLink to="/cartes">cartothèque</RouterLink> pour commencer.</p>
    </div>
  </section>
</template>
