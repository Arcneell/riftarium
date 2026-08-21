# Polices embarquées (image de partage)

Utilisées uniquement côté serveur par `app/og.py` pour dessiner l'aperçu Discord /
réseaux sociaux d'un deck (Pillow ne sait pas lire les `.woff2` du front).

| Fichier | Famille | Licence |
| --- | --- | --- |
| `Marcellus-Regular.ttf` | Marcellus — police d'affichage du site | SIL OFL 1.1 (`OFL-Marcellus.txt`) |
| `IBMPlexMono-Regular.ttf`, `IBMPlexMono-SemiBold.ttf` | IBM Plex Mono — police mono du site | SIL OFL 1.1 (`OFL-IBMPlexMono.txt`) |

Source : dépôt `google/fonts` (`ofl/marcellus`, `ofl/ibmplexmono`). Les mêmes familles
sont servies au navigateur en `.woff2` depuis `apps/web/src/assets/fonts/`.
