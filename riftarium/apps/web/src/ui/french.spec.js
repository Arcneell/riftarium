import { describe, expect, it } from "vitest"
import { de, plural, pluralWord } from "./french.js"

describe("plural", () => {
  it("accorde selon le nombre", () => {
    expect(plural(0, "carte")).toBe("0 carte")
    expect(plural(1, "carte")).toBe("1 carte")
    expect(plural(2, "carte")).toBe("2 cartes")
    expect(plural(3, "carte unique", "cartes uniques")).toBe("3 cartes uniques")
  })
})

describe("de", () => {
  it("élide devant une voyelle", () => {
    expect(de("Ahri")).toBe("d'Ahri")
    expect(de("Irelia")).toBe("d'Irelia")
    expect(de("Écho")).toBe("d'Écho")
  })
  it("garde « de » devant une consonne, un h ou un y consonne", () => {
    expect(de("Jinx")).toBe("de Jinx")
    expect(de("Heimerdinger")).toBe("de Heimerdinger")
    expect(de("Yasuo")).toBe("de Yasuo")
    expect(de("ce lot")).toBe("de ce lot")
  })
})

describe("pluralWord", () => {
  it("garde le singulier pour 0 et 1, passe au pluriel à partir de 2", () => {
    expect(pluralWord(0, "carte", "cartes")).toBe("carte")
    expect(pluralWord(1, "carte")).toBe("carte")
    expect(pluralWord(12, "exemplaire")).toBe("exemplaires")
  })
  it("tolère une valeur absente", () => {
    expect(pluralWord(undefined, "vue", "vues")).toBe("vue")
  })
})
