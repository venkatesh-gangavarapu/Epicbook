# 04 — Proxy Routing & CORS

## Nginx Routing

All incoming traffic on port 80 is handled by nginx. There is only
one upstream — the EpicBook app which serves both views and API.

```
Browser → http://<public_ip>:80
              │
              ▼
         nginx (port 80)
              │
              │ proxy_pass http://epicbook:8080
              ▼
         epicbook-app (port 8080)
              │
              │ Sequelize → mysql:3306
              ▼
         epicbook-mysql
```

### nginx.conf Routes

```nginx
upstream epicbook_backend {
    server epicbook:8080;    # Docker service name — internal DNS
}

server {
    listen 80;

    location / {
        proxy_pass http://epicbook_backend;
        proxy_set_header Host             $host;
        proxy_set_header X-Real-IP        $remote_addr;
        proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
    }

    location /nginx-health {
        return 200 "healthy\n";
    }
}
```

EpicBook is a monolithic Express app — it handles both HTML views
(Handlebars) and API routes from the same server on port 8080.
No separate routing for `/api` vs `/` is needed at the proxy level.

---

## Why `epicbook:8080` Not `localhost:8080`

nginx and epicbook run in **separate containers**. Inside the nginx container,
`localhost` refers to nginx itself — not the app. Docker Compose provides
internal DNS so `epicbook` resolves to the epicbook container's IP automatically.

```
nginx container:    localhost = nginx itself
                    epicbook  = epicbook container (via Docker DNS)
```

---

## Security Headers

Added to every response via nginx:

```nginx
add_header X-Frame-Options        "SAMEORIGIN"    always;
add_header X-Content-Type-Options "nosniff"       always;
add_header X-XSS-Protection       "1; mode=block" always;
```

| Header | Purpose |
|---|---|
| `X-Frame-Options: SAMEORIGIN` | Prevents clickjacking — page cannot be embedded in iframes |
| `X-Content-Type-Options: nosniff` | Prevents MIME type sniffing attacks |
| `X-XSS-Protection` | Enables browser XSS filter (legacy but still useful) |

---

## CORS

EpicBook is a server-rendered application using Handlebars templates.
All pages and API calls are served from the same origin (same host, same port).

**Same-origin requests do not trigger CORS** — the browser does not send
a preflight `OPTIONS` request because the frontend and API share the same domain.

If a separate frontend (React/Vue) were added on a different origin,
CORS would need to be configured in `server.js`:

```javascript
const cors = require('cors');
app.use(cors({
  origin: ['http://<public_ip>', 'https://yourdomain.com'],
  credentials: true
}));
```

For this deployment — CORS configuration is not required.

---

## Proxy Timeout Settings

```nginx
proxy_connect_timeout 60s;
proxy_send_timeout    60s;
proxy_read_timeout    60s;
```

These prevent nginx from dropping slow requests during DB-heavy operations
like the initial book listing query.
