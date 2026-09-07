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

# Update users collection API rules. Signing up stays open because the invite
# flow creates an account before logging in, but an account may only be changed
# or removed by its owner.
echo "→ Updating users collection API rules..."
curl -sf -X PATCH "$PB_URL/api/collections/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"viewRule":"@request.auth.id != \"\"","listRule":"@request.auth.id != \"\"","updateRule":"id = @request.auth.id","createRule":"","deleteRule":"id = @request.auth.id"}' > /dev/null 2>&1 && echo "  ✅ Users API rules updated" || echo "  ⚠️ Could not update users API rules"

# Add is_platform_admin flag to users. A platform admin is a narrow built-in
# role (not a superuser): they can only create new clubs and grant the first
# admin to a freshly created club. They cannot see or manage any other data.
echo "→ Ensuring is_platform_admin field on users collection..."
EXISTING_USER_FIELDS=$(curl -sf "$PB_URL/api/collections/users" -H "Authorization: Bearer $TOKEN" | jq -c '.fields')
HAS_PLATFORM_ADMIN_FIELD=$(echo "$EXISTING_USER_FIELDS" | jq 'any(.name == "is_platform_admin")')
if [ "$HAS_PLATFORM_ADMIN_FIELD" != "true" ]; then
  MERGED_USER_FIELDS=$(echo "$EXISTING_USER_FIELDS" | jq -c '. + [{"name":"is_platform_admin","type":"bool","required":false}]')
  curl -sf -X PATCH "$PB_URL/api/collections/users" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"fields\": $MERGED_USER_FIELDS}" > /dev/null \
    && echo "  ✅ is_platform_admin field added" || echo "  ⚠️ Could not add is_platform_admin field"
else
  echo "  ✅ is_platform_admin field exists"
fi

# Helper: create or update a collection
# Usage: ensure_collection '{"name":"...", "type":"...", "fields":[...], ...}'
ensure_collection() {
  local DEF="$1"
  local NAME=$(echo "$DEF" | jq -r '.name')
  local SECURED_DEF=$(echo "$DEF" | jq -c '
    .listRule = (if .listRule == "" then "@request.auth.id != \"\"" else .listRule end)
    | .viewRule = (if .viewRule == "" then "@request.auth.id != \"\"" else .viewRule end)
    | .createRule = (if .createRule == "" then "@request.auth.id != \"\"" else .createRule end)
    | .updateRule = (if .updateRule == "" then "@request.auth.id != \"\"" else .updateRule end)
    | .deleteRule = (if .deleteRule == "" then "@request.auth.id != \"\"" else .deleteRule end)
  ')

  # Check if collection exists
  local STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "$PB_URL/api/collections/$NAME" \
    -H "Authorization: Bearer $TOKEN")

  if [ "$STATUS" = "200" ]; then
    # Collection exists — merge new fields (add missing ones, don't remove existing)
    local EXISTING_FIELDS=$(curl -sf "$PB_URL/api/collections/$NAME" \
      -H "Authorization: Bearer $TOKEN" | jq -c '.fields')
    local NEW_FIELDS=$(echo "$DEF" | jq -c '.fields')
    # jq only — the setup container has no python3, and a silent failure here
    # would leave existing collections without their new fields.
    local MERGED=$(jq -n --argjson existing "$EXISTING_FIELDS" --argjson new "$NEW_FIELDS" '
      ($existing | map(.name)) as $names
      | ($new | map(select((.name | IN($names[])) | not))) as $added
      | if ($added | length) > 0 then {fields: ($existing + $added)} else empty end
    ')
    if [ -n "$MERGED" ]; then
      curl -sf -X PATCH "$PB_URL/api/collections/$NAME" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "$MERGED" > /dev/null
      echo "  ✓ $NAME (updated with new fields)"
    else
      echo "  ✓ $NAME (exists, up to date)"
    fi
    # Update API rules if specified
    local RULES=$(echo "$SECURED_DEF" | jq -c '{listRule,viewRule,createRule,updateRule,deleteRule} | with_entries(select(.value != null))')
    if [ "$RULES" != "{}" ]; then
      curl -sf -X PATCH "$PB_URL/api/collections/$NAME" \
        -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
        -d "$RULES" > /dev/null 2>&1 \
        || echo "  ⚠️ Could not apply API rules for $NAME"
    fi
  else
    # Create new collection
    curl -sf "$PB_URL/api/collections" -X POST \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "$SECURED_DEF" > /dev/null
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

# === 0. Clubs ===
ensure_collection '{
  "name": "clubs",
  "type": "base",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "short_name", "type": "text", "required": false},
    {"name": "city", "type": "text", "required": false}
  ],
  "listRule": "@request.auth.id != \"\"",
  "viewRule": "@request.auth.id != \"\"",
  "createRule": "@request.auth.id != \"\"",
  "updateRule": "@request.auth.id != \"\"",
  "deleteRule": "@request.auth.id != \"\""
}'

