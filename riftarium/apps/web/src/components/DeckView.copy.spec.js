import { describe, expect, it, vi, beforeEach } from "vitest"
import { mount } from "@vue/test-utils"
import DeckView from "./DeckView.vue"
import { api, session } from "../api.js"

vi.mock("../api.js", async (importOriginal) => {
  const mod = await importOriginal()
  return { ...mod, api: vi.fn() }
})

const push = vi.fn()
vi.mock("vue-router", () => ({ useRouter: () => ({ push }) }))

const DECK = {
  id: 7,
  name: "Aggro Fureur",
  owner: "auteur",
  format: "tournament",
  is_public: true,
  likes: 3,
  views: 12,
  cards: [],
  checks: []
}

function mountView() {
  return mount(DeckView, {
    props: { deck: DECK },
    global: { stubs: { Icon: true, RouterLink: true, DeckExportBar: true, DeckVisual: true, UserAvatar: true } }
  })
}

describe("DeckView — copier dans mes decks", () => {
  beforeEach(() => {
    api.mockReset()
    push.mockReset()
    session.token = "1"
    session.handle = "visiteur"
  })

  it("copie le deck puis ouvre la copie dans l'éditeur", async () => {
    api.mockResolvedValue({ id: 99 })
    const wrapper = mountView()
    const button = wrapper.findAll("button").find((b) => b.text().includes("Copier dans mes decks"))
    expect(button).toBeTruthy()
    await button.trigger("click")
    await new Promise((r) => setTimeout(r))
    expect(api).toHaveBeenCalledWith("/api/decks/7/copy", { method: "POST" })
    expect(push).toHaveBeenCalledWith("/decks/99")
  })

  it("masqué pour le propriétaire et les visiteurs non connectés", () => {
    session.handle = "auteur"
    expect(
      mountView()
        .findAll("button")
        .some((b) => b.text().includes("Copier"))
    ).toBe(false)
    session.token = null
    session.handle = null
    expect(
      mountView()
        .findAll("button")
        .some((b) => b.text().includes("Copier"))
    ).toBe(false)
  })
})
