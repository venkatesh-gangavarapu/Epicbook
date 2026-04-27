# 07 — Cloud Deployment Notes

## Cloud Provider
**Microsoft Azure — Central India region**

---

## VM Specification

| Property | Value |
|---|---|
| VM Name | vm-epicbook-capstone |
| Resource Group | rg-epicbook-capstone |
| Region | Central India |
| Size | Standard_B2s (2 vCPU, 4GB RAM) |
| OS | Ubuntu 22.04 LTS |
| Disk | 64 GB Standard LRS |
| Public IP | Static, Standard SKU |
| Admin User | azureuser |
| Authentication | SSH key (ed25519) — no password |

---

## Network Security Group Rules

| Rule Name | Priority | Direction | Port | Source | Purpose |
|---|---|---|---|---|---|
| allow-ssh | 100 | Inbound | 22 | Any | VM management |
| allow-http | 110 | Inbound | 80 | Any | Public web traffic |
| (implicit deny) | — | Inbound | 8080 | — | App port blocked |
| (implicit deny) | — | Inbound | 3306 | — | DB port blocked |

Ports 8080 and 3306 have **no NSG rules** — they are blocked at the
network level. Even if Docker accidentally published them, the NSG
would prevent any external access.

---

## Docker + Compose Installation

Handled automatically via **cloud-init** at VM first boot:

```yaml
runcmd:
  - apt-get install -y docker.io
  - systemctl enable docker && systemctl start docker
  - usermod -aG docker azureuser
  - curl -SL https://github.com/docker/compose/releases/download/v2.24.0/
      docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
  - chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  - mkdir -p /home/azureuser/epicbook-capstone/logs/nginx
  - chown -R 101:101 /home/azureuser/epicbook-capstone/logs/nginx
```

No manual SSH required to install Docker — the VM arrives ready.

---

## Deployment Steps

```bash
# 1. Provision VM
cd terraform/
terraform init && terraform apply

# 2. Copy project to VM
scp -r ~/epicbook-capstone azureuser@<public_ip>:~/epicbook-capstone

# 3. SSH in
ssh azureuser@<public_ip>

# 4. Clone app source
cd ~/epicbook-capstone
git clone https://github.com/pravinmishraaws/theepicbook epicbook-src
rsync -av --exclude='.git' --exclude='config' --exclude='node_modules' \
  epicbook-src/ epicbook/
rm -rf epicbook-src

# 5. Start the stack
docker compose up -d --build

# 6. Verify
docker compose ps
curl -I http://localhost
```

---

## Public Access Validation

| Check | Command | Expected Result |
|---|---|---|
| HTTP response | `curl -I http://<public_ip>` | `HTTP/1.1 200 OK` |
| nginx health | `curl http://<public_ip>/nginx-health` | `healthy` |
| Browser | `http://<public_ip>` | EpicBook site loads |
| Books visible | Browse to `/books` | Book listing renders |

---

## Application URL

```
http://<public_ip>
```

Replace `<public_ip>` with the value from `terraform output public_ip`.

---

## Teardown

```bash
# On the VM
docker compose down -v

# From WSL2
cd terraform/
terraform destroy
```

All Azure resources removed — Resource Group, VNet, NSG, Public IP, NIC, VM.
