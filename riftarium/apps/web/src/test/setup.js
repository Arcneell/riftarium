import { vi } from "vitest"

class IntersectionObserverMock {
  constructor(callback) {
    this.callback = callback
    this.observe = vi.fn()
    this.unobserve = vi.fn()
    this.disconnect = vi.fn()
    IntersectionObserverMock.instances.push(this)
  }
}
IntersectionObserverMock.instances = []
globalThis.IntersectionObserver = IntersectionObserverMock

if (!window.matchMedia) {
  window.matchMedia = (query) => ({
    matches: false,
    media: query,
    addEventListener() {},
    removeEventListener() {},
    addListener() {},
    removeListener() {},
    dispatchEvent() {
      return false
    }
  })
}

globalThis.__io = IntersectionObserverMock
