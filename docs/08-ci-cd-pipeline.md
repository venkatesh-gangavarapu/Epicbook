# 08 — CI/CD Pipeline (Optional)

## Overview

An optional Azure DevOps pipeline that builds the EpicBook Docker image
on every commit to `main` and deploys it to the Azure VM via SSH.

---

## Pipeline Stages

```
Commit to main
      │
      ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Stage 1   │────►│   Stage 2   │────►│   Stage 3   │
│    Build    │     │    Push     │     │   Deploy    │
│             │     │             │     │             │
│ docker build│     │ docker push │     │ SSH to VM   │
│ multi-stage │     │ to ACR or   │     │ docker pull │
│ epicbook    │     │ Docker Hub  │     │ compose up  │
└─────────────┘     └─────────────┘     └─────────────┘
```

---

## Pipeline YAML

```yaml
trigger:
  branches:
    include:
      - main

pool:
  name: SelfHostedPool

variables:
  IMAGE_NAME: epicbook-app
  IMAGE_TAG:  $(Build.BuildId)

stages:

# ── Build ──────────────────────────────────
- stage: Build
  displayName: "Build Docker Image"
  jobs:
    - job: BuildImage
      steps:
        - checkout: self

        - script: |
            docker build \
              -t $(IMAGE_NAME):$(IMAGE_TAG) \
              -t $(IMAGE_NAME):latest \
              ./epicbook/
          displayName: "Build multi-stage image"

        - script: docker images $(IMAGE_NAME)
          displayName: "Confirm image built"

# ── Deploy ─────────────────────────────────
- stage: Deploy
  displayName: "Deploy to Azure VM"
  dependsOn: Build
  jobs:
    - job: DeployStack
      steps:
        - task: SSH@0
          displayName: "Pull and restart stack on VM"
          inputs:
            sshEndpoint: 'ubuntu-nginx-ssh'
            runOptions: 'inline'
            inline: |
              cd ~/epicbook-capstone
              docker compose pull
              docker compose up -d --build
              docker compose ps
              curl -s -o /dev/null -w "HTTP: %{http_code}" http://localhost
```

---

## Prerequisites for CI/CD

1. Self-hosted agent registered on the VM (from Week 13 Assignment 1)
2. SSH Service Connection `ubuntu-nginx-ssh` configured in Azure DevOps
3. Agent pool: `SelfHostedPool`

---

## Version Tagging Strategy

```
Build ID tag:  epicbook-app:$(Build.BuildId)   ← unique per build
Latest tag:    epicbook-app:latest              ← always points to newest

Rollback:
  docker tag epicbook-app:<previous_build_id> epicbook-app:latest
  docker compose up -d
```

---

## Note

This pipeline is optional for the capstone submission.
The core assignment focuses on the Docker Compose stack and cloud deployment.
CI/CD is the next evolution — automating what was done manually in the deployment steps.
