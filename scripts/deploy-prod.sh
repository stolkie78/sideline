#!/usr/bin/env bash
# SetBaas - Deploy to Docker Linux server
# Usage: ./deploy.sh [setup]
#   - Without args: builds and starts the app
#   - With 'setup': also runs PocketBase collection setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Check .env exists
if [ ! -f .env ]; then
  echo "ERROR: .env file not found. Copy .env.production to .env and configure it."
  echo "  cp .env.production .env && nano .env"
  exit 1
fi

echo "=== SetBaas Production Deploy ==="

# Build and start
echo "→ Building containers..."
docker compose -f docker-compose.prod.yml build

echo "→ Starting services..."
docker compose -f docker-compose.prod.yml up -d

# Run setup if requested
if [ "${1:-}" = "setup" ]; then
  echo "→ Running PocketBase setup..."
  docker compose -f docker-compose.prod.yml --profile setup run --rm pb-setup
fi

echo ""
echo "=== Deploy complete ==="
echo "Frontend: https://$(grep DOMAIN .env | cut -d= -f2)"
echo "API:      https://api.$(grep DOMAIN .env | cut -d= -f2)"
echo "PB Admin: https://api.$(grep DOMAIN .env | cut -d= -f2)/_/"
echo ""
echo "Logs: docker compose -f docker-compose.prod.yml logs -f"
