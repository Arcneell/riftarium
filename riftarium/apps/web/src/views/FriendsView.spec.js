import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import FriendsView from "./FriendsView.vue"
import Icon from "../components/Icon.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const actual = await importOriginal()
  return { ...actual, api: vi.fn() }
})

const NOVA = {
  id: 3,
  handle: "nova",
  avatar_url: "https://cdn.example/nova.png",
  last_match_at: "2026-08-12T19:30:00Z"
}
const KAI = { id: 4, handle: "kai", avatar_url: null }

function setupApi({ following = [NOVA], followers = [KAI], search = [] } = {}) {
  api.mockImplementation((path) => {
    if (path === "/api/me/follows") return Promise.resolve({ following, followers })
    if (path.startsWith("/api/users/search")) return Promise.resolve(search)
    if (path === "/api/play/rooms") return Promise.resolve({ code: "ABC234", mode: "duel", status: "open" })
    return Promise.resolve(null)
  })
}

const lastCall = (fragment) => [...api.mock.calls].reverse().find(([path]) => String(path).includes(fragment))

async function mountView() {
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: "/amis", component: FriendsView },
      { path: "/u/:handle", component: { template: "<div />" } },
      { path: "/salon/:code?", component: { template: "<div />" } },
      { path: "/historique", component: { template: "<div />" } }
    ]
  })
  router.push("/amis")
  await router.isReady()
  const wrapper = mount(FriendsView, {
    global: { plugins: [router], components: { Icon } },
    attachTo: document.body
  })
  await flushPromises()
  return { wrapper, router }
}

const buttonWith = (scope, label) => scope.findAll("button").find((button) => button.text().includes(label))
/* Recherche débrayée de 300 ms : on laisse passer le délai réel, comme dans le salon. */
const waitDebounce = () => new Promise((resolve) => setTimeout(resolve, 360))

