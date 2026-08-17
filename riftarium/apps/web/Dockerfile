# Contexte de build : racine du dépôt (voir compose.yaml) — les données des
# règles (le-codex/data) sont servies sous /data/ pour la page Règles.
FROM node:26-alpine AS build
WORKDIR /build
COPY riftarium/apps/web/package.json riftarium/apps/web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY riftarium/apps/web/index.html riftarium/apps/web/vite.config.js ./
COPY riftarium/apps/web/src/ src/
RUN npm run build

FROM nginx:1.27-alpine
COPY riftarium/apps/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /build/dist /usr/share/nginx/html
COPY le-codex/data/rules-fr.json /usr/share/nginx/html/data/rules-fr.json
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
