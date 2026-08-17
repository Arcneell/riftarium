// Symboles de domaine officiels servis par le CDN de Riot (cf. tools/build_assets.py).
const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live";
const DOMAIN_CHIPS = {
  R: { color: "var(--fury)", label: "Fureur", icon: `${CDN}/5aeb4bfd203b5d265902f65aa5afae7da1682eaa-64x64.png?accountingTag=RB` },
  G: { color: "var(--calm)", label: "Calme", icon: `${CDN}/b9ef2f5b74841ad11f3629aa381a76ac0187d007-64x64.png?accountingTag=RB` },
  B: { color: "var(--mind)", label: "Esprit", icon: `${CDN}/17ab95a6bd052085b6803d846a287f625f347288-64x64.png?accountingTag=RB` },
  O: { color: "var(--body)", label: "Corps", icon: `${CDN}/7a5533034de5870808347bc4b296f0029bdd8eea-64x64.png?accountingTag=RB` },
  P: { color: "var(--chaos)", label: "Chaos", icon: `${CDN}/597ddb82be59e87b467c52bb10204f02c2005d06-64x64.png?accountingTag=RB` },
  Y: { color: "var(--order)", label: "Ordre", icon: `${CDN}/8bb1b193a8e1adc26ca28e1a21da8d1e2f5d2f72-64x64.png?accountingTag=RB` }
};

const state = { doc: "core", section: null, rule: null };
let documents = null;
const searchIndex = [];
const locate = new Map();

const main = document.querySelector(".reader-main");
const tocTree = document.querySelector(".toc-tree");
const tocPanel = document.querySelector("#toc");
const tocScrim = document.querySelector(".toc-scrim");
const docSwitch = document.querySelector(".doc-switch");
const docMeta = document.querySelector(".doc-meta");
const searchInput = document.querySelector("#search");
const searchPanel = document.querySelector(".search-panel");
const searchHits = document.querySelector(".search-hits");
const searchCount = document.querySelector(".search-count");

