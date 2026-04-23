# Task Manager - Kubernetes Deployment (TK-DP)

This repository contains the Kubernetes deployment configurations and Helm chart for the **Task Manager** application. It automates the deployment of the backend API, PostgreSQL database, and Redis cache using a streamlined bash script.

## 🏗 Architecture
The deployment consists of the following components:
- **Backend**: Go Fiber API (`task-manager-backend`)
- **Database**: PostgreSQL 15 (`task-manager-postgres`)
- **Cache**: Redis 7.2 (`task-manager-redis`)

## 📋 Prerequisites
Before you begin, ensure you have the following installed and configured:
- [Kubernetes Cluster](https://kubernetes.io/)
- [Helm](https://helm.sh/) (Package Manager for Kubernetes)
- `kubectl` CLI configured to communicate with your cluster.

## 🚀 Quick Start

### 1. Configuration
Modify the `.env` file in the root directory to set up your environment variables. This file will be converted into a Kubernetes ConfigMap.

Example `.env`:
```env
POSTGRES_USER=admin
POSTGRES_PASSWORD=password123
POSTGRES_DB=taskmanager

POSTGRE_URI=postgres://admin:password123@task-manager-postgres-service:5432/taskmanager
POSTGRE_URI_MIGRATION=postgres://admin:password123@task-manager-postgres-service:5432/taskmanager

REDIS_HOST=task-manager-redis-service
REDIS_PORT=6379
```

### 2. Deployment
Use the provided `deploy.sh` script to manage the entire lifecycle of the application.

```bash
# 1. Create the ConfigMap from your .env file
./deploy.sh create-cf

# 2. Deploy all components using Helm
./deploy.sh deploy
```

## 🛠 Management Tool (`deploy.sh`)

We provide a comprehensive script `deploy.sh` to make managing the cluster easy. 

Run `./deploy.sh help` to see all available commands.

### Common Commands:
- **Deploy / Update**:
  - `./deploy.sh deploy` - Deploy or upgrade the Helm chart.
  - `./deploy.sh create-cf` - Re-create the backend ConfigMap.
- **Monitoring & Logs**:
  - `./deploy.sh pods` - List all running pods.
  - `./deploy.sh logs-backend -f` - Tail logs for the backend.
  - `./deploy.sh logs-postgres` - View Postgres logs.
- **Troubleshooting**:
  - `./deploy.sh shell-backend` - Open a terminal inside the backend pod.
  - `./deploy.sh shell-postgres` - Connect directly to the PostgreSQL database via `psql`.
  - `./deploy.sh shell-redis` - Connect directly to Redis via `redis-cli`.
  - `./deploy.sh restart-backend` - Force restart the backend deployment (useful after updating the ConfigMap).
- **Local Access (Port Forwarding)**:
  - `./deploy.sh pf-postgres 5432` - Forward Postgres to your localhost.

## ⚙️ Helm Configuration
Advanced configuration can be found in `k8s/values/uat.yaml`. Here you can configure:
- Image tags and registry.
- Resource limits and requests (CPU/Memory).
- Replicas.
- Database credentials (under `postgres.auth`).

If you make changes to `uat.yaml`, simply run `./deploy.sh deploy` to apply them.
