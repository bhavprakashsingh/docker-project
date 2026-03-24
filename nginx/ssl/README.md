# SSL Certificates Directory

Place your SSL certificates in this directory.

## Required Files

- `fullchain.pem` - Full certificate chain
- `privkey.pem` - Private key

## Obtaining SSL Certificates

### Option 1: Let's Encrypt (Recommended for production)

```bash
# Install certbot
sudo apt-get update
sudo apt-get install certbot

# Obtain certificate
sudo certbot certonly --standalone -d yourdomain.com -d www.yourdomain.com

# Copy certificates
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem ./nginx/ssl/
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem ./nginx/ssl/
sudo chmod 600 ./nginx/ssl/*.pem
```

### Option 2: Self-Signed Certificate (Development/Testing only)

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ./nginx/ssl/privkey.pem \
  -out ./nginx/ssl/fullchain.pem \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=yourdomain.com"

chmod 600 ./nginx/ssl/*.pem
```

## Certificate Renewal

Let's Encrypt certificates expire after 90 days. Set up automatic renewal:

```bash
# Test renewal
sudo certbot renew --dry-run

# Add to crontab for automatic renewal
0 0 * * 0 certbot renew --quiet && docker-compose -f docker-compose.prod.yml restart nginx
```

## Security Notes

- Never commit actual certificate files to version control
- Keep private keys secure with 600 permissions
- Use strong encryption (RSA 2048+ or ECDSA)
- Monitor certificate expiration dates
- Implement HSTS after testing SSL configuration