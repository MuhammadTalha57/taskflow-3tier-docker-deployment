# syntax=docker/dockerfile:1

# ---------- Stage 1: deps ----------
# Installs ONLY production dependencies in an isolated stage.
# Copying package*.json before the rest of the source lets Docker cache this
# layer — as long as package.json/package-lock.json don't change, this stage
# won't re-run even if application code changes.
FROM node:20.15.1-alpine3.20 AS deps

WORKDIR /app

COPY package.json package-lock.json* ./

# npm ci is deterministic (uses the lockfile exactly) and --omit=dev skips
# devDependencies entirely, so nothing extra ends up in node_modules.
RUN npm ci --omit=dev


# ---------- Stage 2: runtime ----------
# Slim final image: only the pruned node_modules from Stage 1 + app source.
# No build tools, no dev dependencies, no npm cache.
FROM node:20.15.1-alpine3.20 AS runtime

# Create a dedicated non-root user/group to run the app.
# node:alpine already ships a "node" user (uid 1000), but we create our own
# for explicitness/portability across base image changes.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

ENV NODE_ENV=production \
    PORT=4000

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# Ensure the app directory is owned by the non-root user before dropping privileges.
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 4000

# Docker/Compose will mark the container unhealthy if this fails 3x in a row
# (interval/timeout/retries can be overridden in compose).
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD ["node", "src/healthcheck.js"]

CMD ["node", "src/server.js"]
