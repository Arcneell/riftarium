<script setup>
import { computed, ref } from "vue"
import { CONTACT_MAX, TRADE_ZONES, updateTradeSettings } from "../trades.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"

/* Page Échanges d'un compte non inscrit : le principe en trois lignes et
   l'activation sur place (zone + contact). Émet `enabled` avec le profil à jour. */
const emit = defineEmits(["enabled"])

const zone = ref("")
const contact = ref("")
const saving = ref(false)
const error = ref("")
const ready = computed(() => Boolean(zone.value && contact.value.trim()))

async function activate() {
  if (!ready.value || saving.value) return
  saving.value = true
  error.value = ""
  try {
    emit(
      "enabled",
      await updateTradeSettings({ trade_enabled: true, trade_zone: zone.value, trade_contact: contact.value.trim() })
    )
  } catch (e) {
    error.value = e.message
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <RiftEmpty
    title="Échangez avec les joueurs de La Réunion"
    text="Proposez vos cartes en trop et trouvez qui a celles de votre wishlist. Votre contact n'est montré qu'aux joueurs dont vous acceptez la demande."
  >
    <form class="activer" @submit.prevent="activate">
      <RiftChoice v-model="zone" label="Votre zone" :options="TRADE_ZONES" />
      <RiftField
        v-model="contact"
        label="Contact (Discord, Instagram…)"
        placeholder="Discord : pseudo"
        :maxlength="CONTACT_MAX"
      />
      <p v-if="error" class="activer-erreur" role="alert">{{ error }}</p>
      <RiftButton type="submit" :disabled="!ready || saving">Activer les échanges</RiftButton>
    </form>
  </RiftEmpty>
</template>

<style scoped>
.activer {
  display: grid;
  gap: var(--space-3);
  width: min(100%, 420px);
  margin: 0 auto;
  text-align: left;
}
.activer-erreur {
  margin: 0;
  font-size: 14px;
  color: var(--blood-text);
}
</style>
