#!/bin/bash
# setup-collections.sh — Idempotent PocketBase collection setup
# Run after PocketBase is healthy. Creates/updates all collections needed by SetBaas.
# Usage: ./scripts/setup-collections.sh [PB_URL] [ADMIN_EMAIL] [ADMIN_PASSWORD]

set -e

PB_URL="${1:-http://localhost:8090}"
ADMIN_EMAIL="${PB_ADMIN_EMAIL:-${2:-}}"
ADMIN_PASSWORD="${PB_ADMIN_PASSWORD:-${3:-}}"

if [ -z "$ADMIN_EMAIL" ] || [ -z "$ADMIN_PASSWORD" ]; then
  echo "❌ PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD must be set (via env or arguments)"
  exit 1
fi

echo "🏐 SetBaas — Setting up PocketBase collections at $PB_URL"

# Wait for PocketBase to be ready
for i in $(seq 1 30); do
  if curl -sf "$PB_URL/api/health" > /dev/null 2>&1; then
    break
  fi
  echo "  Waiting for PocketBase... ($i)"
  sleep 2
done

# Ensure superuser exists
# Method 1: Try docker exec (when running from host)
if command -v docker &> /dev/null && docker ps --filter name=setbaas-pb --format '{{.Names}}' 2>/dev/null | grep -q setbaas-pb; then
  docker exec setbaas-pb pocketbase superuser upsert "$ADMIN_EMAIL" "$ADMIN_PASSWORD" 2>/dev/null || true
fi

# Method 2: Try creating via API (works on fresh install when no superusers exist)
curl -sf "$PB_URL/api/collections/_superusers/records" \
  -X POST -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"passwordConfirm\":\"$ADMIN_PASSWORD\"}" > /dev/null 2>&1 || true

# Authenticate
TOKEN=$(curl -sf "$PB_URL/api/collections/_superusers/auth-with-password" \
  -X POST -H "Content-Type: application/json" \
  -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" \
  | jq -r '.token')

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to authenticate as superuser"
  exit 1
fi
echo "✅ Authenticated as $ADMIN_EMAIL"

# Helper: create or update a collection
# Usage: ensure_collection '{"name":"...", "type":"...", "fields":[...], ...}'
ensure_collection() {
  local DEF="$1"
  local NAME=$(echo "$DEF" | jq -r '.name')

  # Check if collection exists
  local STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "$PB_URL/api/collections/$NAME" \
    -H "Authorization: Bearer $TOKEN")

  if [ "$STATUS" = "200" ]; then
    # Collection exists — skip (don't overwrite fields to preserve data)
    echo "  ✓ $NAME (exists)"
  else
    # Create new collection
    curl -sf "$PB_URL/api/collections" -X POST \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "$DEF" > /dev/null
    echo "  ✓ $NAME (created)"
  fi
}

# Helper to get collection ID by name (for relations)
get_col_id() {
  curl -sf "$PB_URL/api/collections/$1" -H "Authorization: Bearer $TOKEN" \
    | jq -r '.id'
}

echo ""
echo "📦 Creating/updating collections..."

# === 1. Teams ===
ensure_collection '{
  "name": "teams",
  "type": "base",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "nevobo_code", "type": "text", "required": false},
    {"name": "nevobo_team_type", "type": "text", "required": false},
    {"name": "nevobo_team_number", "type": "number", "required": false},
    {"name": "nevobo_url", "type": "url", "required": false}
  ],
  "listRule": "",
  "viewRule": "",
  "createRule": "",
  "updateRule": "",
  "deleteRule": ""
}'

# === 2. Seasons ===
ensure_collection '{
  "name": "seasons",
  "type": "base",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "start_year", "type": "number", "required": true},
    {"name": "end_year", "type": "number", "required": true}
  ],
  "listRule": "",
  "viewRule": "",
  "createRule": "",
  "updateRule": "",
  "deleteRule": ""
}'

# === 3. Players ===
ensure_collection '{
  "name": "players",
  "type": "base",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "photo", "type": "file", "required": false, "maxSelect": 1, "maxSize": 5242880, "mimeTypes": ["image/jpeg","image/png","image/webp"], "thumbs": ["100x100","200x200"]},
    {"name": "position", "type": "select", "required": false, "values": ["setter","outside_hitter","opposite","middle_blocker","libero","defensive_specialist"], "maxSelect": 6},
    {"name": "status", "type": "select", "required": true, "values": ["active","injured","inactive"], "maxSelect": 1},
    {"name": "jersey_number", "type": "number", "required": false}
  ],
  "listRule": "",
  "viewRule": "",
  "createRule": "",
  "updateRule": "",
  "deleteRule": ""
}'

# === 4. Competencies ===
ensure_collection '{
  "name": "competencies",
  "type": "base",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "category", "type": "select", "required": true, "values": ["technical","tactical","physical","mental"], "maxSelect": 1}
  ],
  "listRule": "",
  "viewRule": "",
  "createRule": "",
  "updateRule": "",
  "deleteRule": ""
}'

