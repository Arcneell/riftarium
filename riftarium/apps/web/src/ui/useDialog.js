import { nextTick, onBeforeUnmount, onMounted } from "vue"

/* Pile partagée par tous les dialogues (modale, feuille, palette) : un dialogue peut
   en ouvrir un autre (deck builder → cartes manquantes). Seul le dernier ouvert
   reçoit le clavier, et seul le dernier fermé rend son défilement à la page. */
const stack = []

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

export function useDialog(elementRef, close) {
  const token = Symbol("dialog")
  let opener = null

  const focusables = () => (elementRef.value ? [...elementRef.value.querySelectorAll(FOCUSABLE)] : [])

  /* Piège à focus : Tab et Shift+Tab bouclent à l'intérieur du dialogue. */
  function trapTab(event) {
    const items = focusables()
    if (!items.length) {
      event.preventDefault()
      elementRef.value?.focus()
      return
    }
    const first = items[0]
    const last = items[items.length - 1]
    const active = document.activeElement
    const inside = elementRef.value?.contains(active)
    if (event.shiftKey && (!inside || active === first)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && (!inside || active === last)) {
      event.preventDefault()
      first.focus()
    }
  }

  function onKeydown(event) {
    if (stack[stack.length - 1] !== token) return
    if (event.key === "Escape") close()
    else if (event.key === "Tab") trapTab(event)
  }

  onMounted(async () => {
    document.addEventListener("keydown", onKeydown)
    /* La classe et non un style inline : `overflow: hidden` en ligne ne retient pas iOS Safari. */
    stack.push(token)
    document.body.classList.add("nav-locked")
    opener = document.activeElement
    await nextTick()
    const target = focusables()[0] || elementRef.value
    target?.focus()
  })

  onBeforeUnmount(() => {
    document.removeEventListener("keydown", onKeydown)
    const index = stack.lastIndexOf(token)
    if (index !== -1) stack.splice(index, 1)
    if (!stack.length) document.body.classList.remove("nav-locked")
    /* Chaque dialogue rend le focus à SON déclencheur, s'il est encore dans la page. */
    if (opener && document.contains(opener)) opener.focus?.()
  })
}
