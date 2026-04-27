# 05 — Persistence & Backup

## Volume Strategy

```yaml
volumes:
  db_data:    # MySQL data directory
    driver: local
  app_logs:   # EpicBook application logs
    driver: local
```

### db_data
- Mounted at `/var/lib/mysql` inside the MySQL container
- Survives `docker compose down` — data is not lost
- Only destroyed by `docker compose down -v` (explicit flag)
- Lives on the VM disk at `/var/lib/docker/volumes/epicbook-capstone_db_data`

### app_logs
- Mounted at `/app/logs` inside the epicbook container
- Persists app-level log files across container restarts

### Nginx Logs (Bind Mount)
- `./logs/nginx:/var/log/nginx` — bind mount to host filesystem
- Accessible directly on the VM without `docker exec`
- Owned by uid 101 (nginx user in Alpine)

---

## Proving Persistence

### Test — Data Survives Full Stack Restart

```bash
# Count books before
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"

# Stop everything (volumes preserved)
docker compose down

# Confirm volume still exists
docker volume ls | grep db_data

# Restart
docker compose up -d

# Count after — must match
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"
```

---

## Backup Plan

### What to Backup
| Data | Method | Location |
|---|---|---|
| MySQL database | `mysqldump` SQL dump | `~/backups/` on VM |
| nginx logs | Already on host disk | `~/epicbook-capstone/logs/nginx/` |
| `.env` file | Manual copy | Secure location (not Git) |

### Manual Backup
```bash
mkdir -p ~/backups

docker exec epicbook-mysql mysqldump \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  > ~/backups/backup_$(date +%Y%m%d_%H%M%S).sql

echo "Backup size: $(ls -lh ~/backups/ | tail -1)"
```

### Scheduled Backup (Daily at 2am)
```bash
# Add to crontab: crontab -e
0 2 * * * docker exec epicbook-mysql mysqldump \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  > /home/azureuser/backups/backup_$(date +\%Y\%m\%d).sql
```

### Restore from Backup
```bash
docker exec -i epicbook-mysql mysql \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  < ~/backups/backup_20240101_020000.sql

echo "Restore complete"
```

---

## Manual Backup Test (Before/After)

### Step 1 — Record baseline
```bash
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) FROM bookstore.books;"
# Result: 10 books
```

### Step 2 — Create backup
```bash
docker exec epicbook-mysql mysqldump \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  > ~/backups/backup_test.sql
```

### Step 3 — Simulate data loss
```bash
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "DELETE FROM bookstore.books LIMIT 5;"

docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) FROM bookstore.books;"
# Result: 5 books (5 deleted)
```

### Step 4 — Restore
```bash
docker exec -i epicbook-mysql mysql \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  < ~/backups/backup_test.sql

docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) FROM bookstore.books;"
# Result: 10 books (restored)
```

Backup and restore verified successfully.
