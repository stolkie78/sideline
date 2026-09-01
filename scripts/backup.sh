#!/bin/bash
# SetBaas Backup Script
# Creates a timestamped backup of the PocketBase database
#
# Usage:
#   ./scripts/backup.sh                    # Backup to ./backups/
#   ./scripts/backup.sh /path/to/folder    # Backup to custom location
#   
# Cron example (dagelijks om 3:00):
#   0 3 * * * cd /path/to/setbaas && ./scripts/backup.sh

set -e

BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="setbaas_backup_${TIMESTAMP}.tar.gz"

# Detect compose file
if [ -f docker-compose.prod.yml ] && docker compose -f docker-compose.prod.yml ps --services 2>/dev/null | grep -q pocketbase; then
    COMPOSE_FILE="docker-compose.prod.yml"
else
    COMPOSE_FILE="docker-compose.yml"
fi

echo "🏐 SetBaas Backup"
echo "  Compose: $COMPOSE_FILE"
echo "  Target:  $BACKUP_DIR/$BACKUP_FILE"

# Check if PocketBase is running
if ! docker compose -f "$COMPOSE_FILE" ps --services --filter status=running | grep -q pocketbase; then
    echo "❌ PocketBase container is not running"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create temp directory for backup files
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Copy PocketBase data directory (database + uploads)
echo "📦 Copying PocketBase data..."
docker compose -f "$COMPOSE_FILE" cp pocketbase:/pb/pb_data "$TMPDIR/pb_data"

# Create compressed archive
echo "📦 Creating archive..."
tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C "$TMPDIR" .

# Show result
SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
echo ""
echo "✅ Backup compleet!"
echo "  Bestand: $BACKUP_DIR/$BACKUP_FILE ($SIZE)"
echo ""

# Cleanup old backups (keep last 7)
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/setbaas_backup_*.tar.gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 7 ]; then
    echo "🧹 Opruimen oude backups (behoud laatste 7)..."
    ls -1t "$BACKUP_DIR"/setbaas_backup_*.tar.gz | tail -n +8 | xargs rm -f
    echo "  Verwijderd: $((BACKUP_COUNT - 7)) oude backup(s)"
fi
