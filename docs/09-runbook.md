# EpicBook — Operations Runbook

## Stack Overview

| Container | Image | Port | Network |
|---|---|---|---|
| epicbook-nginx | nginx:alpine (custom) | 80 (public) | frontend-net |
| epicbook-app | node:18-alpine (custom) | 8080 (internal) | frontend-net + backend-net |
| epicbook-mysql | mysql:8.0 | 3306 (internal) | backend-net |

---

## Start the Stack

```bash
cd ~/epicbook-capstone
docker compose up -d
docker compose ps
```

---

## Stop the Stack (data preserved)

```bash
docker compose down
# db_data volume is preserved — books and authors survive
```

---

## Full Teardown (removes ALL data)

```bash
docker compose down -v
# WARNING: deletes db_data volume — all data lost
```

---

## View Logs

```bash
# All services combined
docker compose logs -f

# Individual services
docker compose logs -f epicbook
docker compose logs -f mysql
docker compose logs -f nginx

# Nginx logs on host (bind mounted)
tail -f ~/epicbook-capstone/logs/nginx/access.log
tail -f ~/epicbook-capstone/logs/nginx/error.log
```

---

## Check Healthcheck Status

```bash
docker inspect epicbook-app   | grep -A 8 '"Health"'
docker inspect epicbook-mysql | grep -A 8 '"Health"'
docker inspect epicbook-nginx | grep -A 8 '"Health"'

# Quick status overview
docker compose ps
```

---

## Backup Database

```bash
# Manual SQL dump with timestamp
docker exec epicbook-mysql mysqldump \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  > ~/backups/backup_$(date +%Y%m%d_%H%M%S).sql

echo "Backup complete"
```

**Schedule:** Run daily via cron:
```bash
# Add to crontab: crontab -e
0 2 * * * docker exec epicbook-mysql mysqldump -u epicbookadmin -p'EpicBook@MySQL123' bookstore > ~/backups/backup_$(date +\%Y\%m\%d).sql
```

---

## Restore Database

```bash
docker exec -i epicbook-mysql mysql \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  < ~/backups/backup_20240101_020000.sql

echo "Restore complete"
```

---

## Rollback Procedure

```bash
# 1. Stop the stack
docker compose down

# 2. Revert the bad commit
git revert HEAD

# 3. Rebuild and redeploy
docker compose build --no-cache
docker compose up -d

# 4. Confirm healthy
docker compose ps
curl -I http://localhost
```

---

## Rotate Secrets

1. Edit `.env` with new password values
2. `docker compose down`
3. Update `epicbook/config/config.json` if DB password changed
4. `docker compose up -d --build`
5. Confirm `curl -I http://localhost` returns 200

---

## Reliability Tests

### Test 1 — Restart app container only
```bash
docker compose restart epicbook
# Nginx returns 502 briefly while epicbook restarts
# Should recover within ~60s
curl -I http://localhost
```

### Test 2 — Take DB down (backend failure)
```bash
docker compose stop mysql
curl -I http://localhost
# Expected: 500 or 502 — epicbook cannot reach DB

docker compose start mysql
# Wait for MySQL healthcheck to pass (~30s)
docker compose ps
curl -I http://localhost
# Expected: 200 — recovered
```

### Test 3 — Full bounce + data persistence
```bash
# Count before
docker exec epicbook-mysql mysql \
  -u epicbookadmin -p'EpicBook@MySQL123' \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"

# Bounce entire stack
docker compose down
docker compose up -d

# Wait for all healthy
docker compose ps

# Count after — must match
docker exec epicbook-mysql mysql \
  -u epicbookadmin -p'EpicBook@MySQL123' \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"
```

---

## Common Errors + Fixes

| Error | Cause | Fix |
|---|---|---|
| `epicbook` unhealthy on start | MySQL not ready yet | Wait 60s — check `docker compose logs mysql` |
| `nginx` stays unhealthy | `epicbook` not healthy | Fix epicbook first — nginx depends on it |
| Port 80 already in use | Another process on port 80 | `sudo lsof -i :80` and kill it |
| DB connection refused | Wrong DB_HOST in .env | Confirm `DB_HOST=mysql` (Docker service name, not IP) |
| Seed skipped but DB empty | nc command failed | Check backend-net — confirm epicbook is on backend-net |
| Permission denied on logs/ | Wrong ownership | `sudo chown -R azureuser:azureuser logs/` |
| `config.json` permission denied | File owned by root | Dockerfile sets ownership — rebuild with `--no-cache` |

---

## Log Locations

| Log | Location | Type |
|---|---|---|
| Nginx access | `~/epicbook-capstone/logs/nginx/access.log` | Bind mount on host |
| Nginx error | `~/epicbook-capstone/logs/nginx/error.log` | Bind mount on host |
| EpicBook app | `docker compose logs epicbook` | Container stdout |
| MySQL | `docker compose logs mysql` | Container stdout |
