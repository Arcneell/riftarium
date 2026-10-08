<script setup>
import { reactive } from "vue"
import UserAvatar from "../components/UserAvatar.vue"
import RiftButton from "../ui/RiftButton.vue"
import RiftField from "../ui/RiftField.vue"
import RiftPanel from "../ui/RiftPanel.vue"

/* Identité (pseudo, bio) et portrait de légende. Le formulaire garde sa saisie en
   local : une réponse d'une autre action (confidentialité, portrait) rafraîchit le
   profil sans écraser un pseudo ou une bio en cours d'écriture. Le réseau reste
   dans la page : `save(body)` renvoie le profil retenu par le serveur ou lève. */
const props = defineProps({
  profile: { type: Object, required: true },
  avatars: { type: Array, default: () => [] },
  /* Choix de portrait en cours : la grille est figée. */
  picking: { type: Boolean, default: false },
  save: { type: Function, required: true }
})
const emit = defineEmits(["pick"])

const form = reactive({
  handle: props.profile.handle,
  bio: props.profile.bio || "",
  password: "",
  saving: false,
  error: "",
  ok: ""
})

async function submit() {
  if (form.saving) return
  form.saving = true
  form.error = ""
  form.ok = ""
  const body = { bio: form.bio }
  if (form.handle !== props.profile.handle) {
    body.handle = form.handle
    body.current_password = form.password
  }
  try {
    /* Envoi volontaire : on recale le formulaire sur ce que le serveur a retenu
       (pseudo normalisé, bio tronquée…). */
    const saved = await props.save(body)
    form.handle = saved.handle
    form.bio = saved.bio || ""
    form.password = ""
    form.ok = "Profil mis à jour"
  } catch (e) {
    form.error = e.message
  } finally {
    form.saving = false
  }
}
</script>

<template>
  <RiftPanel tag="form" title="Identité" accent="var(--bronze)" class="compte-form" @submit.prevent="submit">
    <p class="compte-intro">
      Votre pseudo est visible sur votre profil public, vos decks publics, dans les salons et les échanges.
    </p>
    <RiftField
      v-model="form.handle"
      label="Pseudo"
      name="handle"
      autocapitalize="none"
      autocorrect="off"
      spellcheck="false"
      minlength="3"
      maxlength="32"
      autocomplete="username"
      required
    />
    <div class="compte-bio">
      <label for="profil-bio" class="compte-label">Bio</label>
      <textarea
        id="profil-bio"
        v-model="form.bio"
        class="compte-bio-input"
        name="bio"
        maxlength="280"
        placeholder="Main, région, ce que vous cherchez en communauté…"
      ></textarea>
    </div>
    <RiftField
      v-if="form.handle !== profile.handle"
      v-model="form.password"
      label="Mot de passe actuel"
      type="password"
      name="handle-password"
      autocomplete="current-password"
      required
    />
    <p v-if="form.error" class="compte-erreur" role="alert">{{ form.error }}</p>
    <p v-if="form.ok" class="compte-succes" role="status">{{ form.ok }}</p>
    <div class="compte-pied">
      <RiftButton type="submit" :disabled="form.saving">
        {{ form.saving ? "Enregistrement…" : "Enregistrer" }}
      </RiftButton>
    </div>
  </RiftPanel>

  <RiftPanel title="Portrait de légende" accent="var(--bronze)">
    <p class="compte-intro">Choisissez un portrait parmi les légendes Riftbound.</p>
    <div
      class="profil-portraits"
      :class="{ 'profil-portraits--occupe': picking }"
      tabindex="0"
      role="group"
      aria-label="Choisir un portrait"
      :aria-busy="picking ? 'true' : undefined"
    >
      <button
        type="button"
        class="profil-portrait"
        :class="{ 'profil-portrait--choisi': !profile.avatar_card_id }"
        :aria-pressed="String(!profile.avatar_card_id)"
        @click="emit('pick', null)"
      >
        <UserAvatar :handle="profile.handle" :size="72" />
        <span class="profil-portrait-nom">Initiales</span>
      </button>
      <button
        v-for="face in avatars"
        :key="face.id"
        type="button"
        class="profil-portrait"
        :class="{ 'profil-portrait--choisi': profile.avatar_card_id === face.id }"
        :aria-pressed="String(profile.avatar_card_id === face.id)"
        :title="face.name"
        @click="emit('pick', face.id)"
      >
        <UserAvatar :src="face.image_url" :handle="face.name" :size="72" :orientation="face.orientation" />
        <span class="profil-portrait-nom">{{ face.name }}</span>
      </button>
    </div>
    <p v-if="!avatars.length" class="compte-intro compte-apres">Aucune légende disponible pour le moment.</p>
  </RiftPanel>
</template>

<style scoped>
.compte-form {
  display: grid;
  gap: var(--space-4);
}
/* RiftPanel pose la marge de son intertitre : la grille ajoute déjà l'écart. */
.compte-form :deep(.rift-panel-title) {
  margin-bottom: 0;
}
.compte-intro {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
}
.compte-form .compte-intro {
  margin: 0;
}
.compte-apres {
  margin: var(--space-3) 0 0;
}
.compte-bio {
  display: grid;
  gap: var(--space-1);
}
.compte-label {
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
/* Textarea : reprend le champ de la Forge (fond, arrondi, halo au focus). */
.compte-bio-input {
  width: 100%;
  min-height: 96px;
  padding: var(--space-3);
  resize: vertical;
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  border-radius: 0;
  color: var(--ink);
  font: inherit;
  box-shadow: none;
}
.compte-bio-input:focus {
  outline: none;
  border-color: var(--bronze-light);
  box-shadow: none;
}
.compte-bio-input::placeholder {
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

/* ---------- Portraits ---------- */
.profil-portraits {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(96px, 1fr));
  gap: var(--space-2);
  max-height: 360px;
  overflow-y: auto;
  padding: var(--space-1);
}
.profil-portraits--occupe {
  opacity: 0.6;
  pointer-events: none;
}
.profil-portrait {
  display: grid;
  justify-items: center;
  gap: var(--space-1);
  min-height: 44px;
  padding: var(--space-2) var(--space-1);
  border: 1px solid transparent;
  color: var(--ink-muted);
  transition:
    border-color var(--t-fast),
    color var(--t-fast);
}
.profil-portrait:hover {
  border-color: var(--line);
  color: var(--ink);
}
/* Portrait retenu : filet sang autour de la case et du médaillon. */
.profil-portrait--choisi,
.profil-portrait--choisi:hover {
  border-color: var(--blood);
  box-shadow: inset 0 0 0 1px var(--blood);
  color: var(--ink);
}
.profil-portrait--choisi :deep(.rift-avatar) {
  border: 2px solid var(--blood);
}
.profil-portrait:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.profil-portrait-nom {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 12px;
}
</style>
