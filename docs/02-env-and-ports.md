# 02 — Environment Variables & Ports

## Environment Variables

### MySQL Container
| Variable | Value | Purpose |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | `RootPass@MySQL123` | Root user password |
| `MYSQL_DATABASE` | `bookstore` | Database created on first start |
| `MYSQL_USER` | `epicbookadmin` | App database user |
| `MYSQL_PASSWORD` | `EpicBook@MySQL123` | App user password |

### EpicBook App Container
| Variable | Value | Purpose |
|---|---|---|
| `NODE_ENV` | `production` | Tells Sequelize to use production config block |
| `DB_HOST` | `mysql` | Docker Compose service name — resolves via internal DNS |
| `DB_PORT` | `3306` | MySQL port |
| `DB_NAME` | `bookstore` | Database name |
| `DB_USER` | `epicbookadmin` | Database user |
| `DB_PASSWORD` | `EpicBook@MySQL123` | Database password |

> All variables are stored in `.env` and loaded via `env_file: .env` in Compose.
> `.env` is in `.gitignore` — never committed to version control.

---

## Port Map

| Service | Internal Port | Published Port | Accessible From |
|---|---|---|---|
| nginx | 80 | **80 → host** | Internet (public) |
| epicbook | 8080 | none (expose only) | Docker internal only |
| mysql | 3306 | none (expose only) | Docker internal only |

### What `expose` vs `ports` Means

```yaml
# ports — publishes to host OS and internet
ports:
  - "80:80"      ← host:container — anyone can reach this

# expose — internal Docker DNS only, never reaches host
expose:
  - "8080"       ← only other containers on same network can reach this
```

Port 8080 and 3306 are **invisible to the host OS** and the internet.
Even if the Azure NSG allowed port 8080, the host has no listener on it.

---

## NSG Rules (Azure)

| Rule | Port | Direction | Source | Purpose |
|---|---|---|---|---|
| allow-ssh | 22 | Inbound | Any | VM management |
| allow-http | 80 | Inbound | Any | Public web traffic |
| (implicit deny) | 8080 | — | — | App port — intentionally blocked |
| (implicit deny) | 3306 | — | — | DB port — intentionally blocked |