CLUBS_ID=$(get_col_id "clubs")

# === 1. Teams ===
ensure_collection "{
  \"name\": \"teams\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"club\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$CLUBS_ID\", \"maxSelect\": 1},
    {\"name\": \"name\", \"type\": \"text\", \"required\": true},
    {\"name\": \"nevobo_code\", \"type\": \"text\", \"required\": false},
    {\"name\": \"nevobo_team_type\", \"type\": \"text\", \"required\": false},
    {\"name\": \"nevobo_team_number\", \"type\": \"number\", \"required\": false},
    {\"name\": \"nevobo_url\", \"type\": \"url\", \"required\": false}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"

# === 2. Seasons ===
ensure_collection '{
  "name": "seasons",
  "type": "base",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "start_year", "type": "number", "required": true},
    {"name": "end_year", "type": "number", "required": true}
  ],
  "listRule": "@request.auth.id != \"\"",
  "viewRule": "@request.auth.id != \"\"",
  "createRule": "@request.auth.id != \"\"",
  "updateRule": "@request.auth.id != \"\"",
  "deleteRule": "@request.auth.id != \"\""
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
    {"name": "jersey_number", "type": "number", "required": false, "min": 1, "max": 999, "onlyInt": true},
    {"name": "email", "type": "email", "required": false},
    {"name": "user_id", "type": "relation", "required": false, "collectionId": "_pb_users_auth_", "maxSelect": 1}
  ],
  "listRule": "@request.auth.id != \"\"",
  "viewRule": "@request.auth.id != \"\"",
  "createRule": "@request.auth.id != \"\"",
  "updateRule": "@request.auth.id != \"\"",
  "deleteRule": "@request.auth.id != \"\""
}'

# === 4. Competencies ===
ensure_collection '{
  "name": "competencies",
  "type": "base",
  "fields": [
    {"name": "name", "type": "text", "required": true},
    {"name": "category", "type": "select", "required": true, "values": ["technical","tactical","physical","mental"], "maxSelect": 1}
  ],
  "listRule": "@request.auth.id != \"\"",
  "viewRule": "@request.auth.id != \"\"",
  "createRule": "@request.auth.id != \"\"",
  "updateRule": "@request.auth.id != \"\"",
  "deleteRule": "@request.auth.id != \"\""
}'

# Get IDs for relations
TEAMS_ID=$(get_col_id "teams")
SEASONS_ID=$(get_col_id "seasons")
PLAYERS_ID=$(get_col_id "players")
COMPETENCIES_ID=$(get_col_id "competencies")

