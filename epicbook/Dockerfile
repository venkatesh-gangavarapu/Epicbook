# ─────────────────────────────────────────────
# Stage 1 — Dependencies
# Install production npm packages only
# Dev tools, test frameworks left behind
# ─────────────────────────────────────────────
FROM node:18-alpine AS deps

WORKDIR /app

# Copy lock files FIRST — maximises Docker layer cache
# npm ci only re-runs when package.json changes
# Source file changes skip this layer entirely
COPY package.json package-lock.json ./

RUN npm ci --omit=dev --silent

# ─────────────────────────────────────────────
# Stage 2 — Runtime
# Lean production image
# No npm, no build tools, no dev dependencies
# Expected size: ~180MB vs ~1GB single-stage
# ─────────────────────────────────────────────
FROM node:18-alpine AS runtime

# dumb-init: correct signal handling (Docker stop works cleanly)
# mysql-client: needed by entrypoint seed scripts
# netcat-openbsd: nc command for MySQL readiness check
RUN apk add --no-cache dumb-init mysql-client netcat-openbsd

WORKDIR /app

# Non-root user — security best practice
RUN addgroup -g 1001 -S nodejs && \
    adduser  -S epicbook -u 1001 -G nodejs

# Copy production node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy full application source
COPY . .

# Overwrite config with our production-ready version
# This sets host=mysql (Docker service name, not localhost)
COPY config/config.json ./config/config.json

# Make entrypoint executable and set ownership
RUN chmod +x /app/docker-entrypoint.sh && \
    chown -R epicbook:nodejs /app

USER epicbook

EXPOSE 8080

ENV NODE_ENV=production

ENTRYPOINT ["dumb-init", "--", "/app/docker-entrypoint.sh"]
CMD ["node", "server.js"]

# Health check — confirms app port is open
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=60s \
  CMD nc -z localhost 8080 || exit 1
