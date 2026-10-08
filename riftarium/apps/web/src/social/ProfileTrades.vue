<script setup>
import { reactive, ref, watch } from "vue"
import { CONTACT_MAX, TRADE_ZONES, updateTradeSettings } from "../trades.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftField from "../ui/RiftField.vue"
import RiftPanel from "../ui/RiftPanel.vue"

/* Réglages d'échange du profil : inscription, zone, contact et e-mails.
   Le contact n'est montré qu'aux joueurs dont on accepte la demande. Émet
   `saved` avec le `user_out` à jour ; une erreur garde la saisie. */
const props = defineProps({
  profile: { type: Object, required: true }
})
const emit = defineEmits(["saved"])

const form = reactive({ enabled: false, zone: "", contact: "", notify: true })
const saving = ref(false)
const error = ref("")
const ok = ref("")

watch(
  () => props.profile,
  (profile) => {
    form.enabled = Boolean(profile.trade_enabled)
    form.zone = profile.trade_zone || ""
    form.contact = profile.trade_contact || ""
    form.notify = profile.notify_trades !== false
  },
  { immediate: true }
)

async function save() {
  if (saving.value) return
  saving.value = true
  error.value = ""
  ok.value = ""
  try {
    const patch = { trade_enabled: form.enabled, trade_contact: form.contact.trim(), notify_trades: form.notify }
    if (form.zone) patch.trade_zone = form.zone
    emit("saved", await updateTradeSettings(patch))
    ok.value = "Réglages d'échange enregistrés"
  } catch (e) {
    error.value = e.message
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <RiftPanel title="Échanges" accent="var(--bronze)">
    <p class="echanges-intro">
      Proposez vos cartes aux joueurs de La Réunion et retrouvez ceux qui ont celles de votre wishlist (<RouterLink
        to="/echanges"
        >page Échanges</RouterLink
      >).
    </p>
    <form class="echanges-form" @submit.prevent="save">
      <label class="echanges-case">
        <input v-model="form.enabled" type="checkbox" name="trade_enabled" />
        <span>Participer aux échanges</span>
      </label>
      <p v-if="profile.trade_enabled && !form.enabled" class="echanges-alerte" role="status">
        Désactiver annule vos demandes en attente (reçues et envoyées) et masque vos offres. Les échanges déjà acceptés
        restent visibles.
      </p>
      <RiftChoice v-model="form.zone" label="Ma zone" :options="TRADE_ZONES" />
      <RiftField
        v-model="form.contact"
        label="Contact (Discord, Instagram…)"
        placeholder="Discord : pseudo"
        :maxlength="CONTACT_MAX"
      />
      <p class="echanges-aide">Visible seulement par les joueurs dont vous acceptez la demande.</p>
      <label class="echanges-case">
        <input v-model="form.notify" type="checkbox" name="notify_trades" />
        <span>Me prévenir par e-mail des demandes reçues et acceptées</span>
      </label>
      <p v-if="error" class="echanges-erreur" role="alert">{{ error }}</p>
      <p v-else-if="ok" class="echanges-succes" role="status">{{ ok }}</p>
      <RiftButton variant="secondary" :disabled="saving" @click="save">Enregistrer</RiftButton>
    </form>
  </RiftPanel>
</template>

<style scoped>
.echanges-intro {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
}
.echanges-form {
  display: grid;
  gap: var(--space-3);
  justify-items: start;
}
.echanges-form :deep(.rift-field) {
  width: min(100%, 420px);
}
.echanges-case {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  min-height: 44px;
  color: var(--ink);
  cursor: pointer;
}
.echanges-aide {
  margin: calc(-1 * var(--space-2)) 0 0;
  font-size: 14px;
  color: var(--ink-muted);
}
.echanges-erreur,
.echanges-succes {
  margin: 0;
  font-size: 14px;
}
.echanges-erreur {
  color: var(--blood-text);
}
.echanges-alerte {
  margin: 0;
  padding-left: var(--space-3);
  border-left: 2px solid var(--blood);
  font-size: 14px;
  color: var(--ink);
}
.echanges-succes {
  color: var(--bronze-light);
}
</style>
