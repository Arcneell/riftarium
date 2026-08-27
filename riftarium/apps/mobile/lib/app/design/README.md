# Système de design Riftarium mobile

Transposition mobile de la charte du site (`apps/web/src/assets/main.css`).
Tout écran passe par ces briques ; pas de couleur ni de police hors tokens.

## Voix

- **Matière** : parchemin (`RiftColors.paper`) et encre bleu nuit (`ink`). L'or
  (`gold`) est l'accent : titres, filets, bouton principal. Le hex (sarcelle,
  `hex`) marque l'interaction : liens, focus, action secondaire. Les six domaines
  ont leur couleur (`RiftColors.domain(name)`), le prisme (`prism`) sert aux
  barres de progression.
- **Typo** (`riftText(context)`) : Marcellus pour les titres (`displayLarge/
  Medium/Small`), Outfit pour le texte (`body`, `bodyStrong`, `small`, `title`),
  IBM Plex Mono pour les données (`mono`, `monoStrong`, `eyebrow`). Sur-titre
  toujours en capitales espacées via `eyebrow`.
- **Formes** : rayons 12 / 18 / 28 (`RiftRadius`), cartes à 10. Ombres douces
  et chaudes (`RiftShadows`). Traits or pâle (`colorScheme.outline`).
- **Mouvement** (`RiftMotion`) : `Reveal` à l'apparition des listes (cascade),
  `PressScale` au toucher, `Hero` grille → fiche (`CardImage.heroTag`),
  `FoilOverlay` sur les cartes possédées (signature), `Shimmer` pendant les
  chargements. Tout respecte `MediaQuery.disableAnimations`.

## Briques (`lib/app/design/`, `lib/app/widgets/`)

| Brique | Usage |
| --- | --- |
| `PageBanner(title, art, eyebrow, actions)` | Premier sliver de chaque écran d'onglet : illustration `RiftBanners.*` fondue dans le parchemin, titre Marcellus. Toujours `CustomScrollView` + `PageBanner` + slivers. |
| `GoldButton` | Action principale, une par écran. `GhostButton` pour la secondaire. |
| `RiftPanel` | Bloc de contenu (stat, cas pratique, deck). `raised: true` pour un panneau cliquable mis en avant. |
| `SectionTitle(title, eyebrow, trailing)` | Titre de section dans une liste. |
| `DomainChip`, `MonoBadge`, `PrismBar`, `GoldRule` | Étiquettes et filets. |
| `CardImage(card, heroTag, foil, thumbWidth)` | Tout visuel de carte. Vignette CDN redimensionnée (`CardArtSize.tile` en grille, `detail` en fiche, `zoom` en plein écran), cache 30 jours, squelette, fondu. `foil: true` pour une carte possédée dans la collection (`foilIntensity` 0.6) ; les variantes foil (`card.foil`) ajoutent la teinte prismatique. |
| `precacheCardThumbs(context, cards)` | À appeler après chaque page chargée pour la page suivante. |
| `Reveal(index, child)` | Envelopper chaque tuile d'une grille / ligne d'une liste. |
| `SignInRequired`, `ErrorView`, `EmptyView`, `LoadingView` | États. `EmptyView` doit inviter à agir (bouton), jamais constater. |
| `ProfileAction` | Avatar en haut à droite des bannières → profil. |

## Règles d'écran

1. Ouvrir par une `PageBanner` (ou, pour une fiche, par le visuel lui-même).
2. Une action principale visible sans défiler (or) ; le reste en `GhostButton`,
   `TextButton` ou icônes.
3. Textes : verbes à l'infinitif sur les boutons (« Ajouter à la collection »),
   phrases courtes, pas de jargon technique. Erreurs : ce qui s'est passé + quoi
   faire. Vides : une invitation.
4. Densité : 18 px de marge latérale (`RiftSpace.page`), 3 colonnes de cartes en
   portrait (2 si largeur < 340), 4 en paysage.
5. iOS garde les gestes et transitions natifs ; l'habillage (couleurs, typo,
   composants) est celui de la marque sur les deux plateformes.
6. Dark mode : automatique via les tokens ; ne jamais coder `Colors.white`
   pour un fond.