describe("FriendsView", () => {
  beforeEach(() => {
    session.token = "jeton-test"
    session.handle = "moi"
    api.mockReset()
    setupApi()
  })

  it("liste les suivis et les abonnés, avec un lien vers chaque profil public", async () => {
    const { wrapper } = await mountView()
    expect(api).toHaveBeenCalledWith("/api/me/follows")

    expect(wrapper.get("h1").text()).toBe("Mes amis")
    const panels = wrapper.findAll(".amis-panel")
    expect(panels[0].text()).toContain("Joueurs suivis")
    expect(panels[0].text()).toContain("(1)")
    expect(panels[0].get(".amis-nom").attributes("href")).toBe("/u/nova")
    expect(panels[0].text()).toContain("Dernière partie")
    expect(panels[1].text()).toContain("Abonnés")
    expect(panels[1].get(".amis-nom").attributes("href")).toBe("/u/kai")
    wrapper.unmount()
  })

  it("cherche un pseudo après 300 ms, et jamais sous deux caractères", async () => {
    setupApi({ search: [{ id: 9, handle: "novak", avatar_url: null }] })
    const { wrapper } = await mountView()

    await wrapper.get("input[type='search']").setValue("n")
    await waitDebounce()
    await flushPromises()
    expect(api.mock.calls.some(([path]) => String(path).startsWith("/api/users/search"))).toBe(false)

    await wrapper.get("input[type='search']").setValue("nov")
    await waitDebounce()
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/users/search?q=nov")
    const result = wrapper.get(".amis-recherche .amis-row")
    expect(result.text()).toContain("novak")
    expect(result.get(".amis-nom").attributes("href")).toBe("/u/novak")

    /* Un joueur déjà suivi ne se propose pas deux fois. */
    const suivre = buttonWith(result, "Suivre")
    expect(suivre.attributes("aria-label")).toBe("Suivre novak")
    await suivre.trigger("click")
    await flushPromises()
    expect(lastCall("/api/users/novak/follow")[1]).toEqual({ method: "PUT" })
    const suivi = buttonWith(result, "Suivi")
    expect(suivi).toBeTruthy()
    expect(suivi.attributes("aria-pressed")).toBeUndefined()
    expect(suivi.attributes("aria-label")).toBe("Suivi, ne plus suivre novak")
    expect(suivi.attributes("title")).toBe("Ne plus suivre novak")

    /* Un clic sur « Suivi » se désabonne réellement. */
    await suivi.trigger("click")
    await flushPromises()
    expect(lastCall("/api/users/novak/follow")[1]).toEqual({ method: "DELETE" })
    wrapper.unmount()
  })

  it("cesse de suivre un joueur et le retire de la liste", async () => {
    const { wrapper } = await mountView()
    const row = wrapper.get(".amis-panel .amis-row")
    await buttonWith(row, "Ne plus suivre").trigger("click")
    await flushPromises()
    expect(lastCall("/api/users/nova/follow")[1]).toEqual({ method: "DELETE" })
    expect(wrapper.findAll(".amis-panel")[0].find(".rift-empty").text()).toContain("Personne pour l'instant")
    wrapper.unmount()
  })

  it("invite un suivi : crée un salon de duel, affiche le code et copie le lien", async () => {
    const writeText = vi.fn().mockResolvedValue()
    Object.assign(navigator, { clipboard: { writeText } })
    const { wrapper } = await mountView()

    await buttonWith(wrapper, "Inviter dans un salon").trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/rooms")[1]).toEqual({ method: "POST", body: { mode: "duel" } })

    const invite = wrapper.get(".amis-invite")
    expect(invite.text()).toContain("Salon pour nova")
    expect(invite.get(".amis-invite-code").text()).toBe("ABC234")
    expect(invite.get("a").attributes("href")).toBe("/salon/ABC234")

    await buttonWith(invite, "Copier le lien").trigger("click")
    await flushPromises()
    expect(writeText).toHaveBeenCalledWith(expect.stringContaining("/salon/ABC234"))
    expect(wrapper.get(".amis-invite").text()).toContain("Lien copié")
    wrapper.unmount()
  })

  it("un suivi garde Inviter dans un salon et Ne plus suivre ; un abonné non suivi se suit en retour", async () => {
    const { wrapper } = await mountView()
    const [suivis, abonnes] = wrapper.findAll(".amis-panel")
    expect(buttonWith(suivis, "Inviter dans un salon")).toBeTruthy()
    expect(buttonWith(suivis, "Ne plus suivre")).toBeTruthy()
    expect(buttonWith(abonnes, "Suivre en retour")).toBeTruthy()
    expect(buttonWith(abonnes, "Inviter dans un salon")).toBeUndefined()
    wrapper.unmount()
  })

  it("pseudo long : ellipse, pseudo complet en infobulle", async () => {
    const long = "nova".repeat(10)
    setupApi({ following: [{ id: 3, handle: long, avatar_url: null }] })
    const { wrapper } = await mountView()
    const name = wrapper.get(".amis-panel .amis-nom")
    expect(name.text()).toBe(long)
    expect(name.attributes("title")).toBe(long)
    wrapper.unmount()
  })

  it("listes vides : précise ce que le suivi rend visible", async () => {
    setupApi({ following: [], followers: [] })
    const { wrapper } = await mountView()
    expect(wrapper.findAll(".amis-panel .rift-empty")).toHaveLength(2)
    expect(wrapper.text()).toContain("Personne pour l'instant")
    expect(wrapper.text()).toContain("Personne ne vous suit encore")
    expect(wrapper.get(".amis-note").text()).toContain("ne reçoit aucune notification")
    wrapper.unmount()
  })

  it("affiche l'erreur de l'API sans liste trompeuse", async () => {
    api.mockRejectedValue(new Error("Le serveur a rencontré une erreur"))
    const { wrapper } = await mountView()
    expect(wrapper.get("[role='alert']").text()).toBe("Le serveur a rencontré une erreur")
    expect(wrapper.find(".amis-panel").exists()).toBe(false)
    wrapper.unmount()
  })
})
