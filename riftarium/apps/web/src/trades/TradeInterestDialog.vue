<script setup>
import { computed, ref } from "vue"
import { defaultsLabel } from "../collection/collectionDefaults.js"
import { MESSAGE_MAX, sendRequest, zoneLabel } from "../trades.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftModal from "../ui/RiftModal.vue"

/* « Je suis intéressé » : rappel de la carte et du joueur, message optionnel,
   envoi. Une erreur reste dans la modale sans effacer le message saisi. */
const props = defineProps({
  card: { type: Object, required: true },
  offer: { type: Object, required: true }
})
const emit = defineEmits(["close", "sent"])

const message = ref("")
const sending = ref(false)
const error = ref("")
const remaining = computed(() => MESSAGE_MAX - message.value.length)

async function submit() {
  if (sending.value) return
  sending.value = true
  error.value = ""
  try {
    const request = await sendRequest(props.offer.offer_id, message.value)
    emit("sent", request)
  } catch (e) {
    error.value = e.message
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <RiftModal title="Demande d'échange" @close="emit('close')">
    <p class="interet-rappel">
      <b>{{ card.name }}</b> ({{ defaultsLabel(offer) }}) proposée par <b>{{ offer.owner.handle }}</b
      >, zone {{ zoneLabel(offer.owner.zone) }}.
    </p>
    <p class="interet-aide">
      {{ offer.owner.handle }} sera prévenu par e-mail. S'il accepte, chacun verra le contact de l'autre pour convenir
      de l'échange.
    </p>
    <label class="interet-champ">
      <span class="interet-label">Message (facultatif)</span>
      <textarea
        v-model="message"
        class="interet-message"
        rows="4"
        :maxlength="MESSAGE_MAX"
        placeholder="Ce que vous proposez en retour, vos disponibilités…"
      ></textarea>
      <span class="interet-compteur" aria-live="polite">{{ remaining }} caractères restants</span>
    </label>
    <p v-if="error" class="interet-erreur" role="alert">{{ error }}</p>
    <div class="interet-actions">
      <RiftButton variant="ghost" @click="emit('close')">Annuler</RiftButton>
      <RiftButton :disabled="sending" @click="submit">Envoyer la demande</RiftButton>
    </div>
  </RiftModal>
</template>

<style scoped>
.interet-rappel,
.interet-aide {
  margin: 0 0 var(--space-3);
}
.interet-aide {
  font-size: 14px;
  color: var(--ink-muted);
}
.interet-champ {
  display: grid;
  gap: var(--space-1);
}
.interet-label {
  font-family: var(--font-label);
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.interet-message {
  width: 100%;
  padding: var(--space-2);
  resize: vertical;
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  color: var(--ink);
  font: inherit;
}
.interet-compteur {
  font-size: 13px;
  color: var(--ink-muted);
}
.interet-erreur {
  margin: var(--space-3) 0 0;
  font-size: 14px;
  color: var(--blood-text);
}
.interet-actions {
  display: flex;
  justify-content: flex-end;
  gap: var(--space-2);
  margin-top: var(--space-4);
}
</style>
