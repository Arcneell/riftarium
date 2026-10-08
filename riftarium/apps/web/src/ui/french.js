/* Petits accords du français pour les textes construits à partir de données. */

/* Accorde un nom avec son nombre : plural(1, "carte") → « 1 carte », plural(3, "carte") → « 3 cartes ».
   Le pluriel irrégulier se passe en troisième argument. Zéro et un restent au singulier. */
export function plural(count, singular, pluralForm = `${singular}s`) {
  return `${count} ${Math.abs(count) >= 2 ? pluralForm : singular}`
}

/* « de » ou « d' » devant un nom : de("Ahri") → « d'Ahri », de("Jinx") → « de Jinx ».
   On élide devant une voyelle (accentuée ou non). Le h n'est pas élidé : les noms de cartes en h
   sont aspirés ou étrangers (« de Heimerdinger »). */
export function de(name) {
  const text = String(name ?? "").trim()
  return /^[aeiouyàâäéèêëîïôöùûü]/i.test(text) && !/^y[aeiou]/i.test(text) ? `d'${text}` : `de ${text}`
}

/* Forme seule, sans le nombre, quand celui-ci est affiché à part :
   pluralWord(1, "carte", "cartes") → « carte ». Zéro et un restent au singulier. */
export function pluralWord(count, singular, pluralForm = `${singular}s`) {
  return Math.abs(Number(count) || 0) >= 2 ? pluralForm : singular
}
