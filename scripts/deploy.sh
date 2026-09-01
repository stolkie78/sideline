#!/bin/bash
# SetBaas Deploy Script
# Creates a backup before deploying a new version
#
# Usage:
#   ./scripts/deploy.sh              # On the production server

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "🏐 SetBaas Deploy"
echo ""

# 1. Backup before deploy
echo "📦 Stap 1: Backup maken..."
if docker compose -f docker-compose.prod.yml ps --services --filter status=running 2>/dev/null | grep -q pocketbase; then
    ./scripts/backup.sh
else
    echo "  ⚠ PocketBase draait niet, backup overgeslagen"
fi

echo ""

# 2. Pull latest code
echo "📥 Stap 2: Code ophalen..."
git pull

echo ""

# 3. Build and deploy
echo "🔨 Stap 3: Build en deploy..."
docker compose -f docker-compose.prod.yml up -d --build

echo ""

# 4. Run setup (idempotent, adds new collections/fields)
echo "⚙️  Stap 4: Database setup..."
docker compose -f docker-compose.prod.yml --profile setup run --rm pb-setup

echo ""

# 5. Show version
VERSION=$(grep '"version"' frontend/package.json | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
echo "✅ Deploy compleet! SetBaas v${VERSION} is live."
