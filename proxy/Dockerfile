FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy our reverse proxy config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Fix log directory permissions
# nginx inside Alpine runs as uid 101 (nginx user)
# This ensures the bind-mounted ./logs/nginx is writable
RUN mkdir -p /var/log/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chmod -R 755 /var/log/nginx

EXPOSE 80

# Health check — confirms nginx is serving
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/nginx-health || exit 1
