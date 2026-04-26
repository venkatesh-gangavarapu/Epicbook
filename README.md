# EpicBook — Docker Compose Capstone Deployment

> Full production containerization of The EpicBook bookstore using **Docker Compose**, **multi-stage builds**, **named volumes**, **split networks**, **healthchecks**, and **nginx reverse proxy** — deployed on Azure via Terraform with cloud-init.

---

## Architecture

```
Internet
    │
    ▼ port 80 (only public port)
┌─────────────────────────────────────────────┐
│  nginx (reverse proxy)                      │
│  container: epicbook-nginx                  │
│  logs: bind mount → host logs/nginx/        │
└──────────────────┬──────────────────────────┘
                   │ frontend-net (internal)
                   ▼ port 8080
┌─────────────────────────────────────────────┐
│  EpicBook — Node.js/Express                 │
│  container: epicbook-app                    │
│  serves views + REST API via Handlebars     │
│  Sequelize ORM → MySQL                      │
└──────────────────┬──────────────────────────┘
                   │ backend-net (internal)
                   ▼ port 3306
┌─────────────────────────────────────────────┐
│  MySQL 8.0                                  │
│  container: epicbook-mysql                  │
│  volume: db_data (persists across restarts) │
└─────────────────────────────────────────────┘

Public ports:  80 only
Internal only: 8080 (epicbook), 3306 (mysql)
```

---

## Project Structure

```
epicbook-capstone/
├── docker-compose.yml          # Full stack definition
├── .env                        # Secrets — DO NOT commit
├── .gitignore
├── epicbook/
│   ├── Dockerfile              # Multi-stage: deps → runtime
│   ├── .dockerignore
│   ├── docker-entrypoint.sh    # Waits for MySQL + seeds DB
│   └── config/
│       └── config.json         # Production DB config (host=mysql)
├── proxy/
│   ├── Dockerfile              # nginx:alpine + custom config
│   └── nginx.conf              # Reverse proxy + health endpoint
├── logs/
│   └── nginx/                  # Bind mount — nginx logs on host
├── terraform/
│   ├── providers.tf
│   ├── main.tf                 # VM + NSG + cloud-init
│   └── cloud-init.yml          # Docker + Compose installed at boot
└── docs/
    └── 09-runbook.md           # Ops runbook
```

---

## Prerequisites

- Azure CLI authenticated (`az login`)
- Terraform >= 1.0
- SSH ed25519 key at `~/.ssh/id_ed25519`

---

## Deployment Guide

### Step 1 — Provision VM

```bash
cd terraform/
terraform init
terraform plan
terraform apply
# Note: public_ip from output
```

### Step 2 — Copy project to VM

```bash
# From your local machine
scp -r ~/epicbook-capstone azureuser@<public_ip>:~/epicbook-capstone
ssh azureuser@<public_ip>
```

### Step 3 — Clone app source

```bash
cd ~/epicbook-capstone

# Clone the EpicBook source into the epicbook build context
git clone https://github.com/pravinmishraaws/theepicbook epicbook-src

# Copy all source files (our Dockerfile and config stay in place)
rsync -av --exclude='.git' --exclude='config' --exclude='node_modules' \
  epicbook-src/ epicbook/

# Clean up
rm -rf epicbook-src
```

### Step 4 — Start the stack

```bash
cd ~/epicbook-capstone

# Wait for cloud-init to finish (2-3 minutes after VM boot)
sudo cloud-init status

# Bring stack up
docker compose up -d --build

# Watch startup
docker compose logs -f
```

### Step 5 — Verify

```bash
# All containers healthy
docker compose ps

# HTTP check
curl -I http://localhost
# Expected: HTTP/1.1 200 OK

# Open in browser
http://<public_ip>
```

---

## Image Size Comparison

| Stage | Base | Size |
|---|---|---|
| Single-stage (deps + build tools) | node:18 | ~1 GB |
| Multi-stage runtime | node:18-alpine | ~180 MB |
| Reduction | | ~82% |

---

## Key Design Decisions

**Split networks** — MySQL only on `backend-net`. It never touches `frontend-net`. Even if nginx were compromised, it has no route to the database.

**Port isolation** — Only port 80 is published. Ports 8080 and 3306 are internal only. No NSG rule exists for them.

**Healthcheck chain** — `nginx` waits for `epicbook` healthy. `epicbook` waits for `mysql` healthy. The stack starts in the correct order automatically.

**Idempotent seed** — `docker-entrypoint.sh` checks if tables exist before seeding. Restart the container 100 times — it seeds exactly once.

**Bind mount for nginx logs** — `./logs/nginx` is mounted to the host so logs are accessible without `docker exec`. App logs go to a named volume.

---

## Teardown

```bash
cd terraform/
terraform destroy
```

---

## Part of DevOps Micro Internship

Week 14 Capstone — **DevOps Micro Internship** guided by [Pravin Mishra](https://github.com/pravinmishraaws).

---

*Venkatesh Gangavarapu — Senior DevOps Engineer*
