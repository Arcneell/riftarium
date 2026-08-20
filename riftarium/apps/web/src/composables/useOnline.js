import { onBeforeUnmount, onMounted, ref } from "vue"

/* État de connexion réactif : suit navigator.onLine et les événements
   online/offline (écouteurs nettoyés au démontage). Sert au bandeau
   « Hors ligne » des pages de règles, disponibles via le service worker. */
export function useOnline() {
  const online = ref(typeof navigator === "undefined" || navigator.onLine !== false)
  const update = () => {
    online.value = navigator.onLine !== false
  }
  onMounted(() => {
    update()
    window.addEventListener("online", update)
    window.addEventListener("offline", update)
  })
  onBeforeUnmount(() => {
    window.removeEventListener("online", update)
    window.removeEventListener("offline", update)
  })
  return online
}