const escapeHtml = value => value.replace(/[&<>"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[char]);
// Repli caractère par caractère : l'index reste aligné sur le texte d'origine,
// ce qui permet de surligner les correspondances accentuées au bon endroit.
const normalize = value => value.replace(/./gu, char => {
  const folded = char.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  return folded.length === char.length ? folded : char.toLowerCase();
});
const bare = number => number.replace(/\.$/, "");

function formatText(text) {
  let html = escapeHtml(text);
  html = html.replace(/\[([A-Z0-9]{1,3})\]/g, (match, token) => {
    const domain = DOMAIN_CHIPS[token];
    if (domain) {
      return `<span class="chip chip-domain" style="--chip:${domain.color}" title="Domaine ${domain.label}"><img src="${domain.icon}" width="16" height="16" loading="lazy" alt="${domain.label}" />${token}</span>`;
    }
    const color = /^\d+$/.test(token) ? "#8b95b2" : "var(--accent)";
    return `<span class="chip" style="--chip:${color}">${token}</span>`;
  });
  return html.replace(
    /\b(règles?|sections?)\s+(\d{3}(?:\.\d+)*(?:\.[a-z])?(?:\.\d+)*)/gi,
    (match, word, number) => `<button class="xref" data-ref="${bare(number)}">${word} ${number}</button>`
  );
}

function buildIndex() {
  Object.entries(documents).forEach(([docKey, doc]) => {
    doc.chapters.forEach(chapter => {
      locate.set(`${docKey}:${bare(chapter.number)}`, { doc: docKey, section: chapter.sections[0]?.id });
      chapter.sections.forEach(section => {
        locate.set(`${docKey}:${bare(section.number)}`, { doc: docKey, section: section.id });
        section.entries.forEach(entry => {
          locate.set(`${docKey}:${bare(entry.number)}`, { doc: docKey, section: section.id, rule: entry.id });
          searchIndex.push({
            doc: docKey,
            docTitle: doc.title,
            section: section.id,
            path: `${chapter.title} › ${section.number} ${section.title}`,
            number: entry.number,
            id: entry.id,
            text: entry.text,
            haystack: normalize(`${entry.number} ${entry.text} ${entry.examples.map(e => e.text).join(" ")}`)
          });
        });
      });
    });
  });
}

function sectionsOf(docKey) {
  return documents[docKey].chapters.flatMap(chapter =>
    chapter.sections.map(section => ({ ...section, chapter }))
  );
}

function findSection(docKey, sectionId) {
  return sectionsOf(docKey).find(section => section.id === sectionId);
}

function renderDocSwitch() {
  docSwitch.innerHTML = Object.entries(documents)
    .map(([key, doc]) => `<button role="tab" data-doc="${key}" aria-selected="${key === state.doc}">${doc.title}</button>`)
    .join("");

  const doc = documents[state.doc];
  docMeta.innerHTML = `<strong>${doc.subtitle}</strong>Mis à jour le ${doc.updated} · ${doc.ruleCount} règles<br /><a href="${doc.source}" target="_blank" rel="noopener">Voir le PDF officiel ↗</a>`;
}

function renderToc() {
  tocTree.innerHTML = documents[state.doc].chapters
    .map(chapter => {
      const open = chapter.sections.some(section => section.id === state.section);
      const sections = chapter.sections
        .map(section => `<button data-section="${section.id}" aria-current="${section.id === state.section}"><b>${bare(section.number)}</b><span>${section.title}</span></button>`)
        .join("");
      return `<div class="toc-chapter${open ? " open" : ""}">
          <button data-chapter="${chapter.id}"><i>›</i><span>${chapter.title}</span><em>${chapter.sections.length}</em></button>
          <div class="toc-sections">${sections}</div>
        </div>`;
    })
    .join("");

  tocTree.querySelector('[aria-current="true"]')?.scrollIntoView({ block: "nearest" });
}

function renderRule(entry) {
  const examples = entry.examples
    .map(example => `<div class="example"><strong>Exemple</strong><p>${formatText(example.text)}</p></div>`)
    .join("");
  const refs = entry.refs
    .map(ref => `<button class="ref" data-ref="${bare(ref.number)}">→ ${ref.number}. ${escapeHtml(ref.label)}</button>`)
    .join("");

  return `<article class="rule depth-${Math.min(entry.depth, 4)}" id="r-${entry.id}" data-rule="${entry.id}">
      <button class="rule-num" data-copy="${entry.id}" title="Copier le lien vers cette règle">${entry.number}</button>
      <div class="rule-body">
        <p>${formatText(entry.text)}</p>
        ${examples}
        ${refs ? `<div class="refs">${refs}</div>` : ""}
      </div>
    </article>`;
}

function renderSection() {
  const doc = documents[state.doc];
  const all = sectionsOf(state.doc);
  const index = all.findIndex(section => section.id === state.section);
  const section = all[index];

  if (!section) {
    main.innerHTML = `<p class="empty">Section introuvable.</p>`;
    return;
  }

  const previous = all[index - 1];
  const next = all[index + 1];

  main.innerHTML = `
    <div class="breadcrumb"><b>${doc.title}</b> <span>›</span> <span>${section.chapter.number} ${section.chapter.title}</span></div>
    <h1 class="section-title">${section.title}</h1>
    <p class="section-sub">Section ${bare(section.number)} · ${section.entries.length} règles · Texte officiel mis à jour le ${doc.updated}</p>
    <div class="rules">${section.entries.map(renderRule).join("")}</div>
    <nav class="section-nav">
      <button data-goto="${previous?.id ?? ""}" ${previous ? "" : "disabled"}><small>Section précédente</small><strong>${previous ? previous.title : "—"}</strong></button>
      <button data-goto="${next?.id ?? ""}" ${next ? "" : "disabled"}><small>Section suivante</small><strong>${next ? next.title : "—"}</strong></button>
    </nav>
    <p class="reader-legal">Texte reproduit depuis le document officiel « ${doc.title} » de Riftbound (mise à jour du ${doc.updated}), publié par Riot Games. En cas de divergence, le <a href="${doc.source}" target="_blank" rel="noopener">PDF officiel</a> fait foi. Projet fan non commercial, non affilié à Riot Games.</p>
  `;

  const target = state.rule ? main.querySelector(`#r-${CSS.escape(state.rule)}`) : null;
  if (target) {
    target.classList.add("target");
    target.scrollIntoView({ block: "center", behavior: "smooth" });
  } else {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}

function render() {
  renderDocSwitch();
  renderToc();
  renderSection();
}

function navigate(docKey, sectionId, ruleId = null, push = true) {
  state.doc = docKey;
  state.section = sectionId;
  state.rule = ruleId;
  if (push) {
    const hash = `#${docKey}/${sectionId}${ruleId ? `/${ruleId}` : ""}`;
    if (location.hash !== hash) history.pushState(null, "", hash);
  }
  render();
  closeToc();
}

function followRef(number) {
  const hit = locate.get(`${state.doc}:${number}`) ?? locate.get(`core:${number}`) ?? locate.get(`tournament:${number}`);
  if (hit) navigate(hit.doc, hit.section, hit.rule ?? null);
}

function highlight(raw, tokens) {
  const folded = normalize(raw);
  const spans = [];

  tokens.forEach(token => {
    let position = folded.indexOf(token);
    while (position !== -1) {
      spans.push([position, position + token.length]);
      position = folded.indexOf(token, position + token.length);
    }
  });

  spans.sort((a, b) => a[0] - b[0]);
  const merged = [];
  spans.forEach(span => {
    const last = merged[merged.length - 1];
    if (last && span[0] <= last[1]) last[1] = Math.max(last[1], span[1]);
    else merged.push([...span]);
  });

  let html = "";
  let cursor = 0;
  merged.forEach(([start, end]) => {
    html += `${escapeHtml(raw.slice(cursor, start))}<mark>${escapeHtml(raw.slice(start, end))}</mark>`;
    cursor = end;
  });
  return html + escapeHtml(raw.slice(cursor));
}

function snippet(entry, tokens) {
  const folded = normalize(entry.text);
  const first = tokens.map(token => folded.indexOf(token)).filter(position => position >= 0).sort((a, b) => a - b)[0] ?? 0;
  const start = Math.max(0, first - 70);
  const slice = entry.text.slice(start, start + 230);
  const prefix = start > 0 ? "… " : "";
  const suffix = start + 230 < entry.text.length ? " …" : "";
  return prefix + highlight(slice, tokens) + suffix;
}

function runSearch(query) {
  const trimmed = query.trim();
  if (trimmed.length < 2) {
    searchPanel.hidden = true;
    return;
  }

  const tokens = normalize(trimmed).split(/\s+/).filter(Boolean);
  const matches = searchIndex.filter(entry => tokens.every(token => entry.haystack.includes(token)));
  matches.sort((a, b) => Number(a.haystack.startsWith(tokens[0])) === Number(b.haystack.startsWith(tokens[0])) ? 0 : Number(b.haystack.startsWith(tokens[0])) - Number(a.haystack.startsWith(tokens[0])));

  searchPanel.hidden = false;
  searchCount.textContent = matches.length
    ? `${matches.length} règle${matches.length > 1 ? "s" : ""} trouvée${matches.length > 1 ? "s" : ""}`
    : "Aucun résultat";
  searchHits.innerHTML = matches
    .slice(0, 60)
    .map(entry => `<button class="hit" data-doc="${entry.doc}" data-section="${entry.section}" data-rule="${entry.id}">
        <span class="hit-top"><span class="hit-num">${entry.number}</span><span class="hit-path">${escapeHtml(entry.docTitle)} › ${escapeHtml(entry.path)}</span></span>
        <span class="hit-text">${snippet(entry, tokens)}</span>
      </button>`)
    .join("");
}

function openToc() {
  tocPanel.classList.add("open");
  tocScrim.hidden = false;
  document.querySelector(".toc-trigger").setAttribute("aria-expanded", "true");
}

function closeToc() {
  tocPanel.classList.remove("open");
  tocScrim.hidden = true;
  document.querySelector(".toc-trigger").setAttribute("aria-expanded", "false");
}

function readHash() {
  const [docKey, sectionId, ruleId] = location.hash.replace(/^#/, "").split("/");
  if (documents[docKey]) {
    const section = findSection(docKey, sectionId) ? sectionId : sectionsOf(docKey)[0].id;
    return { doc: docKey, section, rule: ruleId ?? null };
  }
  return { doc: "core", section: sectionsOf("core")[0].id, rule: null };
}

tocTree.addEventListener("click", event => {
  const chapter = event.target.closest("[data-chapter]");
  if (chapter) {
    chapter.parentElement.classList.toggle("open");
    return;
  }
  const section = event.target.closest("[data-section]");
  if (section) navigate(state.doc, section.dataset.section);
});

docSwitch.addEventListener("click", event => {
  const button = event.target.closest("[data-doc]");
  if (button) navigate(button.dataset.doc, sectionsOf(button.dataset.doc)[0].id);
});

main.addEventListener("click", event => {
  const goto = event.target.closest("[data-goto]");
  if (goto && goto.dataset.goto) {
    navigate(state.doc, goto.dataset.goto);
    return;
  }

  const ref = event.target.closest("[data-ref]");
  if (ref) {
    followRef(ref.dataset.ref);
    return;
  }

  const copy = event.target.closest("[data-copy]");
  if (copy) {
    const url = `${location.origin}${location.pathname}#${state.doc}/${state.section}/${copy.dataset.copy}`;
    history.replaceState(null, "", `#${state.doc}/${state.section}/${copy.dataset.copy}`);
    navigator.clipboard?.writeText(url);
    const original = copy.textContent;
    copy.textContent = "copié !";
    setTimeout(() => { copy.textContent = original; }, 1200);
  }
});

searchHits.addEventListener("click", event => {
  const hit = event.target.closest(".hit");
  if (!hit) return;
  searchPanel.hidden = true;
  searchInput.value = "";
  navigate(hit.dataset.doc, hit.dataset.section, hit.dataset.rule);
});

let searchTimer;
searchInput.addEventListener("input", event => {
  clearTimeout(searchTimer);
  const value = event.target.value;
  searchTimer = setTimeout(() => runSearch(value), 140);
});

document.addEventListener("keydown", event => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    event.preventDefault();
    searchInput.focus();
    searchInput.select();
  }
  if (event.key === "Escape") {
    searchPanel.hidden = true;
    searchInput.blur();
    closeToc();
  }
});

document.querySelector(".toc-trigger").addEventListener("click", () => {
  tocPanel.classList.contains("open") ? closeToc() : openToc();
});
tocScrim.addEventListener("click", closeToc);

window.addEventListener("popstate", () => {
  const next = readHash();
  navigate(next.doc, next.section, next.rule, false);
});

fetch("/data/rules-fr.json")
  .then(response => response.json())
  .then(payload => {
    documents = payload;
    buildIndex();
    const initial = readHash();
    navigate(initial.doc, initial.section, initial.rule, false);

    const query = new URLSearchParams(location.search).get("q");
    if (query) {
      searchInput.value = query;
      runSearch(query);
    }
  })
  .catch(() => {
    main.innerHTML = `<p class="empty">Impossible de charger les règles. Vérifiez que le fichier <code>/data/rules-fr.json</code> est bien servi.</p>`;
  });
