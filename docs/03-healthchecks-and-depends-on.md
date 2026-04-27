# 03 — Healthchecks & Startup Order

## Startup Chain

```
mysql (starts first)
  │
  │ healthcheck: mysqladmin ping
  │ interval: 10s / retries: 5 / start_period: 30s
  ▼
epicbook (waits for mysql: service_healthy)
  │
  │ healthcheck: nc -z localhost 8080
  │ interval: 30s / retries: 3 / start_period: 60s
  ▼
nginx (waits for epicbook: service_healthy)
  │
  │ healthcheck: wget /nginx-health
  │ interval: 30s / retries: 3
  ▼
Stack fully ready
```

`depends_on` with `condition: service_healthy` ensures each service only
starts after the previous one passes its healthcheck — not just after it starts.

---

## Healthcheck Definitions

### MySQL
```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost",
         "-uroot", "--password=${MYSQL_ROOT_PASSWORD}"]
  interval: 10s
  timeout:  5s
  retries:  5
  start_period: 30s
```
- Runs `mysqladmin ping` inside the MySQL container
- `start_period: 30s` gives MySQL time to initialise before counting failures
- 5 retries × 10s = up to 80s total before marked unhealthy

### EpicBook App
```yaml
healthcheck:
  test: ["CMD", "nc", "-z", "localhost", "8080"]
  interval: 30s
  timeout:  5s
  retries:  3
  start_period: 60s
```
- `nc -z` checks if port 8080 is open (TCP only — no HTTP request)
- `start_period: 60s` allows time for DB seeding on first run
- Returns healthy as soon as Node.js is listening

### Nginx
```yaml
healthcheck:
  test: ["CMD", "wget", "-qO-", "http://localhost/nginx-health"]
  interval: 30s
  timeout:  3s
  retries:  3
```
- Hits the `/nginx-health` endpoint which returns `200 healthy`
- `access_log off` in nginx config so health pings don't pollute logs

---

## depends_on in docker-compose.yml

```yaml
epicbook:
  depends_on:
    mysql:
      condition: service_healthy   # waits for mysqladmin ping to pass

nginx:
  depends_on:
    epicbook:
      condition: service_healthy   # waits for port 8080 to be open
```

Without `condition: service_healthy`, Docker would start containers
in parallel and epicbook would try to connect before MySQL was ready —
causing a connection refused error and container crash loop.

---

## Checking Healthcheck Status

```bash
# Quick overview
docker compose ps

# Detailed healthcheck state
docker inspect epicbook-mysql | grep -A 8 '"Health"'
docker inspect epicbook-app   | grep -A 8 '"Health"'
docker inspect epicbook-nginx | grep -A 8 '"Health"'
```
