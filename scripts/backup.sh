#!/bin/sh
set -e

# Database backup script for PostgreSQL
# This script creates timestamped backups and manages retention

BACKUP_DIR="/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

# Support Docker secret files (POSTGRES_PASSWORD_FILE)
if [ -z "${POSTGRES_PASSWORD}" ] && [ -n "${POSTGRES_PASSWORD_FILE}" ] && [ -f "${POSTGRES_PASSWORD_FILE}" ]; then
    POSTGRES_PASSWORD=$(cat "${POSTGRES_PASSWORD_FILE}")
fi

if [ -z "${POSTGRES_PASSWORD}" ]; then
    echo "ERROR: POSTGRES_PASSWORD or POSTGRES_PASSWORD_FILE must be set"
    exit 1
fi

echo "Starting database backup at $(date)"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Perform backup
echo "Creating backup: ${BACKUP_FILE}"
PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    -h db \
    -U "${POSTGRES_USER}" \
    -d "${POSTGRES_DB}" \
    --format=plain \
    --no-owner \
    --no-acl \
    | gzip > "${BACKUP_FILE}"

# Verify backup was created
if [ -f "${BACKUP_FILE}" ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo "Backup completed successfully: ${BACKUP_FILE} (${BACKUP_SIZE})"
else
    echo "ERROR: Backup file was not created!"
    exit 1
fi

# Remove old backups
echo "Cleaning up backups older than ${RETENTION_DAYS} days"
find "${BACKUP_DIR}" -name "backup_*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete

# List remaining backups
echo "Current backups:"
ls -lh "${BACKUP_DIR}"/backup_*.sql.gz 2>/dev/null || echo "No backups found"

echo "Backup process completed at $(date)"

# Made with Bob
