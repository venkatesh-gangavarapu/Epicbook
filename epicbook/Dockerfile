# ─────────────────────────────────────────────
# Stage 1 — Dependencies
# Install production npm packages only
# ─────────────────────────────────────────────
FROM node:18-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --silent

# ─────────────────────────────────────────────
# Stage 2 — Runtime
# ~180MB vs ~1GB single-stage
# mariadb-client used (Alpine ships MariaDB, not MySQL client)
# ─────────────────────────────────────────────
FROM node:18-alpine AS runtime

RUN apk add --no-cache dumb-init mariadb-client netcat-openbsd

WORKDIR /app

RUN addgroup -g 1001 -S nodejs && \
    adduser  -S epicbook -u 1001 -G nodejs

COPY --from=deps /app/node_modules ./node_modules
COPY . .
COPY config/config.json ./config/config.json

RUN chmod +x /app/docker-entrypoint.sh && \
    chown -R epicbook:nodejs /app

USER epicbook

EXPOSE 8080

ENV NODE_ENV=production

ENTRYPOINT ["dumb-init", "--", "/app/docker-entrypoint.sh"]
CMD ["node", "server.js"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=60s \
  CMD nc -z localhost 8080 || exit 1
