<script>
/* Portée module, et non instance : tout le code d'un <script setup> vit dans
   setup(), donc une pile déclarée là serait remise à zéro par chaque modale.
   Une modale peut en ouvrir une autre (deck builder → cartes manquantes) :
   seule la dernière ouverte reçoit le clavier, et seule la dernière fermée
   rend son défilement à la page. */
const stack = []
</script>

<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref, useId } from "vue"

const props = defineProps({
  title: { type: String, required: true },
  wide: { type: Boolean, default: false }
})
const emit = defineEmits(["close"])

const modalEl = ref(null)
/* Repère d'instance dans la pile (un symbole : jamais confondu avec un autre)
   et identifiant du titre, auquel le dialogue est relié. */
const token = Symbol("modal")
const titleId = `${useId()}-title`
let opener = null // élément qui avait le focus à l'ouverture, restitué à la fermeture

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

function focusables() {
  return modalEl.value ? [...modalEl.value.querySelectorAll(FOCUSABLE)] : []
}

/* Piège à focus minimal : Tab et Shift+Tab bouclent à l'intérieur de la modale. */
function trapTab(event) {
  const items = focusables()
  if (!items.length) {
    event.preventDefault()
    modalEl.value?.focus()
    return
  }
  const first = items[0]
  const last = items[items.length - 1]
  const active = document.activeElement
  const inside = modalEl.value?.contains(active)
  if (event.shiftKey && (!inside || active === first)) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && (!inside || active === last)) {
    event.preventDefault()
    first.focus()
  }
}

function onKeydown(event) {
  /* Modales empilées : l'écouteur est posé sur `document` par chaque instance.
     Sans ce test, Échap fermait toute la pile d'un coup et le piège à focus de
     la modale du dessous volait le focus à celle du dessus. */
  if (stack[stack.length - 1] !== token) return
  if (event.key === "Escape") emit("close")
  else if (event.key === "Tab") trapTab(event)
}

onMounted(async () => {
  document.addEventListener("keydown", onKeydown)
  /* Même verrou que le tiroir de navigation : `overflow: hidden` posé en style
     inline ne retient pas iOS Safari, la classe le fait (et reste stylée au même
     endroit que le reste du blocage de défilement). */
  stack.push(token)
  document.body.classList.add("nav-locked")
  opener = document.activeElement
  await nextTick()
  const target = focusables()[0] || modalEl.value
  target?.focus()
})

onBeforeUnmount(() => {
  document.removeEventListener("keydown", onKeydown)
  const index = stack.lastIndexOf(token)
  if (index !== -1) stack.splice(index, 1)
  if (!stack.length) document.body.classList.remove("nav-locked")
  /* Chaque modale mémorise SON déclencheur : quand celle du dessus se ferme, le
     focus revient au bouton qui l'a ouverte, même s'il vit dans la modale du
     dessous. Seule condition : que l'élément soit encore dans la page. */
  if (opener && document.contains(opener)) opener.focus?.()
})
</script>

<template>
  <Teleport to="body">
    <!-- @click.self et non @pointerdown.self : au doigt, un début de glissement
         sur le fond fermait la modale avant même le relâchement. -->
    <div class="modal-overlay" @click.self="emit('close')">
      <div
        ref="modalEl"
        class="modal"
        :class="{ wide: props.wide }"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="titleId"
        tabindex="-1"
      >
        <div class="modal-head">
          <h3 :id="titleId">{{ title }}</h3>
          <button type="button" class="modal-close" aria-label="Fermer" @click="emit('close')">✕</button>
        </div>
        <div class="modal-body">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>
