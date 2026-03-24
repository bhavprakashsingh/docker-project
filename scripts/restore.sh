#!/bin/sh
set -e

# Database restore script for PostgreSQL
# Usage: ./restore.sh <backup_file>

if [ -z "$1" ]; then
    echo "Usage: $0 <backup_file>"
    echo "Example: $0 /backups/backup_20240101_120000.sql.gz"
    echo ""
    echo "Available backups:"
    ls -lh /backups/backup_*.sql.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "ERROR: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "WARNING: This will restore the database from: ${BACKUP_FILE}"
echo "This operation will OVERWRITE the current database!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

echo "Starting database restore at $(date)"

# Drop existing connections
echo "Terminating existing database connections..."
PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h db \
    -U "${POSTGRES_USER}" \
    -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${POSTGRES_DB}' AND pid <> pg_backend_pid();"

# Drop and recreate database
echo "Recreating database..."
PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h db \
    -U "${POSTGRES_USER}" \
    -d postgres \
    -c "DROP DATABASE IF EXISTS ${POSTGRES_DB};"

PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h db \
    -U "${POSTGRES_USER}" \
    -d postgres \
    -c "CREATE DATABASE ${POSTGRES_DB};"

# Restore backup
echo "Restoring backup..."
gunzip -c "${BACKUP_FILE}" | PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h db \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}"

echo "Database restore completed successfully at $(date)"
echo "Please restart your application services to reconnect to the database"

# Made with Bob
