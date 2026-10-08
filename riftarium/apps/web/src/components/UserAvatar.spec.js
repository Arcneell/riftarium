import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import UserAvatar from "./UserAvatar.vue"

describe("UserAvatar", () => {
  it("sans image : repli avec l'initiale en majuscule", () => {
    const wrapper = mount(UserAvatar, { props: { handle: "nova", size: 22 } })
    expect(wrapper.classes()).toContain("empty")
    expect(wrapper.get(".rift-avatar-fallback").text()).toBe("N")
    expect(wrapper.attributes("title")).toBe("nova")
    expect(wrapper.attributes("style")).toContain("width: 22px")
  })

  it("sans pseudo ni image : point d'interrogation", () => {
    expect(mount(UserAvatar).get(".rift-avatar-fallback").text()).toBe("?")
  })

  it("avec image : portrait différé, sans repli", () => {
    const wrapper = mount(UserAvatar, { props: { src: "https://cdn.example/nova.png", handle: "nova" } })
    expect(wrapper.classes()).not.toContain("empty")
    expect(wrapper.find(".rift-avatar-fallback").exists()).toBe(false)
    expect(wrapper.get("img").attributes("loading")).toBe("lazy")
  })
})
