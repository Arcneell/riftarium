# Contexte de build : racine du dépôt (voir compose.yaml) — le module Règles
# (le-codex) est embarqué tel quel sous /regles/.
FROM node:22-alpine AS build
WORKDIR /build
COPY riftarium/apps/web/package.json ./
RUN npm install --no-audit --no-fund
COPY riftarium/apps/web/index.html riftarium/apps/web/vite.config.js ./
COPY riftarium/apps/web/src/ src/
RUN npm run build

FROM nginx:1.27-alpine
COPY riftarium/apps/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /build/dist /usr/share/nginx/html
COPY le-codex/index.html le-codex/regles.html le-codex/debuter.html \
     le-codex/reader.css le-codex/reader.js le-codex/learn.css le-codex/learn.js \
     le-codex/style.css le-codex/app.js \
     /usr/share/nginx/html/regles/
COPY le-codex/data/ /usr/share/nginx/html/data/
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
