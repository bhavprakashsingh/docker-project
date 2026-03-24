# Secrets Directory

This directory contains sensitive configuration files used by Docker secrets.

## Setup

1. Generate strong random secrets:
```bash
# Generate JWT secrets (32+ characters recommended)
openssl rand -base64 32 > jwt_access_secret.txt
openssl rand -base64 32 > jwt_refresh_secret.txt

# Set database password
echo "your-strong-db-password" > postgres_password.txt
```

2. Set proper permissions:
```bash
chmod 600 secrets/*.txt
```

## Files

- `postgres_password.txt` - PostgreSQL database password
- `jwt_access_secret.txt` - JWT access token secret
- `jwt_refresh_secret.txt` - JWT refresh token secret

## Security Notes

- Never commit actual secret values to version control
- Use strong, randomly generated values in production
- Rotate secrets regularly
- Limit file permissions to owner read-only (600)