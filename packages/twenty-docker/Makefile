# Makefile for Twenty CRM Docker Deployment
# Usage: make <target>

.PHONY: help build deploy-stage deploy-prod status logs backup rollback monitoring clean

# Default target
help: ## Show this help message
	@echo "Twenty CRM Docker Deployment Commands"
	@echo "====================================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Build targets
build: ## Build Docker image
	@echo "Building Docker image..."
	docker build -f twenty/Dockerfile -t skillcrm-register.registry.twcstorage.ru/twenty:latest .

build-stage: ## Build Docker image for stage
	@echo "Building Docker image for stage..."
	docker build -f twenty/Dockerfile -t skillcrm-register.registry.twcstorage.ru/twenty:stage .

# Deploy targets
deploy-stage: ## Deploy to stage environment
	@echo "Deploying to stage environment..."
	@if [ ! -f .env.stage ]; then \
		echo "Error: .env.stage file not found. Please copy env.stage to .env.stage and configure it."; \
		exit 1; \
	fi
	cp .env.stage .env
	./scripts/deploy.sh stage

deploy-prod: ## Deploy to production environment
	@echo "Deploying to production environment..."
	@if [ ! -f .env.prod ]; then \
		echo "Error: .env.prod file not found. Please copy env.prod to .env.prod and configure it."; \
		exit 1; \
	fi
	cp .env.prod .env
	./scripts/deploy.sh prod

# Status and logs
status: ## Show deployment status
	@echo "Checking deployment status..."
	./scripts/deploy.sh status

logs: ## Show application logs
	@echo "Showing application logs..."
	./scripts/deploy.sh logs

logs-server: ## Show server logs only
	@echo "Showing server logs..."
	docker-compose logs -f server

logs-worker: ## Show worker logs only
	@echo "Showing worker logs..."
	docker-compose logs -f worker

# Backup and rollback
backup: ## Create backup
	@echo "Creating backup..."
	./scripts/backup.sh

backup-list: ## List available backups
	@echo "Available backups:"
	./scripts/backup.sh list

rollback: ## Rollback to previous deployment
	@echo "Starting rollback..."
	./scripts/rollback.sh

rollback-verify: ## Verify latest backup
	@echo "Verifying latest backup..."
	./scripts/backup.sh verify

# Monitoring
monitoring-up: ## Start monitoring stack
	@echo "Starting monitoring stack..."
	docker-compose -f docker-compose.monitoring.yml up -d

monitoring-down: ## Stop monitoring stack
	@echo "Stopping monitoring stack..."
	docker-compose -f docker-compose.monitoring.yml down

monitoring-logs: ## Show monitoring logs
	@echo "Showing monitoring logs..."
	docker-compose -f docker-compose.monitoring.yml logs -f

monitoring-status: ## Show monitoring status
	@echo "Monitoring stack status:"
	docker-compose -f docker-compose.monitoring.yml ps

# Development
dev-up: ## Start development environment
	@echo "Starting development environment..."
	docker-compose up -d

dev-down: ## Stop development environment
	@echo "Stopping development environment..."
	docker-compose down

dev-logs: ## Show development logs
	@echo "Showing development logs..."
	docker-compose logs -f

dev-restart: ## Restart development environment
	@echo "Restarting development environment..."
	docker-compose restart

# Maintenance
clean: ## Clean up unused Docker resources
	@echo "Cleaning up Docker resources..."
	docker system prune -f
	docker volume prune -f

clean-all: ## Clean up all Docker resources (including images)
	@echo "Cleaning up all Docker resources..."
	docker system prune -af
	docker volume prune -f

# Database operations
db-migrate: ## Run database migrations
	@echo "Running database migrations..."
	docker-compose exec server yarn database:migrate:prod

db-reset: ## Reset database (WARNING: This will delete all data)
	@echo "WARNING: This will delete all data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	docker-compose exec server yarn database:reset:prod

db-backup: ## Create database backup only
	@echo "Creating database backup..."
	PGPASSWORD="$$POSTGRESQL_PASSWORD" pg_dump \
		-h "$$POSTGRESQL_HOST" \
		-p "$$POSTGRESQL_PORT" \
		-U "$$POSTGRESQL_USER" \
		-d "$$POSTGRESQL_DBNAME" \
		--clean --no-owner --no-privileges \
		> backup_$(shell date +%Y%m%d_%H%M%S).sql

# Health checks
health: ## Check application health
	@echo "Checking application health..."
	@curl -f http://localhost:3000/healthz || echo "Health check failed"

health-stage: ## Check stage environment health
	@echo "Checking stage environment health..."
	@curl -f https://stage.skillcrm.ru/healthz || echo "Stage health check failed"

health-prod: ## Check production environment health
	@echo "Checking production environment health..."
	@curl -f https://skillcrm.ru/healthz || echo "Production health check failed"

# Security
security-scan: ## Run security scan on Docker images
	@echo "Running security scan..."
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image skillcrm-register.registry.twcstorage.ru/twenty:latest; \
	else \
		echo "Trivy not found. Install it first: https://github.com/aquasecurity/trivy"; \
	fi

# Setup
setup: ## Initial setup
	@echo "Setting up Twenty CRM deployment..."
	@if [ ! -f .env.stage ]; then \
		cp env.stage .env.stage; \
		echo "Created .env.stage from template. Please configure it."; \
	fi
	@if [ ! -f .env.prod ]; then \
		cp env.prod .env.prod; \
		echo "Created .env.prod from template. Please configure it."; \
	fi
	@chmod +x scripts/*.sh
	@echo "Setup completed. Please configure .env.stage and .env.prod files."

# Quick commands
quick-stage: setup deploy-stage ## Quick stage deployment
quick-prod: setup deploy-prod ## Quick production deployment
quick-backup: backup ## Quick backup creation
quick-rollback: rollback ## Quick rollback

# Information
info: ## Show deployment information
	@echo "Twenty CRM Deployment Information"
	@echo "================================="
	@echo "Docker Registry: skillcrm-register.registry.twcstorage.ru"
	@echo "Stage Domain: stage.skillcrm.ru"
	@echo "Production Domain: skillcrm.ru"
	@echo "Database Host: 185.185.142.189"
	@echo "Redis Host: 185.185.142.201"
	@echo ""
	@echo "Available environments:"
	@echo "  - stage (develop branch)"
	@echo "  - production (main branch)"
	@echo ""
	@echo "Use 'make help' to see all available commands"