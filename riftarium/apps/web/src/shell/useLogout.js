import { ref } from "vue"
import { useRouter } from "vue-router"
import { api, setSession } from "../api.js"

/* Déconnexion partagée par le menu du compte (bureau) et la feuille (téléphone).
   Réentrance bloquée : deux clics rapides enverraient deux POST /logout. */
export function useLogout() {
  const router = useRouter()
  const loggingOut = ref(false)

  async function logout() {
    if (loggingOut.value) return
    loggingOut.value = true
    try {
      await api("/api/auth/logout", { method: "POST" })
    } catch {
      /* la session locale se ferme même si le cookie a déjà expiré */
    }
    setSession(null, null)
    loggingOut.value = false
    router.push("/")
  }

  return { loggingOut, logout }
}
