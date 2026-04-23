#!/bin/bash

set -euo pipefail

# ============================================================
# Colors for output
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# Helper Functions
# ============================================================
print_status()   { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning()  { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()    { echo -e "${RED}[ERROR]${NC} $1"; }
print_header()   { echo -e "${BLUE}=== $1 ===${NC}"; }
print_success()  { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# ============================================================
# Configuration Variables
# ============================================================
NAMESPACE="${NAMESPACE:-aprilpollo}"

# Environment Files
ENV_FILE_BACKEND="${ENV_FILE_BACKEND:-.env}"

# ConfigMap Names
CONFIGMAP_NAME_BACKEND="${CONFIGMAP_NAME_BACKEND:-task-manager-env}"

# ============================================================
# Namespace Management
# ============================================================
create_namespace() {
  print_header "Creating Namespace"
  
  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_status "Namespace $NAMESPACE already exists"
  else
    kubectl create namespace "$NAMESPACE"
    print_success "Namespace created: $NAMESPACE"
  fi
}

# ============================================================
# ConfigMap Management
# ============================================================
create_backend_configmap() {
  print_header "Creating Backend ConfigMap"

  if [ ! -f "$ENV_FILE_BACKEND" ]; then
    print_error "Environment file not found: $ENV_FILE_BACKEND"
    exit 1
  fi

  print_status "Creating ConfigMap from: $ENV_FILE_BACKEND"

  kubectl delete configmap "$CONFIGMAP_NAME_BACKEND" -n "$NAMESPACE" 2>/dev/null || true
  
  kubectl create configmap "$CONFIGMAP_NAME_BACKEND" \
    --from-env-file="$ENV_FILE_BACKEND" \
    --namespace="$NAMESPACE"

  print_success "ConfigMap created: $CONFIGMAP_NAME_BACKEND"
}

create_configmap() {
  create_backend_configmap
}

# ============================================================
# Deployment Management
# ============================================================
deploy() {
  print_header "Deploying with Helm"

  local chart_dir="k8s"
  local values_file="k8s/values/uat.yaml"
  local release_name="task-manager"
  
  if [ ! -f "$values_file" ]; then
    print_error "Values file not found: $values_file"
    exit 1
  fi

  print_status "Deploying to namespace: $NAMESPACE"
  print_status "Using values file: $values_file"

  helm upgrade --install "$release_name" "$chart_dir" \
    --namespace "$NAMESPACE" \
    --values "$values_file" \
    --wait
  
  print_success "Deployment completed successfully"
  echo ""
  print_status "Pods status:"
  kubectl get pods -n "$NAMESPACE"
}

# ============================================================
# Pod Management
# ============================================================
get_pods() {
  print_header "Getting Pods Status"
  kubectl get pods -n "$NAMESPACE" -o wide
}

get_all() {
  print_header "Getting All Resources"
  kubectl get all -n "$NAMESPACE"
}

describe_pod() {
  local pod_name="${2:-}"
  
  if [ -z "$pod_name" ]; then
    print_error "Pod name required. Usage: $0 describe <pod-name>"
    exit 1
  fi
  
  print_header "Describing Pod: $pod_name"
  kubectl describe pod "$pod_name" -n "$NAMESPACE"
}

# ============================================================
# Logs Management
# ============================================================
logs_backend() {
  print_header "Backend Logs"
  local follow="${2:-}"
  
  if [ "$follow" == "-f" ] || [ "$follow" == "--follow" ]; then
    kubectl logs -n "$NAMESPACE" -l app=task-manager-backend --tail=100 -f
  else
    kubectl logs -n "$NAMESPACE" -l app=task-manager-backend --tail=100
  fi
}

logs_postgres() {
  print_header "Postgres Logs"
  local follow="${2:-}"
  
  if [ "$follow" == "-f" ] || [ "$follow" == "--follow" ]; then
    kubectl logs -n "$NAMESPACE" -l app=task-manager-postgres --tail=100 -f
  else
    kubectl logs -n "$NAMESPACE" -l app=task-manager-postgres --tail=100
  fi
}

logs_redis() {
  print_header "Redis Logs"
  local follow="${2:-}"
  
  if [ "$follow" == "-f" ] || [ "$follow" == "--follow" ]; then
    kubectl logs -n "$NAMESPACE" -l app=task-manager-redis --tail=100 -f
  else
    kubectl logs -n "$NAMESPACE" -l app=task-manager-redis --tail=100
  fi
}

logs_pod() {
  local pod_name="${2:-}"
  local follow="${3:-}"
  
  if [ -z "$pod_name" ]; then
    print_error "Pod name required. Usage: $0 logs-pod <pod-name> [-f]"
    exit 1
  fi
  
  print_header "Logs for Pod: $pod_name"
  
  if [ "$follow" == "-f" ] || [ "$follow" == "--follow" ]; then
    kubectl logs -n "$NAMESPACE" "$pod_name" --tail=100 -f
  else
    kubectl logs -n "$NAMESPACE" "$pod_name" --tail=100
  fi
}

# ============================================================
# Restart Management
# ============================================================
restart_backend() {
  print_header "Restarting Backend Deployment"
  kubectl rollout restart deployment/task-manager-backend -n "$NAMESPACE"
  print_success "Backend restart initiated"
  kubectl rollout status deployment/task-manager-backend -n "$NAMESPACE"
}

restart_postgres() {
  print_header "Restarting Postgres Deployment"
  kubectl rollout restart deployment/task-manager-postgres -n "$NAMESPACE"
  print_success "Postgres restart initiated"
  kubectl rollout status deployment/task-manager-postgres -n "$NAMESPACE"
}

restart_redis() {
  print_header "Restarting Redis Deployment"
  kubectl rollout restart deployment/task-manager-redis -n "$NAMESPACE"
  print_success "Redis restart initiated"
  kubectl rollout status deployment/task-manager-redis -n "$NAMESPACE"
}

restart_all() {
  print_header "Restarting All Deployments"
  restart_backend
  restart_postgres
  restart_redis
  print_success "All deployments restarted"
}

# ============================================================
# Port Forward Management
# ============================================================
port_forward_backend() {
  local local_port="${2:-8080}"
  print_header "Port Forwarding Backend"
  print_status "Forwarding localhost:$local_port -> backend:8080"
  kubectl port-forward -n "$NAMESPACE" svc/task-manager-backend-service "$local_port":8080
}

port_forward_postgres() {
  local local_port="${2:-5432}"
  print_header "Port Forwarding Postgres"
  print_status "Forwarding localhost:$local_port -> postgres:5432"
  print_status "Connection string: postgresql://admin:password123@localhost:$local_port/taskmanager"
  kubectl port-forward -n "$NAMESPACE" svc/task-manager-postgres-service "$local_port":5432
}

port_forward_redis() {
  local local_port="${2:-6379}"
  print_header "Port Forwarding Redis"
  print_status "Forwarding localhost:$local_port -> redis:6379"
  kubectl port-forward -n "$NAMESPACE" svc/task-manager-redis-service "$local_port":6379
}

# ============================================================
# Shell Access
# ============================================================
shell_backend() {
  print_header "Opening Shell in Backend Pod"
  local pod=$(kubectl get pods -n "$NAMESPACE" -l app=task-manager-backend -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -it -n "$NAMESPACE" "$pod" -- /bin/sh
}

shell_postgres() {
  print_header "Opening Postgres Shell"
  local pod=$(kubectl get pods -n "$NAMESPACE" -l app=task-manager-postgres -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -it -n "$NAMESPACE" "$pod" -- psql -U admin -d taskmanager
}

shell_redis() {
  print_header "Opening Redis Shell"
  local pod=$(kubectl get pods -n "$NAMESPACE" -l app=task-manager-redis -o jsonpath='{.items[0].metadata.name}')
  kubectl exec -it -n "$NAMESPACE" "$pod" -- redis-cli
}

# ============================================================
# Cleanup
# ============================================================
delete_all() {
  print_header "Deleting All Resources"
  print_warning "This will delete all resources in namespace: $NAMESPACE"
  read -p "Are you sure? (yes/no): " confirm
  
  if [ "$confirm" == "yes" ]; then
    helm uninstall task-manager -n "$NAMESPACE" 2>/dev/null || true
    kubectl delete all --all -n "$NAMESPACE"
    print_success "All resources deleted"
  else
    print_status "Deletion cancelled"
  fi
}

# ============================================================
# Help
# ============================================================
help() {
  printf "${CYAN}╔════════════════════════════════════════════════════════════════╗\n"
  printf "║           Task Manager Kubernetes Management Tool              ║\n"
  printf "╚════════════════════════════════════════════════════════════════╝${NC}\n\n"

  printf "${YELLOW}Usage:${NC} $0 [COMMAND] [OPTIONS]\n\n"

  printf "${YELLOW}Namespace Management:${NC}\n"
  printf "  create-np                  Create Kubernetes namespace\n\n"

  printf "${YELLOW}ConfigMap Management:${NC}\n"
  printf "  create-cf                  Create all ConfigMaps from environment files\n\n"

  printf "${YELLOW}Deployment:${NC}\n"
  printf "  deploy                     Deploy application using Helm\n\n"

  printf "${YELLOW}Status & Information:${NC}\n"
  printf "  pods                       List all pods\n"
  printf "  all                        List all resources\n"
  printf "  describe <pod-name>        Describe a specific pod\n\n"

  printf "${YELLOW}Logs:${NC}\n"
  printf "  logs-backend [-f]          Show backend logs (-f to follow)\n"
  printf "  logs-postgres [-f]         Show Postgres logs (-f to follow)\n"
  printf "  logs-redis [-f]            Show Redis logs (-f to follow)\n"
  printf "  logs-pod <pod-name> [-f]   Show logs for specific pod (-f to follow)\n\n"

  printf "${YELLOW}Restart:${NC}\n"
  printf "  restart-backend            Restart backend deployment\n"
  printf "  restart-postgres           Restart Postgres deployment\n"
  printf "  restart-redis              Restart Redis deployment\n"
  printf "  restart-all                Restart all deployments\n\n"

  printf "${YELLOW}Port Forward:${NC}\n"
  printf "  pf-backend [port]          Port forward to backend (default: 8080)\n"
  printf "  pf-postgres [port]         Port forward to Postgres (default: 5432)\n"
  printf "  pf-redis [port]            Port forward to Redis (default: 6379)\n\n"

  printf "${YELLOW}Shell Access:${NC}\n"
  printf "  shell-backend              Open shell in backend pod\n"
  printf "  shell-postgres             Open Postgres shell (psql)\n"
  printf "  shell-redis                Open Redis CLI\n\n"

  printf "${YELLOW}Cleanup:${NC}\n"
  printf "  delete-all                 Delete all resources (with confirmation)\n\n"

  printf "${YELLOW}Environment Variables:${NC}\n"
  printf "  NAMESPACE                  Kubernetes namespace (default: aprilpollo)\n"
  printf "  ENV_FILE_BACKEND           Backend env file (default: .env)\n\n"

  printf "${YELLOW}Examples:${NC}\n"
  printf "  $0 deploy                  Deploy the application\n"
  printf "  $0 logs-backend -f         Follow backend logs\n"
  printf "  $0 restart-all             Restart all services\n"
  printf "  $0 pf-postgres 5432        Forward Postgres to localhost:5432\n"
  printf "  $0 shell-postgres          Connect to Postgres shell\n\n"

  printf "${YELLOW}Help:${NC}\n"
  printf "  help                       Show this help message\n\n"
}

# ============================================================
# Main Command Router
# ============================================================
case "${1:-help}" in
    # Namespace
    create-np)
        create_namespace
        ;;
    
    # ConfigMap
    create-cf)
        create_configmap
        ;;
    
    # Deployment
    deploy)
        deploy
        ;;
    
    # Status
    pods)
        get_pods
        ;;
    all)
        get_all
        ;;
    describe)
        describe_pod "$@"
        ;;
    
    # Logs
    logs-backend)
        logs_backend "$@"
        ;;
    logs-postgres)
        logs_postgres "$@"
        ;;
    logs-redis)
        logs_redis "$@"
        ;;
    logs-pod)
        logs_pod "$@"
        ;;
    
    # Restart
    restart-backend)
        restart_backend
        ;;
    restart-postgres)
        restart_postgres
        ;;
    restart-redis)
        restart_redis
        ;;
    restart-all)
        restart_all
        ;;
    
    # Port Forward
    pf-backend)
        port_forward_backend "$@"
        ;;
    pf-postgres)
        port_forward_postgres "$@"
        ;;
    pf-redis)
        port_forward_redis "$@"
        ;;
    
    # Shell
    shell-backend)
        shell_backend
        ;;
    shell-postgres)
        shell_postgres
        ;;
    shell-redis)
        shell_redis
        ;;
    
    # Cleanup
    delete-all)
        delete_all
        ;;
    
    # Help
    help|*)
        help
        exit 0
        ;;
esac