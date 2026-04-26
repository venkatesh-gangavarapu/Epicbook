FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy our reverse proxy config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Health check — confirms nginx is serving
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/nginx-health || exit 1
