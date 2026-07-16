# syntax=docker/dockerfile:1

# ---------- Stage 1: build ----------
# Compiles the React app into static assets. Node, source code, and
# node_modules all stay in this stage and never reach the final image.
FROM node:20.15.1-alpine3.20 AS build

WORKDIR /app

# Copy manifests first so `npm ci` is cached unless dependencies actually change.
COPY package.json package-lock.json* ./
RUN npm ci

COPY . .

# Build-time API base URL. Vite inlines VITE_ prefixed vars into the JS
# bundle at build time — pass --build-arg VITE_API_BASE_URL=... to override.
# Defaults to /api, which nginx.conf reverse-proxies to the backend service,
# so no absolute URL/CORS setup is needed in the common case.
ARG VITE_API_BASE_URL=/api
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

RUN npm run build


# ---------- Stage 2: runtime ----------
# Only the compiled static output + a minimal nginx server. No Node,
# no node_modules, no source code in the final image.
FROM nginx:1.27.1-alpine AS runtime

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

# Non-root: nginx:alpine already provisions an "nginx" user/group.
# Grant it ownership of everything it needs to write to at runtime.
RUN mkdir -p /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp \
  && chown -R nginx:nginx /usr/share/nginx/html /tmp /var/cache/nginx /etc/nginx

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
