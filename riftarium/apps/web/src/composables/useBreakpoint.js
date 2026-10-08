import { onBeforeUnmount, ref } from "vue"

/* Paliers de la coquille : téléphone (< 768 px : onglets du bas), tablette
   (< 1 024 px : rail replié par défaut), bureau. */
const MOBILE = "(max-width: 767px)"
const TABLET = "(max-width: 1023px)"

export function useBreakpoint() {
  const media = typeof window !== "undefined" && window.matchMedia ? window.matchMedia.bind(window) : null
  const mobile = media?.(MOBILE)
  const tablet = media?.(TABLET)
  const compute = () => (mobile?.matches ? "mobile" : tablet?.matches ? "tablet" : "desktop")
  const breakpoint = ref(compute())
  const update = () => {
    breakpoint.value = compute()
  }
  mobile?.addEventListener?.("change", update)
  tablet?.addEventListener?.("change", update)
  onBeforeUnmount(() => {
    mobile?.removeEventListener?.("change", update)
    tablet?.removeEventListener?.("change", update)
  })
  return breakpoint
}
