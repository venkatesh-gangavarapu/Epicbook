# 10 — Reliability Tests

## Test Summary

| Test | Scenario | Expected Behaviour | Result |
|---|---|---|---|
| 1 | Restart app container | Brief 502, recovers automatically | ✅ Pass |
| 2 | Take DB down | 500/502 while down, recovers on restart | ✅ Pass |
| 3 | Full stack bounce | All data present after restart | ✅ Pass |
| 4 | Backup and restore | Row count matches before and after | ✅ Pass |

---

## Test 1 — Restart App Container

**Scenario:** The epicbook container crashes or is restarted.
nginx should return 502 briefly, then recover as epicbook comes back up.

```bash
# Check current state
docker compose ps
curl -I http://localhost    # HTTP 200

# Restart app only
docker compose restart epicbook

# Test during restart — nginx returns 502
curl -I http://localhost    # HTTP 502 (brief)

# Wait for epicbook healthcheck to pass (~60s)
watch -n2 docker compose ps

# Confirm recovery
curl -I http://localhost    # HTTP 200
```

**Result:** Site recovered within ~60 seconds.
nginx did not need to be restarted — it detected epicbook was back healthy automatically.

---

## Test 2 — Database Failure

**Scenario:** MySQL container goes down. Backend should return errors,
then recover automatically when the database comes back.

```bash
# Confirm working
curl -I http://localhost    # HTTP 200

# Stop MySQL
docker compose stop mysql
curl -I http://localhost    # HTTP 500 or 502

# Check app logs during failure
docker compose logs --tail=10 epicbook

# Restart MySQL
docker compose start mysql

# Watch MySQL healthcheck pass
watch -n5 docker compose ps

# Confirm recovery
curl -I http://localhost    # HTTP 200
```

**Result:** App returned 500 errors while DB was down.
Recovered automatically within ~30s of MySQL becoming healthy.
No manual intervention needed — `restart: unless-stopped` handled it.

---

## Test 3 — Full Stack Bounce + Data Persistence

**Scenario:** Entire stack is stopped and restarted.
All data must survive because it lives in the `db_data` named volume.

```bash
# Record data before bounce
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"
# Result: 10 rows

docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as authors FROM bookstore.authors;"
# Result: 5 rows

# Stop stack (volumes preserved)
docker compose down

# Confirm volume still exists
docker volume ls | grep db_data
# Expected: epicbook-capstone_db_data

# Restart stack
docker compose up -d

# Wait for all healthy
docker compose ps

# Verify data after bounce
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"
# Result: 10 rows — matches

docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as authors FROM bookstore.authors;"
# Result: 5 rows — matches
```

**Result:** All data preserved across full restart.
Entrypoint correctly detected tables existed and skipped re-seeding.

---

## Test 4 — Backup and Restore

**Scenario:** Data is backed up, then deliberately deleted, then restored.

```bash
# Step 1 — Backup
mkdir -p ~/backups
docker exec epicbook-mysql mysqldump \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  > ~/backups/backup_test.sql

echo "Backup size: $(ls -lh ~/backups/backup_test.sql)"

# Step 2 — Simulate data loss
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "DELETE FROM bookstore.books LIMIT 5;"

docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"
# Result: 5 rows (5 deleted)

# Step 3 — Restore
docker exec -i epicbook-mysql mysql \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  < ~/backups/backup_test.sql

# Step 4 — Verify
docker exec epicbook-mysql mariadb \
  -u epicbookadmin -p'EpicBook@MySQL123' --skip-ssl \
  -e "SELECT COUNT(*) as books FROM bookstore.books;"
# Result: 10 rows — fully restored
```

**Result:** Backup and restore verified successfully.

---

## Observations

**Healthcheck chain is the key reliability mechanism.**
Because nginx depends on epicbook healthy, and epicbook depends on mysql healthy,
the stack self-orders on every restart. No race conditions.

**`restart: unless-stopped` handles transient failures.**
If a container crashes unexpectedly (OOM, signal, network blip),
Docker restarts it automatically without any human intervention.

**Named volumes survive `docker compose down` but not `docker compose down -v`.**
The `-v` flag is destructive and should only be used for intentional teardown.
