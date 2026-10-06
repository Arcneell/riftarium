import { mount } from "@vue/test-utils"
import { describe, expect, it } from "vitest"
import RiftSkeleton from "./RiftSkeleton.vue"

describe("RiftSkeleton", () => {
  it("rend le nombre de lignes demandé, masqué aux lecteurs d'écran", () => {
    const wrapper = mount(RiftSkeleton, { props: { lines: 4 } })
    expect(wrapper.attributes("aria-hidden")).toBe("true")
    expect(wrapper.findAll(".rift-skeleton-line")).toHaveLength(4)
  })

  it("en mode bloc, un seul rectangle", () => {
    const wrapper = mount(RiftSkeleton, { props: { block: true } })
    expect(wrapper.findAll(".rift-skeleton-line")).toHaveLength(0)
    expect(wrapper.find(".rift-skeleton-block").exists()).toBe(true)
  })
})
