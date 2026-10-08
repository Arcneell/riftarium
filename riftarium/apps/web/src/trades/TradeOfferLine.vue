<script setup>
import { computed } from "vue"
import UserAvatar from "../components/UserAvatar.vue"
import { defaultsLabel } from "../collection/collectionDefaults.js"
import { profilePath } from "../social.js"
import { zoneLabel } from "../trades.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChip from "../ui/RiftChip.vue"

/* Une offre d'un autre joueur (OfferOut du contrat) : qui, où, quel lot, et
   « Je suis intéressé ». Partagée par la page Échanges et la fiche carte ; la
   demande elle-même est envoyée par le parent (TradeInterestDialog). */
const props = defineProps({
  offer: { type: Object, required: true }
})
const emit = defineEmits(["interest"])

const lot = computed(() => defaultsLabel(props.offer))
</script>

<template>
  <li class="offre">
    <RouterLink :to="profilePath(offer.owner.handle)" class="offre-joueur">
      <UserAvatar :src="offer.owner.avatar_url || ''" :handle="offer.owner.handle" :size="32" />
      <span class="offre-pseudo">{{ offer.owner.handle }}</span>
    </RouterLink>
    <RiftChip static :label="zoneLabel(offer.owner.zone)" />
    <span class="offre-lot">{{ lot }} · ×{{ offer.qty }}</span>
    <span v-if="offer.mutual" class="offre-mutuel" title="Ce joueur cherche aussi une carte que vous proposez">
      Échange possible
    </span>
    <span v-if="offer.pending_request_id" class="offre-envoyee" role="status">Demande envoyée</span>
    <RiftButton v-else size="sm" variant="secondary" class="offre-action" @click="emit('interest', offer)">
      Je suis intéressé
    </RiftButton>
  </li>
</template>

<style scoped>
.offre {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2) var(--space-3);
  padding: var(--space-2) 0;
  border-top: 1px solid var(--line);
}
.offre-joueur {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 44px;
  color: var(--ink);
}
.offre-pseudo {
  font-weight: 600;
}
.offre-lot {
  font-size: 14px;
  color: var(--ink-muted);
}
.offre-mutuel {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.offre-envoyee {
  margin-left: auto;
  font-size: 14px;
  color: var(--ink-muted);
}
.offre-action {
  margin-left: auto;
}
</style>
