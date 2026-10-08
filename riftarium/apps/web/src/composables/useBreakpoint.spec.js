import { mount } from "@vue/test-utils"
import { afterEach, describe, expect, it, vi } from "vitest"
import { defineComponent, h, nextTick } from "vue"
import { useBreakpoint } from "./useBreakpoint.js"

function stubMatchMedia(width) {
  const listeners = []
  const queries = new Map()
  window.matchMedia = vi.fn((query) => {
    const max = Number(query.match(/max-width:\s*(\d+)px/)[1])
    const mql = {
      get matches() {
        return width.value <= max
      },
      addEventListener: (_type, fn) => listeners.push(fn),
      removeEventListener: (_type, fn) => listeners.splice(listeners.indexOf(fn), 1)
    }
    queries.set(query, mql)
    return mql
  })
  return { fire: () => listeners.forEach((fn) => fn()), listeners }
}

const Probe = defineComponent({
  setup() {
    const breakpoint = useBreakpoint()
    return () => h("span", breakpoint.value)
  }
})

const original = window.matchMedia
afterEach(() => {
  window.matchMedia = original
})

describe("useBreakpoint", () => {
  it.each([
    [390, "mobile"],
    [800, "tablet"],
    [1440, "desktop"]
  ])("%i px → %s", (px, expected) => {
    stubMatchMedia({ value: px })
    expect(mount(Probe).text()).toBe(expected)
  })

  it("suit les changements de taille et se désabonne au démontage", async () => {
    const width = { value: 1440 }
    const media = stubMatchMedia(width)
    const wrapper = mount(Probe)
    width.value = 390
    media.fire()
    await nextTick()
    expect(wrapper.text()).toBe("mobile")
    wrapper.unmount()
    expect(media.listeners).toHaveLength(0)
  })
})
