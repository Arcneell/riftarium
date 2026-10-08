<script setup>
import { onMounted, ref, watch } from "vue"
import UserAvatar from "../components/UserAvatar.vue"
import { profilePath } from "../social.js"
import { getOffered, getWanted, zoneLabel } from "../trades.js"
import CardTile from "../ui/CardTile.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import TradeInterestDialog from "./TradeInterestDialog.vue"
import TradeOfferLine from "./TradeOfferLine.vue"

/* Correspondances : « Ils ont ce que je cherche » (ma wishlist × les offres des
   autres), puis « Ils cherchent ce que j'ai » en simple information. */
const props = defineProps({
  zone: { type: String, required: true }
})

const SIZE = 24
const wanted = ref({ items: [], total: 0 })
const offered = ref({ items: [], total: 0 })
const page = ref(1)
const loading = ref(true)
const error = ref("")
const onlyMyZone = ref(false)
const query = ref("")
/* Offre visée par « Je suis intéressé » : { card, offer } ou null. */
const interest = ref(null)

async function load() {
  loading.value = true
  error.value = ""
  const zone = onlyMyZone.value ? props.zone : ""
  try {
    const [found, seekers] = await Promise.all([
      getWanted({ zone, q: query.value.trim(), page: page.value, size: SIZE }),
      getOffered({ zone })
    ])
    wanted.value = found
    offered.value = seekers
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

/* Recherche : 300 ms après la dernière frappe, retour en première page. */
let timer = null
watch(query, () => {
  clearTimeout(timer)
  timer = setTimeout(() => {
    page.value = 1
    load()
  }, 300)
})
watch(onlyMyZone, () => {
  page.value = 1
  load()
})

function goTo(next) {
  page.value = next
  load()
}

/* Demande envoyée : l'offre affiche « Demande envoyée » sans recharger la liste. */
function onSent(request) {
  const { offer } = interest.value
  offer.pending_request_id = request.id
  interest.value = null
}

onMounted(load)
</script>

<template>
  <div class="correspondances">
    <div class="correspondances-filtres">
      <RiftField v-model="query" label="Chercher une carte" hide-label search placeholder="Nom de carte" />
      <RiftChip
        :label="`Zone ${zoneLabel(zone)} seulement`"
        :selected="onlyMyZone"
        @toggle="onlyMyZone = !onlyMyZone"
      />
    </div>

    <p v-if="error" class="correspondances-erreur" role="alert">{{ error }}</p>

    <section aria-labelledby="ils-ont">
      <h2 id="ils-ont" class="correspondances-titre">Ils ont ce que je cherche</h2>
      <div v-if="loading" class="correspondances-grille">
        <RiftSkeleton v-for="n in 4" :key="n" block />
      </div>
      <ul v-else-if="wanted.items.length" class="correspondances-grille">
        <li v-for="block in wanted.items" :key="block.card.id" class="correspondance">
          <RouterLink :to="`/cartes/${block.card.id}`" class="correspondance-carte">
            <CardTile :card="block.card" :preview="false" />
          </RouterLink>
          <ul class="correspondance-offres">
            <TradeOfferLine
              v-for="offer in block.offers"
              :key="offer.offer_id"
              :offer="offer"
              @interest="interest = { card: block.card, offer }"
            />
          </ul>
        </li>
      </ul>
      <RiftEmpty
        v-else-if="!error"
        title="Aucune correspondance pour l'instant"
        text="Ajoutez des cartes à votre wishlist : dès qu'un joueur les propose, elles apparaissent ici."
      >
        <RiftButton to="/wishlist" variant="secondary">Ma wishlist</RiftButton>
      </RiftEmpty>
      <nav v-if="wanted.total > SIZE" class="correspondances-pages" aria-label="Pages des correspondances">
        <RiftButton variant="ghost" size="sm" :disabled="page <= 1 || loading" @click="goTo(page - 1)"
          >Précédentes</RiftButton
        >
        <span class="correspondances-page">Page {{ page }} / {{ Math.ceil(wanted.total / SIZE) }}</span>
        <RiftButton variant="ghost" size="sm" :disabled="page * SIZE >= wanted.total || loading" @click="goTo(page + 1)"
          >Suivantes</RiftButton
        >
      </nav>
    </section>

    <section v-if="!loading && offered.items.length" aria-labelledby="ils-cherchent">
      <h2 id="ils-cherchent" class="correspondances-titre">Ils cherchent ce que j'ai</h2>
      <p class="correspondances-aide">
        Ces joueurs ont dans leur wishlist une carte que vous proposez. Jetez un œil à leurs offres : c'est peut-être
        l'occasion d'un échange.
      </p>
      <ul class="chercheurs">
        <li v-for="item in offered.items" :key="item.user.handle" class="chercheur">
          <RouterLink :to="profilePath(item.user.handle)" class="chercheur-joueur">
            <UserAvatar :src="item.user.avatar_url || ''" :handle="item.user.handle" :size="32" />
            <span>{{ item.user.handle }}</span>
          </RouterLink>
          <RiftChip static :label="zoneLabel(item.user.zone)" />
          <span class="chercheur-cartes">{{ item.cards.map((card) => card.name).join(", ") }}</span>
        </li>
      </ul>
    </section>

    <TradeInterestDialog
      v-if="interest"
      :card="interest.card"
      :offer="interest.offer"
      @close="interest = null"
      @sent="onSent"
    />
  </div>
</template>

<style scoped>
.correspondances {
  display: grid;
  gap: var(--space-5);
}
.correspondances-filtres {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-3);
}
.correspondances-filtres :deep(.rift-field) {
  flex: 1 1 240px;
}
.correspondances-erreur {
  margin: 0;
  font-size: 14px;
  color: var(--blood-text);
}
.correspondances-titre {
  margin: 0 0 var(--space-3);
  font-size: 1.2rem;
}
.correspondances-aide {
  margin: 0 0 var(--space-3);
  color: var(--ink-muted);
}
.correspondances-grille {
  display: grid;
  gap: var(--space-4);
  margin: 0;
  padding: 0;
  list-style: none;
}
.correspondances-grille :deep(.rift-skeleton-block) {
  height: 160px;
}
.correspondance {
  display: grid;
  grid-template-columns: 140px 1fr;
  gap: var(--space-4);
  align-items: start;
  padding: var(--space-3);
  background: var(--bg-raised);
  border: 1px solid var(--line);
}
.correspondance-carte {
  display: block;
}
.correspondance-offres {
  margin: 0;
  padding: 0;
  list-style: none;
}
.correspondances-pages {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: var(--space-3);
  margin-top: var(--space-4);
}
.correspondances-page {
  font-size: 14px;
  color: var(--ink-muted);
}
.chercheurs {
  margin: 0;
  padding: 0;
  list-style: none;
}
.chercheur {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2) var(--space-3);
  padding: var(--space-2) 0;
  border-top: 1px solid var(--line);
}
.chercheur-joueur {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 44px;
  color: var(--ink);
  font-weight: 600;
}
.chercheur-cartes {
  font-size: 14px;
  color: var(--ink-muted);
}
@media (max-width: 599px) {
  .correspondance {
    grid-template-columns: 96px 1fr;
    gap: var(--space-3);
  }
}
</style>
