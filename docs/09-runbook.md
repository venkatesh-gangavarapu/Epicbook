# EpicBook Operations Runbook

## Start the Stack
```bash
cd ~/epicbook-capstone
docker compose up -d
docker compose ps
```

## Stop the Stack
```bash
docker compose down
# Data persists in db_data volume
```

## Full Teardown (removes volumes)
```bash
docker compose down -v
# WARNING: deletes all data
```

## View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f epicbook
docker compose logs -f mysql
docker compose logs -f nginx

# Nginx logs on host
tail -f ~/epicbook-capstone/logs/nginx/access.log
```

## Check Healthcheck Status
```bash
docker inspect epicbook-app | grep -A 10 '"Health"'
docker inspect epicbook-mysql | grep -A 10 '"Health"'
```

## Rollback Procedure
```bash
# If latest deployment is broken
docker compose down

# Pull previous image tag (if using registry)
# Or revert code and rebuild
git revert HEAD
docker compose build
docker compose up -d
```

## Backup Database
```bash
# Manual SQL dump
docker exec epicbook-mysql mysqldump \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  > backup_$(date +%Y%m%d_%H%M%S).sql
```

## Restore Database
```bash
docker exec -i epicbook-mysql mysql \
  -u epicbookadmin -p'EpicBook@MySQL123' bookstore \
  < backup_20240101_120000.sql
```

## Rotate Secrets
1. Update .env with new values
2. `docker compose down`
3. `docker compose up -d`
4. Confirm app connects with new credentials

## Common Errors

| Error | Cause | Fix |
|---|---|---|
| `epicbook` unhealthy | MySQL not ready | Wait 30s, check `docker compose logs mysql` |
| Port 80 already in use | Another nginx running | `sudo lsof -i :80` and kill the process |
| DB connection refused | Wrong DB_HOST in .env | Confirm `DB_HOST=mysql` (service name, not IP) |
| Permission denied on logs | Wrong ownership | `sudo chown -R azureuser:azureuser logs/` |
