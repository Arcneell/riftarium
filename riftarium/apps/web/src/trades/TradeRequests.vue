<script setup>
import { nextTick, onMounted, ref, watch } from "vue"
import UserAvatar from "../components/UserAvatar.vue"
import { defaultsLabel } from "../collection/collectionDefaults.js"
import { profilePath } from "../social.js"
import { actOnRequest, getRequests, refreshTradeBadge, statusLabel, zoneLabel } from "../trades.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSegments from "../ui/RiftSegments.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"

/* Demandes reçues et envoyées. Les actions dépendent du rôle : le propriétaire
   accepte ou refuse, le demandeur annule, l'un ou l'autre marque l'échange fait.
   Le contact de l'autre joueur n'arrive de l'API qu'une fois la demande acceptée. */
const props = defineProps({
  /* Demande ouverte depuis un e-mail (`?id=`) : mise en évidence et défilement. */
  target: { type: Number, default: null }
})

const box = ref("in")
const boxes = [
  { value: "in", label: "Reçues" },
  { value: "out", label: "Envoyées" }
]
const items = ref([])
const loading = ref(true)
const error = ref("")
const busyId = ref(null)
const copied = ref(null)

const ACTIONS = {
  in: {
    pending: [
      ["accept", "Accepter", "primary"],
      ["decline", "Refuser", "ghost"]
    ]
  },
  out: { pending: [["cancel", "Annuler ma demande", "ghost"]] }
}
function actionsFor(item) {
  if (item.status === "accepted") return [["done", "Marquer comme fait", "secondary"]]
  return ACTIONS[item.box][item.status] ?? []
}

async function load() {
  loading.value = true
  error.value = ""
  try {
    items.value = (await getRequests(box.value)).items
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

async function act(item, action) {
  if (busyId.value) return
  busyId.value = item.id
  error.value = ""
  try {
    Object.assign(item, await actOnRequest(item.id, action))
    refreshTradeBadge()
  } catch (e) {
    error.value = e.message
  } finally {
    busyId.value = null
  }
}

async function copy(item) {
  try {
    await navigator.clipboard.writeText(item.contact)
    copied.value = item.id
  } catch {
    copied.value = null
  }
}

watch(box, load)

onMounted(async () => {
  /* Lien d'e-mail : la demande ciblée peut être une demande envoyée (acceptation). */
  await load()
  if (props.target && !items.value.some((item) => item.id === props.target)) {
    box.value = "out"
    await load()
  }
  await nextTick()
  document.getElementById(`demande-${props.target}`)?.scrollIntoView?.({ block: "center" })
})
</script>

<template>
  <div class="demandes">
    <RiftSegments v-model="box" :items="boxes" label="Demandes" id-base="demandes" />
    <p v-if="error" class="demandes-erreur" role="alert">{{ error }}</p>
    <div v-if="loading" class="demandes-liste">
      <RiftSkeleton v-for="n in 3" :key="n" block />
    </div>
    <ul v-else-if="items.length" class="demandes-liste">
      <li
        v-for="item in items"
        :id="`demande-${item.id}`"
        :key="item.id"
        class="demande"
        :class="{ ciblee: item.id === target }"
      >
        <div class="demande-tete">
          <RouterLink :to="`/cartes/${item.card.id}`" class="demande-carte">{{ item.card.name }}</RouterLink>
          <span class="demande-lot">{{ defaultsLabel(item) }}</span>
          <span class="demande-statut" :class="`statut-${item.status}`">{{ statusLabel(item.status) }}</span>
        </div>
        <p v-if="item.other" class="demande-joueur">
          {{ item.box === "in" ? "De" : "À" }}
          <RouterLink :to="profilePath(item.other.handle)" class="demande-pseudo">
            <UserAvatar :src="item.other.avatar_url || ''" :handle="item.other.handle" :size="24" />
            {{ item.other.handle }}
          </RouterLink>
          · zone {{ zoneLabel(item.other.zone) }}
        </p>
        <blockquote v-if="item.message" class="demande-message">{{ item.message }}</blockquote>
        <RiftPanel v-if="item.contact" title="Contact" accent="var(--blood)">
          <p class="demande-contact-texte">{{ item.contact }}</p>
          <RiftButton size="sm" variant="secondary" @click="copy(item)">
            {{ copied === item.id ? "Copié" : "Copier" }}
          </RiftButton>
        </RiftPanel>
        <p v-else-if="item.status === 'accepted' || item.status === 'done'" class="demande-sans-contact">
          Ce joueur a retiré son contact de son profil.
        </p>
        <div v-if="actionsFor(item).length" class="demande-actions">
          <RiftButton
            v-for="[action, label, variant] in actionsFor(item)"
            :key="action"
            size="sm"
            :variant="variant"
            :disabled="busyId === item.id"
            @click="act(item, action)"
          >
            {{ label }}
          </RiftButton>
        </div>
      </li>
    </ul>
    <RiftEmpty
      v-else-if="!error"
      :title="box === 'in' ? 'Aucune demande reçue' : 'Aucune demande envoyée'"
      :text="
        box === 'in'
          ? 'Quand un joueur s\'intéresse à une de vos offres, sa demande arrive ici (et par e-mail).'
          : 'Depuis les correspondances, « Ça m\'intéresse » envoie une demande au joueur.'
      "
    />
  </div>
</template>

<style scoped>
.demandes {
  display: grid;
  gap: var(--space-4);
}
.demandes-erreur {
  margin: 0;
  font-size: 14px;
  color: var(--blood-text);
}
.demandes-liste {
  display: grid;
  gap: var(--space-3);
  margin: 0;
  padding: 0;
  list-style: none;
}
.demandes-liste :deep(.rift-skeleton-block) {
  height: 120px;
}
.demande {
  display: grid;
  gap: var(--space-2);
  padding: var(--space-3) var(--space-4);
  background: var(--bg-raised);
  border: 1px solid var(--line);
}
.demande.ciblee {
  border-color: var(--bronze-light);
  box-shadow: inset 3px 0 0 var(--blood-bright);
}
.demande-tete {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: var(--space-2) var(--space-3);
}
.demande-carte {
  font-family: var(--font-display);
  font-weight: 700;
  color: var(--ink);
}
.demande-lot {
  font-size: 14px;
  color: var(--ink-muted);
}
.demande-statut {
  margin-left: auto;
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.statut-pending {
  color: var(--bronze-light);
}
.statut-accepted,
.statut-done {
  color: var(--blood-text);
}
.demande-joueur {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-1);
  margin: 0;
  color: var(--ink-muted);
}
.demande-pseudo {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  color: var(--ink);
  font-weight: 600;
}
.demande-message {
  margin: 0;
  padding-left: var(--space-3);
  border-left: 2px solid var(--bronze);
  color: var(--ink);
}
.demande-sans-contact {
  margin: 0;
  font-size: 14px;
  color: var(--ink-muted);
}
.demande-contact-texte {
  margin: 0 0 var(--space-2);
  font-weight: 600;
  color: var(--ink);
  overflow-wrap: anywhere;
}
.demande-actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}
</style>
