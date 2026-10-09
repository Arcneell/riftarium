<script setup>
import { computed, ref, watch } from "vue"
import { session } from "../api.js"
import TradeInterestDialog from "../trades/TradeInterestDialog.vue"
import TradeOfferLine from "../trades/TradeOfferLine.vue"
import { ensureTradeSettings, getCardOffers, tradeSettings } from "../trades.js"
import RiftButton from "../ui/RiftButton.vue"

/* Bloc « À l'échange » de la fiche carte : qui la propose, dont combien dans
   ma zone, et « Ça m'intéresse ». Rien pour un visiteur ; une invitation
   pour un compte qui n'a pas activé les échanges. */
const props = defineProps({
  card: { type: Object, required: true }
})

const data = ref(null)
const error = ref("")
const interest = ref(null)

const summary = computed(() => {
  const { total, in_my_zone: mine } = data.value
  const players = total > 1 ? `${total} joueurs la proposent` : "1 joueur la propose"
  return mine ? `${players}, dont ${mine} dans votre zone` : players
})

async function load() {
  data.value = null
  error.value = ""
  if (!session.token) return
  await ensureTradeSettings()
  if (!tradeSettings.enabled) return
  const cardId = props.card.id
  try {
    const result = await getCardOffers(cardId)
    if (cardId === props.card.id) data.value = result
  } catch (e) {
    error.value = e.message
  }
}

function onSent(request) {
  interest.value.offer.pending_request_id = request.id
  interest.value = null
}

watch(() => [props.card.id, session.token], load, { immediate: true })
</script>

<template>
  <section v-if="session.token && tradeSettings.loaded" class="echange-fiche" aria-labelledby="echange-fiche-titre">
    <h2 id="echange-fiche-titre" class="echange-fiche-titre">À l'échange</h2>
    <p v-if="!tradeSettings.enabled" class="echange-fiche-texte">
      Activez les échanges pour voir qui la propose à La Réunion.
      <RiftButton to="/echanges" variant="ghost" size="sm">Activer les échanges</RiftButton>
    </p>
    <p v-else-if="error" class="echange-fiche-erreur" role="alert">{{ error }}</p>
    <template v-else-if="data">
      <p v-if="!data.total" class="echange-fiche-texte">Personne ne la propose pour l'instant.</p>
      <template v-else>
        <p class="echange-fiche-texte">{{ summary }}.</p>
        <ul class="echange-fiche-offres">
          <TradeOfferLine
            v-for="offer in data.offers"
            :key="offer.offer_id"
            :offer="offer"
            @interest="interest = { offer }"
          />
        </ul>
      </template>
    </template>
    <TradeInterestDialog v-if="interest" :card="card" :offer="interest.offer" @close="interest = null" @sent="onSent" />
  </section>
</template>

<style scoped>
.echange-fiche {
  display: grid;
  gap: var(--space-2);
  padding-top: var(--space-3);
  border-top: 1px solid var(--line);
}
.echange-fiche-titre {
  margin: 0;
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink);
}
.echange-fiche-texte {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
  margin: 0;
  color: var(--ink-muted);
  font-size: 14px;
}
.echange-fiche-erreur {
  margin: 0;
  font-size: 14px;
  color: var(--blood-text);
}
.echange-fiche-offres {
  margin: 0;
  padding: 0;
  list-style: none;
}
</style>
