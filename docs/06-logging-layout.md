# 06 — Logging Layout

## Logging Strategy

```
Container           Log Type        Storage         Access Method
─────────────────   ─────────────   ─────────────   ──────────────────────
epicbook-nginx      access.log      Bind mount      tail ./logs/nginx/access.log
epicbook-nginx      error.log       Bind mount      tail ./logs/nginx/error.log
epicbook-app        stdout/stderr   Named volume    docker compose logs epicbook
epicbook-mysql      stdout/stderr   Container       docker compose logs mysql
```

---

## Nginx Logs — Bind Mount

Nginx logs are written to `/var/log/nginx/` inside the container and
bind-mounted to `./logs/nginx/` on the host.

```yaml
volumes:
  - ./logs/nginx:/var/log/nginx
```

**Why bind mount for nginx?**
- Logs are directly accessible on the host without `docker exec`
- Easy to tail, grep, or forward to a log aggregator
- Survives container removal — logs stay even after `docker compose down`

**Permission fix required:**
nginx in Alpine runs as uid 101. The host directory must be owned by that uid:
```bash
sudo chown -R 101:101 ./logs/nginx
```

**Access nginx logs:**
```bash
# Live access log
tail -f ~/epicbook-capstone/logs/nginx/access.log

# Live error log
tail -f ~/epicbook-capstone/logs/nginx/error.log

# Filter by status code
grep " 500 " ~/epicbook-capstone/logs/nginx/access.log
grep " 404 " ~/epicbook-capstone/logs/nginx/access.log

# Count requests
wc -l ~/epicbook-capstone/logs/nginx/access.log
```

**Sample access log entry:**
```
49.43.216.22 - - [27/Apr/2026:10:15:32 +0000] "GET / HTTP/1.1" 200 3421 "-" "curl/7.88.1"
49.43.216.22 - - [27/Apr/2026:10:15:45 +0000] "GET /nginx-health HTTP/1.1" 200 8 "-" "wget"
```

---

## App Logs — Named Volume (stdout)

EpicBook logs go to stdout/stderr — the Docker default. They are captured
by Docker's log driver and stored in the container log buffer.

```bash
# View app logs
docker compose logs epicbook

# Follow live
docker compose logs -f epicbook

# Last 50 lines
docker compose logs --tail=50 epicbook
```

App logs are also persisted in the `app_logs` named volume at `/app/logs`
if the application writes structured logs to that directory.

---

## MySQL Logs — Container stdout

```bash
docker compose logs mysql
docker compose logs -f mysql
```

MySQL slow query log and error log go to stdout in the official mysql:8.0 image.

---

## Health Check Logs Excluded

The `/nginx-health` endpoint has `access_log off` in nginx config —
health check pings from Docker every 30s do not pollute the access log.

```nginx
location /nginx-health {
    access_log off;
    return 200 "healthy\n";
}
```

---

## Optional: Log Forwarding with Fluent Bit

For production at scale, logs can be forwarded to a centralised system.
Fluent Bit is lightweight (~450KB) and can tail files or read from Docker:

```yaml
# Add to docker-compose.yml (optional)
fluent-bit:
  image: fluent/fluent-bit:latest
  volumes:
    - ./logs/nginx:/var/log/nginx:ro
    - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf
  networks:
    - frontend-net
```

For this deployment, direct file access and `docker compose logs` are sufficient.
