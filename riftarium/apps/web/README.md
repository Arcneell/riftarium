# Riftarium — site web (Vue 3)

Site Vue 3 + Vite servi par nginx (proxy `/api`). Commandes : voir `WORKFLOW.md` §5
(`npm run check` avant de pousser).

## Charte « Forge noxienne »

Spec complète : `docs/superpowers/specs/2026-10-06-refonte-forge-noxienne-design.md`.
Cette charte est aussi la référence du futur réalignement de l'app Flutter.

### Règles d'usage

- **Pas de style de composant dans une vue.** Une vue ne contient que sa mise en
  page (grilles, espacements) dans son `<style scoped>`. Boutons, champs, onglets,
  modales, feuilles et texte de jeu viennent de `src/ui/`.
- **Seuls trois fichiers sont globaux** : `src/styles/tokens.css` (toutes les
  couleurs, polices, espacements et dimensions), `fonts.css` et `base.css` (reset,
  liens, focus, glyphes `.rb-glyph` et pastilles `.rb-kw`). `src/assets/main.css`
  est l'ancienne feuille, en cours de démantèlement : n'y ajoutez rien.
- **Visuels de jeu officiels obligatoires** : énergie, puissance, runes et
  épuisement en glyphes Riot, mots-clés en pastilles colorées par famille, via
  `RiftText` (`tag="p"` pour une carte, `rules` pour le texte des règles). Jamais
  de « 5 énergie » en texte.
- **Couleurs** : `--blood` pour l'action principale, `--blood-text` pour un accent
  dans du texte courant, `--blood-bright` seulement pour les grands titres et les
  graphismes, `--bronze` pour les filets, `--bronze-light` pour les intertitres et
  les prix, `--ink` / `--ink-muted` pour le texte. Le contraste des tokens de texte
  est vérifié par `src/styles/tokens.spec.js`.
- **Typographie** : Cinzel (`--font-display`) pour les titres et les chiffres-clés,
  Barlow Condensed en capitales espacées (`--font-label`) pour les étiquettes, la
  navigation et les boutons, Barlow (`--font-body`) pour le texte.
- **Habillage Forgé** : angles coupés (`--cut`), boutons principaux biseautés,
  filets de bronze, liseré rouge. Pas d'arrondi marqué hors illustrations de cartes.
- **Effets ciblés seulement** : reflet foil au survol des cartes rares et showcase,
  entrée du splash, défilement lent du mur de cartes, éclat rouge à l'ajout d'une
  carte, transitions de 150 à 200 ms. Tout est coupé par `prefers-reduced-motion`.

### Composants `src/ui/`

| Composant | Usage |
| --- | --- |
| `RiftButton` | `variant` primary / secondary / ghost, `size` sm / md, `to` ou `href` |
| `RiftField` | champ avec label (masquable), `search`, `error` ; attributs transmis à l'`<input>` |
| `RiftTabs` | onglets de sous-rubriques liés aux routes (`items: [{ label, to }]`) |
| `RiftSegments` | onglets dans une page (`tablist`, `items: [{ value, label, badge? }]`, `v-model`, `label`, `id-base`) ; les panneaux restent à la page |
| `RiftModal` | modale accessible (`title`, `wide`, `@close`) |
| `RiftSheet` | feuille du bas sur téléphone (`title`, `@close`) |
| `RiftText` / `RiftGlyph` | texte de jeu enrichi |
| `useDialog` | pile de dialogues, piège à focus, Échap, verrou de défilement |

### Coquille `src/shell/`

`navigation.js` est la table unique des rubriques : rail (`AppRail`), onglets
mobiles (`AppTabbar`), sous-onglets, fil d'Ariane (`AppTopbar`) et groupe « Pages »
de la recherche (`SearchPalette`, logique dans `src/search/search.js`). Une page peut
fournir le dernier maillon du fil d'Ariane avec `setPageCrumb(nom)`
(`src/shell/pageCrumb.js`).

### Decks `src/decks/`

Pièces des pages `DecksView`, `CommunityView` et `DeckEditView` : fiches (`DeckCard`),
filtres de la communauté, galerie, liste du deck et glisser-déposer (`useDeckDrag`),
barre d'édition, analyse, export, cartes manquantes, lecture (`DeckView`, `DeckVisual`).
Chaque pièce a son préfixe de classes (`deck-card-`, `atelier-`, `galerie-`,
`decklist-`, `analyse-`, `lecture-`, `communaute-`, `mesdecks-`, `legalite-`).
