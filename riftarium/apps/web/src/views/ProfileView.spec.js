import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import ProfileView from "./ProfileView.vue"
import { api, ApiError, session } from "../api.js"
import Icon from "../components/Icon.vue"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const profile = {
  id: 1,
  handle: "testeur",
  email: "testeur@example.org",
  email_verified: true,
  bio: "",
  avatar_card_id: null,
  avatar_url: null,
  created_at: "2026-01-15T10:00:00+00:00",
  show_stats: false,
  show_collection: false,
  show_decks: true,
  show_achievements: true,
  stats: { unique_cards: 12, total_cards: 40, decks: 2, public_decks: 1, likes_received: 7 }
}

const achievements = [
  {
    key: "first_blood",
    family: "duels",
    title: "Premier sang",
    description: "Remporter un duel suivi.",
    icon: "emoji_events",
    tier: "bronze",
    threshold: 1,
    current: 1,
    unlocked_at: "2026-08-01T10:00:00Z"
  },
  {
    key: "veteran_10",
    family: "duels",
    title: "Vétéran",
    description: "Jouer 10 duels suivis.",
    icon: "military_tech",
    tier: "silver",
    threshold: 10,
    current: 4,
    unlocked_at: null
  },
  {
    key: "architect_1",
    family: "decks",
    title: "Architecte",
    description: "Créer un deck.",
    icon: "architecture",
    tier: "bronze",
    threshold: 1,
    current: 1,
    unlocked_at: "2026-07-02T10:00:00Z"
  }
]

const faces = [
  {
    id: "ogn-247-298",
    name: "Daughter of the Void",
    image_url: "https://cdn.example/ahri.png",
    orientation: "landscape"
  }
]

/* Réponses de base ; `over(path, options)` peut en remplacer une en renvoyant autre chose qu'undefined. */
function setupApi(over = () => undefined, me = profile) {
  api.mockImplementation((path, options = {}) => {
    const custom = over(path, options)
    if (custom !== undefined) return custom
    if (path === "/api/auth/me" && !options.method) return Promise.resolve({ ...me })
    if (path === "/api/auth/avatars") return Promise.resolve(faces)
    if (path === "/api/me/achievements") return Promise.resolve(achievements)
    if (path === "/api/auth/me" && options.method === "PATCH") {
      return Promise.resolve({
        ...me,
        ...options.body,
        handle: options.body.handle || me.handle,
        avatar_url: options.body.avatar_card_id ? faces[0].image_url : null
      })
    }
    if (path === "/api/auth/password") {
      return Promise.resolve({ token: "nouveau-jeton", handle: "testeur", avatar_url: null })
    }
    if (path === "/api/auth/export") {
      return Promise.resolve({ handle: "testeur", collection: [], decks: [] })
    }
    return Promise.resolve(null)
  })
}

function deferred() {
  let resolve
  let reject
  const promise = new Promise((ok, ko) => {
    resolve = ok
    reject = ko
  })
  return { promise, resolve, reject }
}

const calls = (path, method) =>
  api.mock.calls.filter(([called, options]) => called === path && (!method || options?.method === method))

