FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html debuter.html regles.html /usr/share/nginx/html/
COPY style.css learn.css reader.css /usr/share/nginx/html/
COPY app.js learn.js reader.js /usr/share/nginx/html/
COPY data/ /usr/share/nginx/html/data/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
