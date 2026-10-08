<script setup>
import { reactive } from "vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftField from "../ui/RiftField.vue"
import RiftPanel from "../ui/RiftPanel.vue"

/* E-mail (avec le rappel de vérification) et mot de passe. Chaque formulaire garde
   sa saisie et ses messages ; le réseau reste dans la page, par trois fonctions :
   - `saveEmail(body)` : lève en cas de refus ;
   - `savePassword(body)` : idem ;
   - `resendVerification()` : renvoie `true` si l'e-mail est parti, `false` si
     l'adresse était déjà vérifiée (la page met alors le profil à jour), lève sinon. */
const props = defineProps({
  email: { type: String, default: "" },
  /* Vrai seulement quand l'API dit l'adresse non vérifiée (champ absent = rien à rappeler). */
  unverified: { type: Boolean, default: false },
  saveEmail: { type: Function, required: true },
  savePassword: { type: Function, required: true },
  resendVerification: { type: Function, required: true }
})

const account = reactive({ email: props.email, password: "", saving: false, error: "", ok: "" })
const verification = reactive({ sending: false, ok: "", error: "" })
const secret = reactive({ current: "", next: "", confirm: "", saving: false, error: "", ok: "" })

async function submitEmail() {
  if (account.saving) return
  account.saving = true
  account.error = ""
  account.ok = ""
  try {
    const saved = await props.saveEmail({ email: account.email, current_password: account.password })
    if (saved?.email) account.email = saved.email
    account.password = ""
    account.ok = "Email mis à jour — un e-mail de vérification a été envoyé à la nouvelle adresse."
  } catch (e) {
    account.error = e.message
  } finally {
    account.saving = false
  }
}

async function resend() {
  if (verification.sending) return
  verification.sending = true
  verification.ok = ""
  verification.error = ""
  try {
    if (await props.resendVerification()) {
      verification.ok = "E-mail de vérification renvoyé. Pensez à vérifier vos indésirables."
    }
  } catch (e) {
    verification.error = e.message
  } finally {
    verification.sending = false
  }
}

async function submitPassword() {
  if (secret.saving) return
  if (secret.next !== secret.confirm) {
    secret.error = "Les mots de passe ne correspondent pas"
    secret.ok = ""
    return
  }
  secret.saving = true
  secret.error = ""
  secret.ok = ""
  try {
    await props.savePassword({ current_password: secret.current, new_password: secret.next })
    secret.current = ""
    secret.next = ""
    secret.confirm = ""
    secret.ok = "Mot de passe mis à jour"
  } catch (e) {
    secret.error = e.message
  } finally {
    secret.saving = false
  }
}
</script>

<template>
  <RiftPanel tag="form" title="Email" accent="var(--bronze)" class="compte-form" @submit.prevent="submitEmail">
    <div v-if="unverified" class="compte-verif">
      <p class="compte-intro">Adresse e-mail non vérifiée.</p>
      <RiftButton variant="secondary" size="sm" :disabled="verification.sending" @click="resend">
        {{ verification.sending ? "Envoi…" : "Renvoyer l'e-mail" }}
      </RiftButton>
      <p v-if="verification.ok" class="compte-succes" role="status">{{ verification.ok }}</p>
      <p v-if="verification.error" class="compte-erreur" role="alert">{{ verification.error }}</p>
    </div>
    <RiftField v-model="account.email" label="Adresse" type="email" name="email" autocomplete="email" required />
    <RiftField
      v-model="account.password"
      label="Mot de passe actuel"
      type="password"
      name="email-password"
      autocomplete="current-password"
      required
    />
    <p v-if="account.error" class="compte-erreur" role="alert">{{ account.error }}</p>
    <p v-if="account.ok" class="compte-succes" role="status">{{ account.ok }}</p>
    <div class="compte-pied">
      <RiftButton type="submit" :disabled="account.saving">
        {{ account.saving ? "Enregistrement…" : "Changer l'email" }}
      </RiftButton>
    </div>
  </RiftPanel>

  <RiftPanel
    tag="form"
    title="Mot de passe"
    accent="var(--bronze)"
    class="compte-form"
    @submit.prevent="submitPassword"
  >
    <RiftField
      v-model="secret.current"
      label="Mot de passe actuel"
      type="password"
      name="password-current"
      autocomplete="current-password"
      required
    />
    <RiftField
      v-model="secret.next"
      label="Nouveau mot de passe"
      type="password"
      name="password-new"
      minlength="8"
      autocomplete="new-password"
      placeholder="8 caractères minimum"
      required
    />
    <RiftField
      v-model="secret.confirm"
      label="Confirmation"
      type="password"
      name="password-confirm"
      minlength="8"
      autocomplete="new-password"
      required
    />
    <p v-if="secret.error" class="compte-erreur" role="alert">{{ secret.error }}</p>
    <p v-if="secret.ok" class="compte-succes" role="status">{{ secret.ok }}</p>
    <div class="compte-pied">
      <RiftButton type="submit" :disabled="secret.saving">
        {{ secret.saving ? "Enregistrement…" : "Changer le mot de passe" }}
      </RiftButton>
    </div>
  </RiftPanel>
</template>

<style scoped>
.compte-form {
  display: grid;
  gap: var(--space-4);
}
.compte-form :deep(.rift-panel-title) {
  margin-bottom: 0;
}
.compte-verif {
  display: grid;
  justify-items: start;
  gap: var(--space-2);
  padding: var(--space-3);
  border-left: 2px solid var(--blood);
  background: var(--bg-sunken);
}
.compte-intro {
  margin: 0;
  color: var(--ink-muted);
}
.compte-erreur,
.compte-succes {
  margin: 0;
  font-size: 14px;
}
.compte-erreur {
  color: var(--blood-text);
}
.compte-succes {
  color: var(--bronze-light);
}
.compte-pied {
  display: flex;
  justify-content: flex-end;
}
</style>
