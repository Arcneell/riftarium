/* Riftarium — maquette. Données de démonstration.
   Visuels © Riot Games, servis depuis le CDN officiel (cmsassets.rgpub.io).
   Noms FR et prix : valeurs FICTIVES de démonstration (en attente API Riot / Cardmarket). */

const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live";
const img = (hash, w = 420) => `${CDN}/${hash}?auto=format&fit=max&w=${w}&accountingTag=RB`;

const DOMAINS = {
  fury:  { fr: "Fureur", en: "Fury",  color: "var(--fury)" },
  calm:  { fr: "Calme",  en: "Calm",  color: "var(--calm)" },
  mind:  { fr: "Esprit", en: "Mind",  color: "var(--mind)" },
  body:  { fr: "Corps",  en: "Body",  color: "var(--body)" },
  chaos: { fr: "Chaos",  en: "Chaos", color: "var(--chaos)" },
  order: { fr: "Ordre",  en: "Order", color: "var(--order)" },
  colorless: { fr: "Neutre", en: "Colorless", color: "var(--muted)" }
};

const CARDS = [
  { id: "ogn-037", en: "Immortal Phoenix", fr: "Phénix immortel", code: "OGN-037/298", type: "unit", typeFr: "Unité", typeEn: "Unit", rarity: "Épique", domain: "fury", artist: "Kudos Productions", price: 7.9, hash: "7b623ae985bf5f362b6d8d4a17e9b8146aeae3c3-744x1039.png" },
  { id: "ogn-078", en: "Lee Sin, Ascetic", fr: "Lee Sin, Ascète", code: "OGN-078/298", type: "unit", typeFr: "Unité", typeEn: "Unit", rarity: "Épique", domain: "calm", artist: "Six More Vodka", price: 5.4, hash: "70734e8833bfbbdb2736407c449f418553e3cf7c-744x1039.png" },
  { id: "ogn-119", en: "Ahri, Inquisitive", fr: "Ahri, Curieuse", code: "OGN-119/298", type: "unit", typeFr: "Unité", typeEn: "Unit", rarity: "Épique", domain: "mind", artist: "Six More Vodka", price: 11.2, hash: "cfa28e1abcac1db780d11e82985e13ee5978290d-744x1039.png" },
  { id: "ogn-161", en: "Deadbloom Predator", fr: "Prédateur des fleurs-mortes", code: "OGN-161/298", type: "unit", typeFr: "Unité", typeEn: "Unit", rarity: "Épique", domain: "body", artist: "Slawomir Maniak", price: 3.1, hash: "112b4b3847b26ea2d245ac0976717d109be7b032-744x1039.png" },
  { id: "ogn-202", en: "Jinx, Rebel", fr: "Jinx, Rebelle", code: "OGN-202/298", type: "unit", typeFr: "Unité", typeEn: "Unit", rarity: "Épique", domain: "chaos", artist: "Kudos Productions", price: 14.6, hash: "a7fe105f40df66525be51bd18e25506945a7b027-744x1039.png" },
  { id: "ogn-243", en: "Darius, Executioner", fr: "Darius, Bourreau", code: "OGN-243/298", type: "unit", typeFr: "Unité", typeEn: "Unit", rarity: "Épique", domain: "order", artist: "Six More Vodka", price: 6.8, hash: "7b71cf13a07074a6eccbe88ae6c74133d989cb68-744x1039.png" },
  { id: "ogn-080", en: "Mystic Reversal", fr: "Renversement mystique", code: "OGN-080/298", type: "spell", typeFr: "Sort", typeEn: "Spell", rarity: "Épique", domain: "calm", artist: "Polar Engine Studio", price: 2.4, hash: "298fe91f9d76086b7d77880e11016ed46389b61b-744x1039.png" },
  { id: "ogn-040", en: "Seal of Rage", fr: "Sceau de rage", code: "OGN-040/298", type: "gear", typeFr: "Équipement", typeEn: "Gear", rarity: "Épique", domain: "fury", artist: "Kudos Productions", price: 1.9, hash: "fbdd14adb40b0ca46b89f476a356fa21413d812e-744x1039.png" },
  { id: "ogn-007", en: "Fury Rune", fr: "Rune de Fureur", code: "OGN-007/298", type: "rune", typeFr: "Rune", typeEn: "Rune", rarity: "Commun", domain: "fury", artist: "G. Ghielmetti & L. Chen", price: 0.3, hash: "12bcd0cde5d9ff4640e82945001e9fef863530f1-744x1039.png" },
  { id: "ogn-247", en: "Daughter of the Void", fr: "Fille du Néant", code: "OGN-247/298", type: "legend", typeFr: "Légende", typeEn: "Legend", rarity: "Rare", domain: "fury", artist: "Kudos Productions", price: 4.2, hash: "a576472c7bb00f475882ac814e1d8f9be233b402-744x1040.png" },
  { id: "ogn-275", en: "Altar to Unity", fr: "Autel de l'Unité", code: "OGN-275/298", type: "battlefield", typeFr: "Champ de bataille", typeEn: "Battlefield", rarity: "Peu commun", domain: "colorless", artist: "Kudos Productions", price: 0.9, landscape: true, hash: "2392529560dc9af72596c6fc65b4c0356bbc44d1-1038x744.png" },
  { id: "ogn-276", en: "Aspirant's Climb", fr: "Ascension de l'Aspirant", code: "OGN-276/298", type: "battlefield", typeFr: "Champ de bataille", typeEn: "Battlefield", rarity: "Peu commun", domain: "colorless", artist: "Polar Engine Studio", price: 0.7, landscape: true, hash: "9301593f3800e68427469d38181b578a672473c3-1038x744.png" }
];