# Get IDs for relations
TEAMS_ID=$(get_col_id "teams")
SEASONS_ID=$(get_col_id "seasons")
PLAYERS_ID=$(get_col_id "players")
COMPETENCIES_ID=$(get_col_id "competencies")

# === 5. Player Competencies ===
ensure_collection "{
  \"name\": \"player_competencies\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"player\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$PLAYERS_ID\", \"maxSelect\": 1},
    {\"name\": \"competency\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$COMPETENCIES_ID\", \"maxSelect\": 1},
    {\"name\": \"rating\", \"type\": \"number\", \"required\": true},
    {\"name\": \"date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"notes\", \"type\": \"text\", \"required\": false},
    {\"name\": \"created_by\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 6. Trainings ===
ensure_collection "{
  \"name\": \"trainings\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"overall_rating\", \"type\": \"number\", \"required\": false},
    {\"name\": \"general_comments\", \"type\": \"text\", \"required\": false},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"season\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$SEASONS_ID\", \"maxSelect\": 1},
    {\"name\": \"template\", \"type\": \"text\", \"required\": false},
    {\"name\": \"status\", \"type\": \"select\", \"required\": false, \"values\": [\"open\",\"closed\"], \"maxSelect\": 1},
    {\"name\": \"content\", \"type\": \"editor\", \"required\": false},
    {\"name\": \"created_by\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

TRAININGS_ID=$(get_col_id "trainings")

# === 7. Training Attendance ===
ensure_collection "{
  \"name\": \"training_attendance\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"training\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$TRAININGS_ID\", \"maxSelect\": 1},
    {\"name\": \"player\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$PLAYERS_ID\", \"maxSelect\": 1},
    {\"name\": \"status\", \"type\": \"select\", \"required\": true, \"values\": [\"present\",\"absent\",\"late\",\"sick\",\"injured\"], \"maxSelect\": 1},
    {\"name\": \"player_rating\", \"type\": \"number\", \"required\": false},
    {\"name\": \"player_notes\", \"type\": \"text\", \"required\": false}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 8. Matches ===
ensure_collection "{
  \"name\": \"matches\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"opponent\", \"type\": \"text\", \"required\": true},
    {\"name\": \"home_away\", \"type\": \"select\", \"required\": false, \"values\": [\"home\",\"away\"], \"maxSelect\": 1},
    {\"name\": \"score_team\", \"type\": \"number\", \"required\": false},
    {\"name\": \"score_opponent\", \"type\": \"number\", \"required\": false},
    {\"name\": \"set_scores\", \"type\": \"json\", \"required\": false},
    {\"name\": \"general_notes\", \"type\": \"text\", \"required\": false},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"season\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$SEASONS_ID\", \"maxSelect\": 1},
    {\"name\": \"lineups\", \"type\": \"json\", \"required\": false},
    {\"name\": \"game_system\", \"type\": \"json\", \"required\": false},
    {\"name\": \"substitutions\", \"type\": \"json\", \"required\": false},
    {\"name\": \"timeouts\", \"type\": \"json\", \"required\": false},
    {\"name\": \"created_by\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1},
    {\"name\": \"location\", \"type\": \"text\", \"required\": false},
    {\"name\": \"nevobo_uuid\", \"type\": \"text\", \"required\": false},
    {\"name\": \"nevobo_code\", \"type\": \"text\", \"required\": false}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

MATCHES_ID=$(get_col_id "matches")

# === 9. Match Player Stats ===
ensure_collection "{
  \"name\": \"match_player_stats\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"match\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$MATCHES_ID\", \"maxSelect\": 1},
    {\"name\": \"player\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$PLAYERS_ID\", \"maxSelect\": 1},
    {\"name\": \"position_points\", \"type\": \"json\", \"required\": false},
    {\"name\": \"playing_time\", \"type\": \"number\", \"required\": false},
    {\"name\": \"notes\", \"type\": \"text\", \"required\": false}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 10. Team Players ===
ensure_collection "{
  \"name\": \"team_players\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"team\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"season\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$SEASONS_ID\", \"maxSelect\": 1},
    {\"name\": \"player\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$PLAYERS_ID\", \"maxSelect\": 1}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 11. Team Access ===
ensure_collection "{
  \"name\": \"team_access\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"user\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"role\", \"type\": \"select\", \"required\": true, \"values\": [\"admin\",\"coach\",\"viewer\"], \"maxSelect\": 1}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 12. Training Templates ===
ensure_collection "{
  \"name\": \"training_templates\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"name\", \"type\": \"text\", \"required\": true},
    {\"name\": \"type\", \"type\": \"select\", \"required\": false, \"values\": [\"serve\",\"pass\",\"attack\",\"block\",\"defense\",\"setting\",\"all_round\",\"game\",\"conditioning\"], \"maxSelect\": 1},
    {\"name\": \"content\", \"type\": \"editor\", \"required\": false},
    {\"name\": \"notes\", \"type\": \"text\", \"required\": false},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"season\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$SEASONS_ID\", \"maxSelect\": 1}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 13. Training Plan ===
ensure_collection "{
  \"name\": \"training_plan\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"template\", \"type\": \"text\", \"required\": false},
    {\"name\": \"title\", \"type\": \"text\", \"required\": false},
    {\"name\": \"content\", \"type\": \"editor\", \"required\": false},
    {\"name\": \"notes\", \"type\": \"text\", \"required\": false},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"season\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$SEASONS_ID\", \"maxSelect\": 1}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 14. Season Periods (Periodization) ===
ensure_collection "{
  \"name\": \"season_periods\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"name\", \"type\": \"text\", \"required\": true},
    {\"name\": \"phase\", \"type\": \"select\", \"required\": false, \"values\": [\"preparation\",\"competition_1\",\"winter_break\",\"competition_2\",\"playoffs\",\"off_season\"], \"maxSelect\": 1},
    {\"name\": \"start_date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"end_date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"goals_technical\", \"type\": \"text\", \"required\": false},
    {\"name\": \"goals_tactical\", \"type\": \"text\", \"required\": false},
    {\"name\": \"goals_physical\", \"type\": \"text\", \"required\": false},
    {\"name\": \"goals_mental\", \"type\": \"text\", \"required\": false},
    {\"name\": \"notes\", \"type\": \"text\", \"required\": false},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"season\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$SEASONS_ID\", \"maxSelect\": 1}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

# === 15. Invitations ===
ensure_collection "{
  \"name\": \"invitations\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"email\", \"type\": \"email\", \"required\": true},
    {\"name\": \"token\", \"type\": \"text\", \"required\": true},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"role\", \"type\": \"select\", \"required\": true, \"values\": [\"admin\",\"coach\",\"viewer\"], \"maxSelect\": 1},
    {\"name\": \"status\", \"type\": \"select\", \"required\": true, \"values\": [\"pending\",\"accepted\",\"expired\"], \"maxSelect\": 1},
    {\"name\": \"invited_by\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1},
    {\"name\": \"expires_at\", \"type\": \"date\", \"required\": true}
  ],
  \"listRule\": \"\",
  \"viewRule\": \"\",
  \"createRule\": \"\",
  \"updateRule\": \"\",
  \"deleteRule\": \"\"
}"

echo ""
echo "🔐 Configuring Google OAuth..."

# Set PocketBase application URL for OAuth redirects
SITE_URL="${SITE_URL:-}"
if [ -n "$SITE_URL" ]; then
  curl -sf "$PB_URL/api/settings" -X PATCH \
    -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
    -d "{\"meta\": {\"appURL\": \"$SITE_URL\"}}" > /dev/null && echo "  ✓ App URL set to $SITE_URL" || echo "  ⚠ Could not set app URL (older PB version?)"
fi

# Configure OAuth if env vars are set
GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-}"
GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-}"

if [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ]; then
  # Enable OAuth2 on users collection via direct PATCH
  OAUTH_BODY=$(cat <<EOJSON
{
  "oauth2": {
    "enabled": true,
    "mappedFields": {"id": "", "name": "name", "avatarURL": "avatar"},
    "providers": [{"name": "google", "clientId": "$GOOGLE_CLIENT_ID", "clientSecret": "$GOOGLE_CLIENT_SECRET", "authURL": "", "tokenURL": "", "displayName": "Google", "pkce": null}]
  }
}
EOJSON
)
  curl -sf "$PB_URL/api/collections/users" -X PATCH \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "$OAUTH_BODY" > /dev/null && echo "  ✓ Google OAuth enabled" || echo "  ✗ OAuth configuration failed"
else
  echo "  ⚠ Skipped (set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET env vars)"
fi

echo ""
echo "🏐 Seeding default team & season..."

# Create default team if none exists
TEAM_COUNT=$(curl -sf "$PB_URL/api/collections/teams/records?perPage=1" \
  -H "Authorization: Bearer $TOKEN" | jq -r ".totalItems // 0")

if [ "$TEAM_COUNT" = "0" ]; then
  TEAM_ID=$(curl -sf "$PB_URL/api/collections/teams/records" -X POST \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"Zovoc MB1"}' | jq -r '.id')
  echo "  ✓ Team 'Zovoc MB1' created ($TEAM_ID)"
else
  echo "  ✓ Team exists (skipped)"
fi

# Create default season if none exists
SEASON_COUNT=$(curl -sf "$PB_URL/api/collections/seasons/records?perPage=1" \
  -H "Authorization: Bearer $TOKEN" | jq -r ".totalItems // 0")

if [ "$SEASON_COUNT" = "0" ]; then
  curl -sf "$PB_URL/api/collections/seasons/records" -X POST \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"name":"2026-2027","start_year":2026,"end_year":2027}' > /dev/null
  echo "  ✓ Seizoen '2026-2027' created"
else
  echo "  ✓ Seizoen exists (skipped)"
fi

echo ""
echo "✅ Setup complete! All collections are ready."
