#!/usr/bin/env bash
# SetBaas - Deploy to Azure Container Apps
# Prerequisites: az cli logged in, .env file present
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load env vars
if [ -f "$ROOT_DIR/.env" ]; then
  set -a && . "$ROOT_DIR/.env" && set +a
fi

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-setbaas-rg}"
LOCATION="${AZURE_LOCATION:-westeurope}"
ENVIRONMENT="${AZURE_ENVIRONMENT:-prod}"

echo "=== SetBaas Azure Deployment ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Environment: $ENVIRONMENT"
echo ""

# 1. Create resource group
echo "→ Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

# 2. Deploy infrastructure
echo "→ Deploying infrastructure (Bicep)..."
DEPLOY_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$SCRIPT_DIR/main.bicep" \
  --parameters "$SCRIPT_DIR/main.bicepparam" \
  --query 'properties.outputs' \
  --output json)

ACR_SERVER=$(echo "$DEPLOY_OUTPUT" | jq -r '.acrLoginServer.value')
PB_URL=$(echo "$DEPLOY_OUTPUT" | jq -r '.pocketbaseUrl.value')
FRONTEND_URL=$(echo "$DEPLOY_OUTPUT" | jq -r '.frontendUrl.value')

echo "  ACR: $ACR_SERVER"
echo "  PocketBase: $PB_URL"
echo "  Frontend: $FRONTEND_URL"

# 3. Push container images
echo "→ Logging into ACR..."
az acr login --name "${ACR_SERVER%%.*}"

echo "→ Building and pushing PocketBase image..."
docker build -t "$ACR_SERVER/setbaas-pocketbase:latest" -f "$ROOT_DIR/Dockerfile.pocketbase" "$ROOT_DIR"
docker push "$ACR_SERVER/setbaas-pocketbase:latest"

echo "→ Building and pushing Frontend image..."
docker build -t "$ACR_SERVER/setbaas-frontend:latest" -f "$ROOT_DIR/frontend/Dockerfile" "$ROOT_DIR/frontend" \
  --build-arg PUBLIC_POCKETBASE_URL="$PB_URL"
docker push "$ACR_SERVER/setbaas-frontend:latest"

# 4. Update container apps with new images
echo "→ Updating container apps..."
az containerapp update --name "setbaas-${ENVIRONMENT}-pocketbase" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$ACR_SERVER/setbaas-pocketbase:latest" --output none

az containerapp update --name "setbaas-${ENVIRONMENT}-frontend" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$ACR_SERVER/setbaas-frontend:latest" --output none

# 5. Run setup (collections + seeding)
echo "→ Running PocketBase setup..."
"$ROOT_DIR/scripts/setup-collections.sh"

echo ""
echo "=== Deployment complete! ==="
echo "Frontend: $FRONTEND_URL"
echo "PocketBase API: $PB_URL"
echo "PocketBase Admin: $PB_URL/_/"
