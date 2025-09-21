#!/bin/bash

# Kubernetes deployment script for SkillCRM
# Usage: ./deploy.sh [stage|prod] [image-tag]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
DOCKER_REGISTRY="skillcrm-register.registry.twcstorage.ru"
IMAGE_NAME="twenty"
ENVIRONMENT=${1:-prod}
IMAGE_TAG=${2:-latest}
KUBECTL_CMD="kubectl"

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to create namespace
create_namespace() {
    print_status "Creating namespace for $ENVIRONMENT environment..."
    
    if [ "$ENVIRONMENT" = "stage" ]; then
        kubectl apply -f stage/namespace.yaml
    else
        kubectl apply -f namespace.yaml
    fi
    
    print_success "Namespace created"
}

# Function to create Docker registry secret
create_registry_secret() {
    print_status "Creating Docker registry secret..."
    
    # Check if secret already exists
    if kubectl get secret twentycrm-registry-secret -n twentycrm${ENVIRONMENT:+-$ENVIRONMENT} >/dev/null 2>&1; then
        print_warning "Registry secret already exists, skipping creation"
        return 0
    fi
    
    # Create docker config
    local docker_config=$(cat <<EOF
{
  "auths": {
    "$DOCKER_REGISTRY": {
      "username": "$DOCKER_REGISTRY_USER",
      "password": "$DOCKER_REGISTRY_TOKEN",
      "auth": "$(echo -n "$DOCKER_REGISTRY_USER:$DOCKER_REGISTRY_TOKEN" | base64)"
    }
  }
}
EOF
)
    
    # Create secret
    kubectl create secret docker-registry twentycrm-registry-secret \
        --docker-server="$DOCKER_REGISTRY" \
        --docker-username="$DOCKER_REGISTRY_USER" \
        --docker-password="$DOCKER_REGISTRY_TOKEN" \
        --namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
    
    print_success "Docker registry secret created"
}

# Function to update image in deployment
update_image() {
    print_status "Updating image to $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG..."
    
    local deployment_name="skillcrm${ENVIRONMENT:+-$ENVIRONMENT}-server"
    local namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
    
    kubectl set image deployment/$deployment_name \
        server=$DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG \
        -n $namespace
    
    print_success "Image updated"
}

# Function to apply Kubernetes manifests
apply_manifests() {
    print_status "Applying Kubernetes manifests..."
    
    local namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
    
    if [ "$ENVIRONMENT" = "stage" ]; then
        # Apply stage manifests
        kubectl apply -f stage/secret.yaml
        kubectl apply -f stage/configmap.yaml
        kubectl apply -f stage/pvc.yaml
        kubectl apply -f stage/deployment-server.yaml
        kubectl apply -f stage/deployment-worker.yaml
        kubectl apply -f stage/service.yaml
        kubectl apply -f stage/ingress.yaml
    else
        # Apply production manifests
        kubectl apply -f secret.yaml
        kubectl apply -f configmap.yaml
        kubectl apply -f pvc.yaml
        kubectl apply -f deployment-server.yaml
        kubectl apply -f deployment-worker.yaml
        kubectl apply -f service.yaml
        kubectl apply -f ingress.yaml
    fi
    
    print_success "Manifests applied"
}

# Function to wait for rollout
wait_for_rollout() {
    print_status "Waiting for rollout to complete..."
    
    local deployment_name="skillcrm${ENVIRONMENT:+-$ENVIRONMENT}-server"
    local namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
    
    kubectl rollout status deployment/$deployment_name -n $namespace --timeout=300s
    
    print_success "Rollout completed"
}

# Function to check application health
check_health() {
    print_status "Checking application health..."
    
    local service_name="skillcrm${ENVIRONMENT:+-$ENVIRONMENT}-server"
    local namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
    local domain=""
    
    if [ "$ENVIRONMENT" = "stage" ]; then
        domain="stage.skillcrm.ru"
    else
        domain="skillcrm.ru"
    fi
    
    # Wait a bit for ingress to be ready
    sleep 30
    
    # Check health endpoint
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f "https://$domain/healthz" >/dev/null 2>&1; then
            print_success "Application is healthy!"
            return 0
        fi
        
        print_status "Health check attempt $attempt/$max_attempts..."
        sleep 30
        attempt=$((attempt + 1))
    done
    
    print_error "Health check failed after $max_attempts attempts"
    return 1
}

# Function to show deployment status
show_status() {
    print_status "Deployment Status:"
    echo "===================="
    
    local namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
    
    echo "Namespace: $namespace"
    echo ""
    
    echo "Pods:"
    kubectl get pods -n $namespace
    echo ""
    
    echo "Services:"
    kubectl get services -n $namespace
    echo ""
    
    echo "Ingress:"
    kubectl get ingress -n $namespace
    echo ""
    
}

# Function to rollback deployment
rollback_deployment() {
    print_warning "Rolling back deployment..."
    
    local deployment_name="skillcrm${ENVIRONMENT:+-$ENVIRONMENT}-server"
    local namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
    
    kubectl rollout undo deployment/$deployment_name -n $namespace
    kubectl rollout status deployment/$deployment_name -n $namespace --timeout=300s
    
    print_success "Rollback completed"
}

# Main deployment function
deploy() {
    print_status "Starting Kubernetes deployment for $ENVIRONMENT environment..."
    print_status "Image: $DOCKER_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    
    # Check prerequisites
    check_prerequisites
    
    # Create namespace
    create_namespace
    
    # Create registry secret
    create_registry_secret
    
    # Apply manifests
    apply_manifests
    
    # Update image
    update_image
    
    # Wait for rollout
    wait_for_rollout
    
    # Check health
    if check_health; then
        print_success "Deployment completed successfully!"
        show_status
    else
        print_error "Deployment failed health check"
        rollback_deployment
        exit 1
    fi
}

# Parse command line arguments
case "${1:-}" in
    "stage")
        ENVIRONMENT="stage"
        deploy
        ;;
    "prod")
        ENVIRONMENT="prod"
        deploy
        ;;
    "rollback")
        ENVIRONMENT=${2:-prod}
        rollback_deployment
        ;;
    "status")
        ENVIRONMENT=${2:-prod}
        show_status
        ;;
    "logs")
        ENVIRONMENT=${2:-prod}
        local namespace="twentycrm${ENVIRONMENT:+-$ENVIRONMENT}"
        kubectl logs -f deployment/skillcrm${ENVIRONMENT:+-$ENVIRONMENT}-server -n $namespace
        ;;
    *)
        echo "Usage: $0 {stage|prod} [image-tag]"
        echo "       $0 rollback [stage|prod]"
        echo "       $0 status [stage|prod]"
        echo "       $0 logs [stage|prod]"
        echo ""
        echo "Commands:"
        echo "  stage [tag]   - Deploy to stage environment"
        echo "  prod [tag]    - Deploy to production environment"
        echo "  rollback      - Rollback to previous deployment"
        echo "  status        - Show deployment status"
        echo "  logs          - Show application logs"
        echo ""
        echo "Environment variables:"
        echo "  DOCKER_REGISTRY_USER - Docker registry username"
        echo "  DOCKER_REGISTRY_TOKEN - Docker registry token"
        exit 1
        ;;
esac