# === 4b. Club Access (multi-user, club-scoped) ===
# Replaces team_access: granting a role on a club gives access to every team
# under it. default_team lets someone with multiple teams in the same club
# pick which one loads by default.
ensure_collection "{
  \"name\": \"club_access\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"user\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1},
    {\"name\": \"club\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$CLUBS_ID\", \"maxSelect\": 1},
    {\"name\": \"role\", \"type\": \"select\", \"required\": true, \"values\": [\"admin\",\"user\",\"viewer\"], \"maxSelect\": 1},
    {\"name\": \"default_team\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"is_trainer\", \"type\": \"bool\", \"required\": false},
    {\"name\": \"is_player\", \"type\": \"bool\", \"required\": false},
    {\"name\": \"is_parent\", \"type\": \"bool\", \"required\": false}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"
CLUB_ACCESS_ID=$(get_col_id "club_access")

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
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
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
    {\"name\": \"status\", \"type\": \"select\", \"required\": false, \"values\": [\"open\",\"active\",\"closed\"], \"maxSelect\": 1},
    {\"name\": \"content\", \"type\": \"editor\", \"required\": false},
    {\"name\": \"created_by\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1},
    {\"name\": \"trainer\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 10},
    {\"name\": \"checkout_question\", \"type\": \"text\", \"required\": false}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
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
    {\"name\": \"player_notes\", \"type\": \"text\", \"required\": false},
    {\"name\": \"happiness\", \"type\": \"number\", \"required\": false},
    {\"name\": \"fitness\", \"type\": \"number\", \"required\": false},
    {\"name\": \"checkout_selected\", \"type\": \"bool\", \"required\": false},
    {\"name\": \"checkout_answer\", \"type\": \"text\", \"required\": false}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"

# === 8. Matches ===
ensure_collection "{
  \"name\": \"matches\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"date\", \"type\": \"date\", \"required\": true},
    {\"name\": \"opponent\", \"type\": \"text\", \"required\": true},
    {\"name\": \"status\", \"type\": \"select\", \"required\": false, \"values\": [\"open\",\"played\"], \"maxSelect\": 1},
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
    {\"name\": \"nevobo_code\", \"type\": \"text\", \"required\": false},
    {\"name\": \"coach\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 10}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
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
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
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
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"

# === 10b. Match Attendance ===
MATCHES_ID=$(get_col_id "matches")
ensure_collection "{
  \"name\": \"match_attendance\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"match\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$MATCHES_ID\", \"maxSelect\": 1},
    {\"name\": \"player\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$PLAYERS_ID\", \"maxSelect\": 1},
    {\"name\": \"status\", \"type\": \"select\", \"required\": true, \"values\": [\"present\",\"absent\",\"sick\",\"injured\"], \"maxSelect\": 1}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"

# === 11. Team Access ===
ensure_collection "{
  \"name\": \"team_access\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"user\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1},
    {\"name\": \"team\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$TEAMS_ID\", \"maxSelect\": 1},
    {\"name\": \"role\", \"type\": \"select\", \"required\": true, \"values\": [\"admin\",\"user\",\"viewer\"], \"maxSelect\": 1},
    {\"name\": \"is_trainer\", \"type\": \"bool\", \"required\": false},
    {\"name\": \"is_player\", \"type\": \"bool\", \"required\": false},
    {\"name\": \"is_parent\", \"type\": \"bool\", \"required\": false}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
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
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
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
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
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
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"

# === 15. Invitations ===
ensure_collection "{
  \"name\": \"invitations\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"email\", \"type\": \"email\", \"required\": true},
    {\"name\": \"token\", \"type\": \"text\", \"required\": true},
    {\"name\": \"club\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$CLUBS_ID\", \"maxSelect\": 1},
    {\"name\": \"role\", \"type\": \"select\", \"required\": true, \"values\": [\"admin\",\"user\",\"viewer\"], \"maxSelect\": 1},
    {\"name\": \"status\", \"type\": \"select\", \"required\": true, \"values\": [\"pending\",\"accepted\",\"expired\"], \"maxSelect\": 1},
    {\"name\": \"invited_by\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"_pb_users_auth_\", \"maxSelect\": 1},
    {\"name\": \"expires_at\", \"type\": \"date\", \"required\": true}
  ],
  \"listRule\": \"id != \\\"\\\"\",
  \"viewRule\": \"id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"

# Legacy installs required the (now removed from the definition above, but
# never dropped) "team" field and only allowed admin/coach/player as role
# values. Loosen "team" so it's no longer required and fix the role select so
# admin/user/viewer invites actually validate.
INVITATIONS_FIELDS=$(curl -sf "$PB_URL/api/collections/invitations" -H "Authorization: Bearer $TOKEN" | jq -c '.fields')
NEEDS_INVITATIONS_FIX=$(echo "$INVITATIONS_FIELDS" | jq '
  (map(select(.name == "team" and .required == true)) | length > 0)
  or (map(select(.name == "role")) | (.[0].values // []) != ["admin","user","viewer"])
')
if [ "$NEEDS_INVITATIONS_FIX" = "true" ]; then
  echo "  🔄 Fixing legacy invitations fields (team optional, role values)"
  FIXED_INVITATIONS_FIELDS=$(echo "$INVITATIONS_FIELDS" | jq -c '
    map(
      if .name == "team" then . + {"required": false}
      elif .name == "role" then . + {"values": ["admin","user","viewer"]}
      else . end
    )
  ')
  curl -sf -X PATCH "$PB_URL/api/collections/invitations" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"fields\": $FIXED_INVITATIONS_FIELDS}" > /dev/null \
    && echo "  ✓ invitations fields fixed" || echo "  ⚠️ Could not fix invitations fields"
fi

echo ""
echo "🔐 Configuring Google OAuth..."

# === 16. Player Availability ===
TRAININGS_ID=$(get_col_id "trainings")
MATCHES_ID=$(get_col_id "matches")
ensure_collection "{
  \"name\": \"player_availability\",
  \"type\": \"base\",
  \"fields\": [
    {\"name\": \"player\", \"type\": \"relation\", \"required\": true, \"collectionId\": \"$PLAYERS_ID\", \"maxSelect\": 1},
    {\"name\": \"training\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$TRAININGS_ID\", \"maxSelect\": 1},
    {\"name\": \"match\", \"type\": \"relation\", \"required\": false, \"collectionId\": \"$MATCHES_ID\", \"maxSelect\": 1},
    {\"name\": \"status\", \"type\": \"select\", \"required\": true, \"values\": [\"available\",\"unavailable\",\"uncertain\"], \"maxSelect\": 1},
    {\"name\": \"reason\", \"type\": \"text\", \"required\": false}
  ],
  \"listRule\": \"@request.auth.id != \\\"\\\"\",
  \"viewRule\": \"@request.auth.id != \\\"\\\"\",
  \"createRule\": \"@request.auth.id != \\\"\\\"\",
  \"updateRule\": \"@request.auth.id != \\\"\\\"\",
  \"deleteRule\": \"@request.auth.id != \\\"\\\"\"
}"

# Set PocketBase application URL for OAuth redirects
SITE_URL="${SITE_URL:-}"
if [ -n "$SITE_URL" ]; then
  curl -sf "$PB_URL/api/settings" -X PATCH \
    -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
    -d "{\"meta\": {\"appURL\": \"$SITE_URL\"}, \"trustedProxy\": {\"headers\": [\"X-Forwarded-For\", \"X-Forwarded-Proto\", \"X-Forwarded-Host\"], \"useLeftmostIP\": true}}" > /dev/null && echo "  ✓ App URL set to $SITE_URL (with trusted proxy)" || echo "  ⚠ Could not set app URL (older PB version?)"
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
echo "🏛  Seeding clubs..."

# Idempotent club creation; echoes the club id on stdout
ensure_club() {
  local NAME="$1"
  local SHORT="$2"
  local EXISTING=$(curl -sf --get "$PB_URL/api/collections/clubs/records" \
    --data-urlencode "filter=name='$NAME'" --data-urlencode "perPage=1" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].id // empty')

  if [ -n "$EXISTING" ]; then
    echo "  ✓ Club '$NAME' exists ($EXISTING)" >&2
    echo "$EXISTING"
  else
    local CREATED=$(curl -sf "$PB_URL/api/collections/clubs/records" -X POST \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"name\":\"$NAME\",\"short_name\":\"$SHORT\"}" | jq -r '.id')
    echo "  ✓ Club '$NAME' created ($CREATED)" >&2
    echo "$CREATED"
  fi
}

ZOVOC_ID=$(ensure_club "Zovoc" "ZOVOC")
ZVH_ID=$(ensure_club "ZVH" "ZVH")

echo ""
echo "🏐 Seeding default team & season..."

# Create default team if none exists
TEAM_COUNT=$(curl -sf "$PB_URL/api/collections/teams/records?perPage=1" \
  -H "Authorization: Bearer $TOKEN" | jq -r ".totalItems // 0")

if [ "$TEAM_COUNT" = "0" ]; then
  TEAM_ID=$(curl -sf "$PB_URL/api/collections/teams/records" -X POST \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d "{\"name\":\"Zovoc MB1\",\"club\":\"$ZOVOC_ID\"}" | jq -r '.id')
  echo "  ✓ Team 'Zovoc MB1' created ($TEAM_ID)"
else
  echo "  ✓ Team exists (skipped)"
fi

# Link teams without a club, matching the club name against the team name
ORPHAN_TEAMS=$(curl -sf --get "$PB_URL/api/collections/teams/records" \
  --data-urlencode "filter=club=''" --data-urlencode "perPage=200" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.items[] | "\(.id)|\(.name)"')

if [ -n "$ORPHAN_TEAMS" ]; then
  echo "$ORPHAN_TEAMS" | while IFS='|' read -r T TNAME; do
    [ -z "$T" ] && continue
    CLUB_ID="$ZOVOC_ID"
    CLUB_NAME="Zovoc"
    case "$(echo "$TNAME" | tr '[:upper:]' '[:lower:]')" in
      zvh*) CLUB_ID="$ZVH_ID"; CLUB_NAME="ZVH" ;;
    esac
    [ -z "$CLUB_ID" ] && continue
    curl -sf -X PATCH "$PB_URL/api/collections/teams/records/$T" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"club\":\"$CLUB_ID\"}" > /dev/null && echo "  ✓ Team '$TNAME' linked to $CLUB_NAME"
  done
else
  echo "  ✓ All teams already linked to a club"
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
echo "🔄 Migrating team_access naar club_access..."

# team_access granted a role per team. Access is now granted per club (which
# covers every team under it), so fold each user's team_access records into
# one club_access record per club they had any team access in, keeping the
# highest role and OR-ing the trainer/player/parent flags. Idempotent: a user
# who already has a club_access record for that club is left untouched.
TEAM_CLUB_MAP=$(curl -sf --get "$PB_URL/api/collections/teams/records" \
  --data-urlencode "perPage=200" -H "Authorization: Bearer $TOKEN" \
  | jq -c '[.items[] | select(.club != "") | {(.id): .club}] | add // {}')

ALL_TEAM_ACCESS=$(curl -sf --get "$PB_URL/api/collections/team_access/records" \
  --data-urlencode "perPage=500" -H "Authorization: Bearer $TOKEN" | jq -c '.items')

MIGRATIONS=$(jq -n --argjson teamClub "$TEAM_CLUB_MAP" --argjson access "$ALL_TEAM_ACCESS" '
  def roleRank: {"admin":3,"user":2,"viewer":1}[.] // 0;
  [$access[]
    | . as $a
    | ($teamClub[$a.team] // null) as $club
    | select($club != null)
    | {user: $a.user, club: $club, role: $a.role, is_trainer: ($a.is_trainer // false), is_player: ($a.is_player // false), is_parent: ($a.is_parent // false)}
  ]
  | group_by(.user + "|" + .club)
  | map({
      user: .[0].user,
      club: .[0].club,
      role: (reduce .[] as $x (""; if ($x.role | roleRank) > (. | roleRank) then $x.role else . end)),
      is_trainer: (map(.is_trainer) | any),
      is_player: (map(.is_player) | any),
      is_parent: (map(.is_parent) | any)
    })
')

MIGRATED_COUNT=0
while IFS= read -r ROW; do
  [ -z "$ROW" ] && continue
  U=$(echo "$ROW" | jq -r '.user')
  C=$(echo "$ROW" | jq -r '.club')
  EXISTING=$(curl -sf --get "$PB_URL/api/collections/club_access/records" \
    --data-urlencode "filter=user='$U' && club='$C'" --data-urlencode "perPage=1" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].id // empty')
  if [ -z "$EXISTING" ]; then
    curl -sf "$PB_URL/api/collections/club_access/records" -X POST \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "$ROW" > /dev/null && MIGRATED_COUNT=$((MIGRATED_COUNT + 1))
  fi
done < <(echo "$MIGRATIONS" | jq -c '.[]')
echo "  ✓ $MIGRATED_COUNT club_access record(s) migrated (idempotent, skips existing)"

OWNER_EMAIL="${OWNER_EMAIL:-}"
if [ -n "$OWNER_EMAIL" ]; then
  echo ""
  echo "👑 Granting admin access to $OWNER_EMAIL..."
  OWNER_ID=$(curl -sf --get "$PB_URL/api/collections/users/records" \
    --data-urlencode "filter=email='$OWNER_EMAIL'" --data-urlencode "perPage=1" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].id // empty')

  if [ -z "$OWNER_ID" ]; then
    echo "  ⚠ User $OWNER_EMAIL not found, skipped"
  else
    ALL_CLUBS=$(curl -sf --get "$PB_URL/api/collections/clubs/records" \
      --data-urlencode "perPage=200" \
      -H "Authorization: Bearer $TOKEN" | jq -r '.items[] | "\(.id)|\(.name)"')

    echo "$ALL_CLUBS" | while IFS='|' read -r CID CNAME; do
      [ -z "$CID" ] && continue
      EXISTING=$(curl -sf --get "$PB_URL/api/collections/club_access/records" \
        --data-urlencode "filter=user='$OWNER_ID' && club='$CID'" --data-urlencode "perPage=1" \
        -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].id // empty')

      if [ -z "$EXISTING" ]; then
        curl -sf "$PB_URL/api/collections/club_access/records" -X POST \
          -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
          -d "{\"user\":\"$OWNER_ID\",\"club\":\"$CID\",\"role\":\"admin\"}" > /dev/null \
          && echo "  ✓ Admin access on '$CNAME' granted"
      else
        curl -sf -X PATCH "$PB_URL/api/collections/club_access/records/$EXISTING" \
          -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
          -d '{"role":"admin"}' > /dev/null \
          && echo "  ✓ Admin access on '$CNAME' confirmed"
      fi
    done
  fi
fi

SETBAAS_ADMIN_EMAIL="${SETBAAS_ADMIN_EMAIL:-}"
SETBAAS_ADMIN_PASSWORD="${SETBAAS_ADMIN_PASSWORD:-}"
if [ -n "$SETBAAS_ADMIN_EMAIL" ] && [ -n "$SETBAAS_ADMIN_PASSWORD" ]; then
  echo ""
  echo "🛡️  Ensuring built-in setbaas-admin account ($SETBAAS_ADMIN_EMAIL)..."
  EXISTING_SETBAAS_ADMIN=$(curl -sf --get "$PB_URL/api/collections/users/records" \
    --data-urlencode "filter=email='$SETBAAS_ADMIN_EMAIL'" --data-urlencode "perPage=1" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].id // empty')

  if [ -z "$EXISTING_SETBAAS_ADMIN" ]; then
    curl -sf "$PB_URL/api/collections/users/records" -X POST \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"email\":\"$SETBAAS_ADMIN_EMAIL\",\"password\":\"$SETBAAS_ADMIN_PASSWORD\",\"passwordConfirm\":\"$SETBAAS_ADMIN_PASSWORD\",\"name\":\"SetBaas Admin\",\"verified\":true,\"emailVisibility\":true,\"is_platform_admin\":true}" > /dev/null \
      && echo "  ✓ SetBaas admin account created" || echo "  ⚠️ Could not create setbaas-admin account"
  else
    curl -sf -X PATCH "$PB_URL/api/collections/users/records/$EXISTING_SETBAAS_ADMIN" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d '{"is_platform_admin":true,"verified":true}' > /dev/null \
      && echo "  ✓ SetBaas admin account confirmed (flagged as platform admin)" || echo "  ⚠️ Could not update setbaas-admin account"
  fi
fi

echo ""
echo "🏁 Backfilling match status..."

# Matches without a status get one based on their date: anything in the past is
# considered played, everything else stays open.
backfill_match_status() {
  local FILTER="$1"
  local STATUS="$2"
  local IDS=$(curl -sf --get "$PB_URL/api/collections/matches/records" \
    --data-urlencode "filter=$FILTER" --data-urlencode "perPage=500" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.items[]?.id')

  local COUNT=0
  for ID in $IDS; do
    curl -sf -X PATCH "$PB_URL/api/collections/matches/records/$ID" \
      -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
      -d "{\"status\":\"$STATUS\"}" > /dev/null && COUNT=$((COUNT + 1))
  done
  echo "$COUNT"
}

PLAYED_COUNT=$(backfill_match_status "status='' && date < @now" "played")
OPEN_COUNT=$(backfill_match_status "status='' && date >= @now" "open")
echo "  ✓ $PLAYED_COUNT gespeeld, $OPEN_COUNT open"

echo ""
echo "✅ Setup complete! All collections are ready."
