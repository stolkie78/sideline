.PHONY: up down setup rebuild logs

# Start all services
up:
	docker compose up -d

# Stop all services
down:
	docker compose down

# Run collection setup (idempotent — safe to run anytime)
setup:
	chmod +x scripts/setup-collections.sh
	@if [ -f .env ]; then set -a && . ./.env && set +a; fi && ./scripts/setup-collections.sh

# Full rebuild + setup
rebuild:
	docker compose down
	docker compose build
	docker compose up -d
	@echo "Waiting for PocketBase to be healthy..."
	@sleep 5
	$(MAKE) setup

# View logs
logs:
	docker compose logs -f
