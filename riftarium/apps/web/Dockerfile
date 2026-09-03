# Contexte de build : racine de riftarium/ (voir compose.yaml) — les données des
# règles (data/) sont servies sous /data/ pour la page Règles.
FROM node:26-alpine AS build
WORKDIR /build
COPY apps/web/package.json apps/web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/web/index.html apps/web/vite.config.js ./
COPY apps/web/public/ public/
COPY apps/web/src/ src/
RUN npm run build

FROM nginx:1.31-alpine
COPY apps/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /build/dist /usr/share/nginx/html
COPY data/rules-fr.json /usr/share/nginx/html/data/rules-fr.json
RUN sed -i '/^user /d' /etc/nginx/nginx.conf \
    && sed -i 's|pid .*|pid /tmp/nginx.pid;|' /etc/nginx/nginx.conf \
    && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx/conf.d \
    && install -d -o nginx -g nginx /tmp
USER nginx
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:8080/ || exit 1