const lang = () => document.body.dataset.lang || "fr";
const cardName = c => (lang() === "fr" ? c.fr : c.en);
const cardType = c => (lang() === "fr" ? c.typeFr : c.typeEn);
const euro = v => v.toFixed(2).replace(".", ",") + " €";

/* ---------- Bascule FR / EN ---------- */
document.querySelectorAll(".lang-switch button").forEach(btn => {
  btn.addEventListener("click", () => {
    document.body.dataset.lang = btn.dataset.lang;
    document.querySelectorAll(".lang-switch button").forEach(b =>
      b.setAttribute("aria-pressed", String(b === btn)));
    document.dispatchEvent(new CustomEvent("langchange"));
  });
});

/* ---------- Galerie (cartes.html) ---------- */
const gallery = document.querySelector("[data-gallery]");
if (gallery) {
  const state = { domain: null, type: null, q: "" };

  const render = () => {
    const cards = CARDS.filter(c =>
      (!state.domain || c.domain === state.domain) &&
      (!state.type || c.type === state.type) &&
      (!state.q || (c.fr + " " + c.en + " " + c.code).toLowerCase().includes(state.q)));

    gallery.innerHTML = cards.map(c => `
      <a class="card-tile${c.landscape ? " landscape" : ""}" href="carte.html" aria-label="${cardName(c)}">
        <img src="${img(c.hash)}" alt="Carte Riftbound : ${c.en} (${c.code})" loading="lazy" />
        <div class="t-name">${cardName(c)}</div>
        <div class="t-meta"><span>${c.code}</span><span class="t-price">${euro(c.price)}</span></div>
        <div class="t-meta"><span>${cardType(c)} · ${c.rarity}</span>
          <span style="color:${DOMAINS[c.domain].color}">${DOMAINS[c.domain][lang()]}</span></div>
      </a>`).join("");

    const count = document.querySelector("[data-count]");
    if (count) count.textContent = lang() === "fr"
      ? `${cards.length} carte${cards.length > 1 ? "s" : ""} · jeu d'exemple (galerie complète : 1 190 cartes via l'API Riot)`
      : `${cards.length} card${cards.length > 1 ? "s" : ""} · sample set (full gallery: 1,190 cards via the Riot API)`;
  };

  document.querySelectorAll("[data-filter-domain]").forEach(f =>
    f.addEventListener("click", () => {
      state.domain = state.domain === f.dataset.filterDomain ? null : f.dataset.filterDomain;
      document.querySelectorAll("[data-filter-domain]").forEach(b =>
        b.setAttribute("aria-pressed", String(b.dataset.filterDomain === state.domain)));
      render();
    }));

  document.querySelectorAll("[data-filter-type]").forEach(f =>
    f.addEventListener("click", () => {
      state.type = state.type === f.dataset.filterType ? null : f.dataset.filterType;
      document.querySelectorAll("[data-filter-type]").forEach(b =>
        b.setAttribute("aria-pressed", String(b.dataset.filterType === state.type)));
      render();
    }));

  const input = document.querySelector("[data-search]");
  input?.addEventListener("input", e => { state.q = e.target.value.trim().toLowerCase(); render(); });

  document.addEventListener("langchange", render);
  render();
}

/* ---------- Boutons like (communauté / decks) ---------- */
document.querySelectorAll("[data-like]").forEach(btn => {
  btn.addEventListener("click", () => {
    const liked = btn.getAttribute("aria-pressed") === "true";
    const n = btn.querySelector("span");
    btn.setAttribute("aria-pressed", String(!liked));
    if (n) n.textContent = Number(n.textContent) + (liked ? -1 : 1);
  });
});

/* ---------- Raccourci recherche ---------- */
document.addEventListener("keydown", e => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
    const input = document.querySelector("[data-search]");
    if (input) { e.preventDefault(); input.focus(); }
  }
});
