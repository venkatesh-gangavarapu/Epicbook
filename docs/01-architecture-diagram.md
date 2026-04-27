# 01 — Architecture Diagram

Replace this file with a screenshot or diagram image named `01-architecture-diagram.png`

## Architecture (Text Reference)

```
Internet
    │
    ▼ port 80 (only public port)
┌─────────────────────────────────────────────────────────────┐
│  AZURE VM — vm-epicbook-capstone (Standard_B2s)             │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Docker Compose Stack                                 │  │
│  │                                                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  epicbook-nginx (nginx:alpine)                  │  │  │
│  │  │  port 80 → host                                 │  │  │
│  │  │  logs/nginx/ → bind mount on host               │  │  │
│  │  └──────────────────┬──────────────────────────────┘  │  │
│  │                     │ frontend-net                    │  │
│  │                     ▼ port 8080 (internal)            │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  epicbook-app (node:18-alpine)                  │  │  │
│  │  │  Express + Handlebars + Sequelize               │  │  │
│  │  │  seeds DB on first run via entrypoint           │  │  │
│  │  └──────────────────┬──────────────────────────────┘  │  │
│  │                     │ backend-net                     │  │
│  │                     ▼ port 3306 (internal)            │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  epicbook-mysql (mysql:8.0)                     │  │  │
│  │  │  db_data → named volume                        │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  NSG Rules: allow 22 (SSH) + 80 (HTTP) only                 │
└─────────────────────────────────────────────────────────────┘
```

## Network Separation

```
frontend-net:  nginx ↔ epicbook   (public-facing proxy)
backend-net:   epicbook ↔ mysql   (internal data layer)

MySQL has NO route to frontend-net
nginx has NO route to backend-net
```

## Startup Order

```
mysql (healthy) → epicbook (healthy) → nginx (healthy)
```