/* Le formulaire qui contient le champ nommé (les formulaires vivent dans des sous-composants). */
const formWith = (wrapper, name) => wrapper.findAll("form").find((form) => form.find(`[name="${name}"]`).exists())

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/", component: { template: "<div />" } },
      { path: "/profil", component: ProfileView },
      { path: "/confidentialite", component: { template: "<div />" } },
      { path: "/u/:handle", component: { template: "<div />" } },
      { path: "/amis", component: { template: "<div />" } }
    ]
  })
  router.push("/profil")
  await router.isReady()
  const wrapper = mount(ProfileView, {
    global: { plugins: [router], components: { Icon } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

/* La modale de suppression est téléportée dans <body>. */
async function openDeleteModal(wrapper) {
  await wrapper.get(".profil-danger .rift-btn").trigger("click")
  const modal = document.body.querySelector(".rift-modal")
  expect(modal).not.toBeNull()
  const fill = (selector, value) => {
    const input = modal.querySelector(selector)
    input.value = value
    input.dispatchEvent(new Event("input"))
  }
  fill("input[type=password]", "motdepasse123")
  fill("input[type=text]", "testeur")
  return modal
}

describe("ProfileView", () => {
  beforeEach(() => {
    session.token = "jeton-test"
    session.handle = "testeur"
    session.avatarUrl = null
    session.emailVerified = null
    api.mockReset()
    setupApi()
  })

  it("affiche les stats et la grille de légendes", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.get("h1").text()).toBe("testeur")
    expect(wrapper.text()).toContain("12")
    expect(wrapper.text()).toContain("Likes reçus")
    expect(wrapper.text()).toContain("Membre depuis")
    expect(wrapper.text()).toContain("Daughter of the Void")
    expect(wrapper.findAll(".profil-portrait")).toHaveLength(2)
    expect(wrapper.get(".profil-portraits").attributes("aria-label")).toBe("Choisir un portrait")
    wrapper.unmount()
  })

  it("enregistre un pseudo et une bio", async () => {
    const { wrapper } = await mountView()
    await wrapper.get('input[name="handle"]').setValue("nyra")
    await wrapper.get('textarea[name="bio"]').setValue("Main Ahri")
    await wrapper.get('input[name="handle-password"]').setValue("motdepasse123")
    await formWith(wrapper, "handle").trigger("submit")
    await flushPromises()

    const [call] = calls("/api/auth/me", "PATCH")
    expect(call[1].body).toEqual({
      bio: "Main Ahri",
      handle: "nyra",
      current_password: "motdepasse123"
    })
    /* Le formulaire suit ce que le serveur a retenu, et le champ de mot de passe disparaît. */
    expect(wrapper.get('input[name="handle"]').element.value).toBe("nyra")
    expect(wrapper.find('input[name="handle-password"]').exists()).toBe(false)
    expect(formWith(wrapper, "handle").get('[role="status"]').text()).toBe("Profil mis à jour")
    wrapper.unmount()
  })

  it("choisit un portrait de légende (sélection en aria-pressed)", async () => {
    const { wrapper } = await mountView()
    let picks = wrapper.findAll(".profil-portrait")
    expect(picks[0].attributes("aria-pressed")).toBe("true")
    expect(picks[0].classes()).toContain("profil-portrait--choisi")
    await picks[1].trigger("click")
    await flushPromises()
    const call = api.mock.calls.find(
      ([path, options]) => path === "/api/auth/me" && options?.method === "PATCH" && options.body?.avatar_card_id
    )
    expect(call[1].body).toEqual({ avatar_card_id: "ogn-247-298" })
    picks = wrapper.findAll(".profil-portrait")
    expect(picks[1].attributes("aria-pressed")).toBe("true")
    expect(picks[1].classes()).toContain("profil-portrait--choisi")
    expect(picks[0].attributes("aria-pressed")).toBe("false")
    wrapper.unmount()
  })

  it("signale un changement d'e-mail avec l'envoi d'un e-mail de vérification", async () => {
    const { wrapper } = await mountView()
    const emailForm = formWith(wrapper, "email")
    expect(emailForm.get('input[name="email"]').attributes("type")).toBe("email")
    expect(emailForm.get('input[name="email"]').attributes("autocomplete")).toBe("email")
    await emailForm.get('input[name="email"]').setValue("nouvelle@example.org")
    await emailForm.get('input[name="email-password"]').setValue("motdepasse123")
    await emailForm.trigger("submit")
    await flushPromises()

    const [call] = calls("/api/auth/me", "PATCH")
    expect(call[1].body).toEqual({ email: "nouvelle@example.org", current_password: "motdepasse123" })
    const status = formWith(wrapper, "email").get(".compte-succes")
    expect(status.attributes("role")).toBe("status")
    expect(status.text()).toBe("Email mis à jour — un e-mail de vérification a été envoyé à la nouvelle adresse.")
    wrapper.unmount()
  })

  it("masque le rappel de vérification quand l'adresse est vérifiée", async () => {
    const { wrapper } = await mountView()
    expect(wrapper.find(".compte-verif").exists()).toBe(false)
    expect(session.emailVerified).toBe(true)
    wrapper.unmount()
  })

  it("adresse non vérifiée : affiche le rappel et renvoie l'e-mail de vérification", async () => {
    setupApi(() => undefined, { ...profile, email_verified: false })
    const { wrapper } = await mountView()

    const line = wrapper.get(".compte-verif")
    expect(line.text()).toContain("Adresse e-mail non vérifiée")
    expect(session.emailVerified).toBe(false)

    await line.get("button").trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/resend-verification", { method: "POST" })
    expect(line.get(".compte-succes").text()).toContain("E-mail de vérification renvoyé")
    wrapper.unmount()
  })

  it("adresse déjà vérifiée côté serveur (400) : le rappel disparaît", async () => {
    setupApi(
      (path) =>
        path === "/api/auth/resend-verification" ? Promise.reject(new ApiError(400, "Déjà vérifiée")) : undefined,
      { ...profile, email_verified: false }
    )
    const { wrapper } = await mountView()
    await wrapper.get(".compte-verif button").trigger("click")
    await flushPromises()
    expect(wrapper.find(".compte-verif").exists()).toBe(false)
    expect(session.emailVerified).toBe(true)
    wrapper.unmount()
  })

  it("refuse un nouveau mot de passe non confirmé", async () => {
    const { wrapper } = await mountView()
    const pwdForm = formWith(wrapper, "password-new")
    await pwdForm.get('input[name="password-current"]').setValue("ancien")
    await pwdForm.get('input[name="password-new"]').setValue("nouveausecret")
    await pwdForm.get('input[name="password-confirm"]').setValue("autrechose")
    await pwdForm.trigger("submit")
    await flushPromises()
    expect(wrapper.text()).toContain("Les mots de passe ne correspondent pas")
    expect(calls("/api/auth/password")).toHaveLength(0)
    wrapper.unmount()
  })

  it("mot de passe : erreur affichée sur place, bouton réactivé", async () => {
    const pending = deferred()
    setupApi((path) => (path === "/api/auth/password" ? pending.promise : undefined))
    const { wrapper } = await mountView()
    const pwdForm = formWith(wrapper, "password-new")
    await pwdForm.get('input[name="password-current"]').setValue("mauvais")
    await pwdForm.get('input[name="password-new"]').setValue("nouveausecret")
    await pwdForm.get('input[name="password-confirm"]').setValue("nouveausecret")
    await pwdForm.trigger("submit")
    await flushPromises()

    const button = pwdForm.get('button[type="submit"]')
    expect(button.attributes("disabled")).toBeDefined()
    expect(button.text()).toBe("Enregistrement…")
    expect(calls("/api/auth/password", "POST")[0][1].body).toEqual({
      current_password: "mauvais",
      new_password: "nouveausecret"
    })

    pending.reject(new ApiError(400, "Mot de passe actuel incorrect"))
    await flushPromises()
    /* Le message s'affiche dans le formulaire du mot de passe, pas ailleurs. */
    const alert = pwdForm.get('[role="alert"]')
    expect(alert.text()).toBe("Mot de passe actuel incorrect")
    expect(formWith(wrapper, "email").find('[role="alert"]').exists()).toBe(false)
    expect(button.attributes("disabled")).toBeUndefined()
    expect(button.text()).toBe("Changer le mot de passe")
    /* La saisie reste là pour corriger. */
    expect(pwdForm.get('input[name="password-new"]').element.value).toBe("nouveausecret")
    wrapper.unmount()
  })

  it("demande une confirmation avant de supprimer le compte", async () => {
    const { wrapper, router } = await mountView()
    expect(calls("/api/auth/me", "DELETE")).toHaveLength(0)
    const modal = await openDeleteModal(wrapper)
    expect(modal.getAttribute("role")).toBe("dialog")
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()

    const [call] = calls("/api/auth/me", "DELETE")
    expect(call[1].body).toEqual({ password: "motdepasse123", handle: "testeur" })
    expect(session.token).toBeNull()
    expect(router.currentRoute.value.path).toBe("/")
    wrapper.unmount()
  })

  it("suppression : modale de confirmation, double clic → une seule requête", async () => {
    const pending = deferred()
    setupApi((path, options) => (path === "/api/auth/me" && options.method === "DELETE" ? pending.promise : undefined))
    const { wrapper, router } = await mountView()
    const modal = await openDeleteModal(wrapper)
    const form = modal.querySelector("form")
    form.dispatchEvent(new Event("submit"))
    form.dispatchEvent(new Event("submit"))
    await flushPromises()

    expect(calls("/api/auth/me", "DELETE")).toHaveLength(1)
    const submit = modal.querySelector('button[type="submit"]')
    expect(submit.disabled).toBe(true)
    expect(submit.textContent.trim()).toBe("Suppression…")

    pending.resolve(null)
    await flushPromises()
    expect(calls("/api/auth/me", "DELETE")).toHaveLength(1)
    expect(router.currentRoute.value.path).toBe("/")
    wrapper.unmount()
  })

  it("suppression refusée : erreur dans la modale, qui reste ouverte", async () => {
    setupApi((path, options) =>
      path === "/api/auth/me" && options.method === "DELETE"
        ? Promise.reject(new ApiError(400, "Pseudo incorrect"))
        : undefined
    )
    const { wrapper, router } = await mountView()
    const modal = await openDeleteModal(wrapper)
    modal.querySelector("form").dispatchEvent(new Event("submit"))
    await flushPromises()
    expect(modal.querySelector('[role="alert"]').textContent).toBe("Pseudo incorrect")
    expect(document.body.querySelector(".rift-modal")).not.toBeNull()
    expect(router.currentRoute.value.path).toBe("/profil")
    expect(modal.querySelector('button[type="submit"]').disabled).toBe(false)
    wrapper.unmount()
  })

  it("groupe les hauts faits par famille, débloqués en tête et progression chiffrée", async () => {
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/me/achievements")

    const families = wrapper.findAll(".profil-famille-titre").map((node) => node.text())
    expect(families[0]).toContain("Duels")
    expect(families[1]).toContain("Decks")
    const title = wrapper.findAll(".rift-panel-title").find((node) => node.text().includes("Hauts faits"))
    expect(title.text()).toContain("2 / 3")

    const medals = wrapper.findAll(".profil-famille")[0].findAll(".profil-medaille")
    expect(medals[0].text()).toContain("Premier sang")
    expect(medals[0].classes()).not.toContain("profil-medaille--verrouille")
    /* Verrouillé : grisé, avec la progression vers le seuil. */
    expect(medals[1].classes()).toContain("profil-medaille--verrouille")
    expect(medals[1].text()).toContain("4 / 10")
    wrapper.unmount()
  })

  it("bascule un réglage de confidentialité et l'enregistre aussitôt", async () => {
    const { wrapper } = await mountView()
    const boxes = wrapper.findAll(".compte-reglages input")
    expect(boxes).toHaveLength(4)
    /* L'état vient du compte : hauts faits et decks visibles, stats et collection non. */
    expect(boxes.map((box) => box.element.checked)).toEqual([true, false, false, true])

    await boxes[1].trigger("change")
    await flushPromises()
    const call = api.mock.calls.find(
      ([path, options]) => path === "/api/auth/me" && options?.method === "PATCH" && "show_stats" in options.body
    )
    expect(call[1].body).toEqual({ show_stats: true })
    expect(wrapper.get(".compte-reglages ~ .compte-succes").text()).toBe("Réglage enregistré")
    expect(wrapper.findAll(".compte-reglages input")[1].element.checked).toBe(true)
    wrapper.unmount()
  })

  it("confidentialité : bascule envoie la valeur et reflète aria-pressed / checked", async () => {
    const pending = deferred()
    setupApi((path, options) =>
      path === "/api/auth/me" && options.method === "PATCH" && "show_decks" in options.body
        ? pending.promise
        : undefined
    )
    const { wrapper } = await mountView()
    const boxes = () => wrapper.findAll(".compte-reglages input")
    /* Une vraie case à cocher, nommée par son libellé. */
    expect(boxes()[3].attributes("type")).toBe("checkbox")
    expect(boxes()[3].element.closest("label").textContent).toContain("Mes decks publics")

    /* Decks visibles → masqués : la valeur envoyée est l'inverse de l'état courant. */
    await boxes()[3].trigger("change")
    await flushPromises()
    const call = calls("/api/auth/me", "PATCH").find(([, options]) => "show_decks" in options.body)
    expect(call[1].body).toEqual({ show_decks: false })
    /* Bascule optimiste : la case suit tout de suite, et tout est figé pendant l'envoi. */
    expect(boxes()[3].element.checked).toBe(false)
    expect(boxes().every((box) => box.attributes("disabled") !== undefined)).toBe(true)
    expect(wrapper.get(".compte-attente").attributes("role")).toBe("status")

    pending.resolve({ ...profile, show_decks: false })
    await flushPromises()
    expect(boxes()[3].element.checked).toBe(false)
    expect(boxes().every((box) => box.attributes("disabled") === undefined)).toBe(true)
    expect(wrapper.get(".compte-reglages ~ .compte-succes").attributes("role")).toBe("status")
    wrapper.unmount()
  })

  it("remet l'interrupteur en place si l'API refuse", async () => {
    setupApi((path, options) =>
      path === "/api/auth/me" && options.method === "PATCH" ? Promise.reject(new Error("Requête invalide")) : undefined
    )
    const { wrapper } = await mountView()
    await wrapper.findAll(".compte-reglages input")[1].trigger("change")
    await flushPromises()
    const error = wrapper.get(".compte-reglages ~ .compte-erreur")
    expect(error.text()).toBe("Requête invalide")
    expect(error.attributes("role")).toBe("alert")
    expect(wrapper.findAll(".compte-reglages input")[1].element.checked).toBe(false)
    wrapper.unmount()
  })

  it("un échec de choix de portrait laisse le profil affiché", async () => {
    setupApi((path, options) =>
      path === "/api/auth/me" && options.method === "PATCH"
        ? Promise.reject(new ApiError(429, "Trop de requêtes, réessayez dans une minute"))
        : undefined
    )
    const { wrapper } = await mountView()
    await wrapper.findAll(".profil-portrait")[1].trigger("click")
    await flushPromises()
    expect(wrapper.get(".profil-erreur").text()).toContain("Trop de requêtes")
    /* Le profil ne disparaît pas : l'erreur est celle d'une action, pas du chargement. */
    expect(wrapper.find(".profil-hero").exists()).toBe(true)
    expect(wrapper.get('input[name="handle"]').element.value).toBe("testeur")
    wrapper.unmount()
  })

  it("une bascule de confidentialité ne réécrit pas la bio en cours de saisie", async () => {
    const { wrapper } = await mountView()
    await wrapper.get('textarea[name="bio"]').setValue("Main Fureur, Réunion")
    await wrapper.get('input[name="handle"]').setValue("nyra")

    await wrapper.findAll(".compte-reglages input")[0].trigger("change")
    await flushPromises()
    expect(wrapper.get(".compte-reglages ~ .compte-succes").text()).toBe("Réglage enregistré")
    /* La réponse du PATCH rafraîchit le profil, jamais les champs déjà saisis. */
    expect(wrapper.get('textarea[name="bio"]').element.value).toBe("Main Fureur, Réunion")
    expect(wrapper.get('input[name="handle"]').element.value).toBe("nyra")
    wrapper.unmount()
  })

  it("le sélecteur de portrait est un groupe nommé pour les lecteurs d'écran", async () => {
    const { wrapper } = await mountView()
    const scroller = wrapper.get(".profil-portraits")
    expect(scroller.attributes("role")).toBe("group")
    expect(scroller.attributes("aria-label")).toBe("Choisir un portrait")
    wrapper.unmount()
  })

  it("mène au profil public et aux amis", async () => {
    const { wrapper } = await mountView()
    const links = wrapper.findAll(".profil-hero-actions a").map((link) => link.attributes("href"))
    expect(links).toEqual(["/u/testeur", "/amis"])
    wrapper.unmount()
  })

  it("pseudo long : ellipse", async () => {
    const long = "chevalier-de-la-forge-noxienne-x"
    setupApi(() => undefined, { ...profile, handle: long })
    const { wrapper } = await mountView()
    const title = wrapper.get("h1")
    expect(title.classes()).toContain("profil-hero-pseudo")
    /* Tronqué à l'écran, le pseudo complet reste lisible au survol et pour les lecteurs d'écran. */
    expect(title.attributes("title")).toBe(long)
    expect(title.text()).toBe(long)
    wrapper.unmount()
  })

  it("export RGPD : télécharge le JSON du compte", async () => {
    /* jsdom n'implémente pas les URL d'objets : bouchons posés pour ce seul test. */
    vi.stubGlobal("URL", Object.assign(class extends URL {}, { createObjectURL: () => "blob:x", revokeObjectURL() {} }))
    const click = vi.spyOn(HTMLAnchorElement.prototype, "click").mockImplementation(() => {})
    const { wrapper } = await mountView()
    const button = wrapper.findAll("button").find((node) => node.text() === "Exporter mon compte")
    await button.trigger("click")
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/auth/export")
    expect(click).toHaveBeenCalledTimes(1)
    expect(click.mock.instances[0].download).toBe("riftarium-testeur.json")
    click.mockRestore()
    vi.unstubAllGlobals()
    wrapper.unmount()
  })

  it("profil illisible : message d'erreur sous le titre de la page", async () => {
    setupApi((path, options) =>
      path === "/api/auth/me" && !options.method ? Promise.reject(new Error("Service indisponible")) : undefined
    )
    const { wrapper } = await mountView()
    expect(wrapper.get("h1").text()).toBe("Mon profil")
    expect(wrapper.get('[role="alert"]').text()).toBe("Service indisponible")
    expect(wrapper.find(".profil-hero").exists()).toBe(false)
    wrapper.unmount()
  })
})
