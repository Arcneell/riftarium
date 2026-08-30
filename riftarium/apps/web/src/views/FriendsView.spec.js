import { flushPromises, mount } from "@vue/test-utils"
import { createMemoryHistory, createRouter } from "vue-router"
import { beforeEach, describe, expect, it, vi } from "vitest"
import FriendsView from "./FriendsView.vue"
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
    global: { plugins: [router], stubs: { Icon: true }, directives: { tilt: {}, reveal: {} } },
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

    const panels = wrapper.findAll(".friends-panel")
    expect(panels[0].text()).toContain("Suivis")
    expect(panels[0].get(".friend-name").attributes("href")).toBe("/u/nova")
    expect(panels[0].text()).toContain("Dernière partie")
    expect(panels[1].text()).toContain("Abonnés")
    expect(panels[1].get(".friend-name").attributes("href")).toBe("/u/kai")
    wrapper.unmount()
  })

  it("cherche un pseudo après 300 ms, et jamais sous deux caractères", async () => {
    setupApi({ search: [{ id: 9, handle: "novak", avatar_url: null }] })
    const { wrapper } = await mountView()

    await wrapper.get("#friends-q").setValue("n")
    await waitDebounce()
    await flushPromises()
    expect(api.mock.calls.some(([path]) => String(path).startsWith("/api/users/search"))).toBe(false)

    await wrapper.get("#friends-q").setValue("nov")
    await waitDebounce()
    await flushPromises()
    expect(api).toHaveBeenCalledWith("/api/users/search?q=nov")
    const result = wrapper.get(".friends-search .friend-row")
    expect(result.text()).toContain("novak")
    expect(result.get(".friend-name").attributes("href")).toBe("/u/novak")

    /* Un joueur déjà suivi ne se propose pas deux fois. */
    await buttonWith(result, "Suivre").trigger("click")
    await flushPromises()
    expect(lastCall("/api/users/novak/follow")[1]).toEqual({ method: "PUT" })
    expect(buttonWith(result, "Ne plus suivre")).toBeTruthy()
    wrapper.unmount()
  })

  it("cesse de suivre un joueur et le retire de la liste", async () => {
    const { wrapper } = await mountView()
    const row = wrapper.get(".friends-panel .friend-row")
    await buttonWith(row, "Ne plus suivre").trigger("click")
    await flushPromises()
    expect(lastCall("/api/users/nova/follow")[1]).toEqual({ method: "DELETE" })
    expect(wrapper.findAll(".friends-panel")[0].text()).toContain("Personne pour l'instant")
    wrapper.unmount()
  })

  it("invite un suivi : crée un salon de duel, affiche le code et copie le lien", async () => {
    const writeText = vi.fn().mockResolvedValue()
    Object.assign(navigator, { clipboard: { writeText } })
    const { wrapper } = await mountView()

    await buttonWith(wrapper, "Inviter dans un salon").trigger("click")
    await flushPromises()
    expect(lastCall("/api/play/rooms")[1]).toEqual({ method: "POST", body: { mode: "duel" } })

    const invite = wrapper.get(".friends-invite")
    expect(invite.text()).toContain("Salon pour nova")
    expect(invite.get(".friends-invite-code").text()).toBe("ABC234")
    expect(invite.get("a").attributes("href")).toBe("/salon/ABC234")

    await buttonWith(invite, "Copier le lien").trigger("click")
    await flushPromises()
    expect(writeText).toHaveBeenCalledWith(expect.stringContaining("/salon/ABC234"))
    expect(wrapper.get(".friends-invite").text()).toContain("Lien copié")
    wrapper.unmount()
  })

  it("listes vides : explique à quoi sert le carnet d'adversaires", async () => {
    setupApi({ following: [], followers: [] })
    const { wrapper } = await mountView()
    expect(wrapper.text()).toContain("Personne pour l'instant")
    expect(wrapper.text()).toContain("Personne ne vous suit encore")
    expect(wrapper.get(".friends-note").text()).toContain("carnet d'adversaires")
    wrapper.unmount()
  })

  it("affiche l'erreur de l'API sans liste trompeuse", async () => {
    api.mockRejectedValue(new Error("Le serveur a rencontré une erreur"))
    const { wrapper } = await mountView()
    expect(wrapper.get(".error").text()).toBe("Le serveur a rencontré une erreur")
    expect(wrapper.find(".friends-panel").exists()).toBe(false)
    wrapper.unmount()
  })
})
