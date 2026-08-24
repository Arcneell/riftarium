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

// Node 26 définit un accesseur natif globalThis.localStorage qui renvoie
// undefined tant que --localstorage-file n'est pas fourni. Comme il est déjà
// présent (et non énumérable), jsdom n'installe pas le sien et localStorage
// disparaît des tests. On remet alors un Storage minimal — les seules méthodes
// utilisées par l'application. Sur Node 24, jsdom fournit le vrai : no-op.
if (!globalThis.localStorage) {
  const entries = new Map()
  Object.defineProperty(globalThis, "localStorage", {
    configurable: true,
    writable: true,
    value: {
      getItem: (key) => (entries.has(String(key)) ? entries.get(String(key)) : null),
      setItem: (key, value) => {
        entries.set(String(key), String(value))
      },
      removeItem: (key) => {
        entries.delete(String(key))
      },
      clear: () => {
        entries.clear()
      },
      key: (index) => [...entries.keys()][index] ?? null,
      get length() {
        return entries.size
      }
    }
  })
}
