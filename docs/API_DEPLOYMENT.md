# MAPS API Deployment Guide

Guide for deploying the MAPS REST API in production environments.

## Development Server

For local development:

```bash
# Using the launch script
python scripts/run_server.py

# Or using uvicorn directly
uvicorn maps.api.app:create_app --factory --reload --port 8000
```

Access the API at:
- API: http://localhost:8000/api
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Production Deployment

### Using Uvicorn

```bash
# Install production dependencies
pip install uvicorn[standard] gunicorn

# Run with multiple workers
gunicorn maps.api.app:create_app \
    --workers 4 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind 0.0.0.0:8000 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -
```

### Environment Configuration

Create `.env` file:

```bash
# Application
MAPS_APP_NAME="MAPS API"
MAPS_DEBUG=false

# Server
MAPS_HOST=0.0.0.0
MAPS_PORT=8000

# CORS (configure for production)
MAPS_CORS_ORIGINS=["https://yourdomain.com"]

# File upload
MAPS_MAX_UPLOAD_SIZE=104857600  # 100MB in bytes

# Logging
MAPS_LOG_LEVEL=INFO

# Profiles
MAPS_PROFILE_DIRECTORY=/var/maps/profiles
```

### Using Docker

Create `Dockerfile`:

```dockerfile
FROM python:3.9-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/
COPY profiles/ ./profiles/

# Expose port
EXPOSE 8000

# Run application
CMD ["uvicorn", "maps.api.app:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000"]
```

Build and run:

```bash
# Build image
docker build -t maps-api .

# Run container
docker run -d \
    -p 8000:8000 \
    -v $(pwd)/profiles:/app/profiles \
    -v $(pwd)/data:/app/data \
    --name maps-api \
    maps-api
```

### Using Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - ./profiles:/app/profiles
      - ./data:/app/data
    environment:
      - MAPS_DEBUG=false
      - MAPS_LOG_LEVEL=INFO
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - api
    restart: unless-stopped
```

Run:

```bash
docker-compose up -d
```

### Nginx Reverse Proxy

Example `nginx.conf`:

```nginx
upstream maps_api {
    server api:8000;
}

server {
    listen 80;
    server_name api.yourdomain.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    # SSL certificates
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    # Client upload limit
    client_max_body_size 100M;

    location / {
        proxy_pass http://maps_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Timeouts for long-running requests
        proxy_connect_timeout 120s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
}
```

## Security Considerations

### CORS Configuration

Update CORS settings for production in `.env`:

```bash
MAPS_CORS_ORIGINS=["https://yourdomain.com", "https://app.yourdomain.com"]
MAPS_CORS_CREDENTIALS=true
```

### API Rate Limiting

Install slowapi:

```bash
pip install slowapi
```

Add to `app.py`:

```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
```

### Authentication

For production, add authentication:

```python
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Depends, HTTPException, Security

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    token = credentials.credentials
    # Verify token logic here
    if not is_valid_token(token):
        raise HTTPException(status_code=403, detail="Invalid token")
    return token
```

## Monitoring

### Health Checks

The API provides health check endpoints:

```bash
# Kubernetes liveness probe
GET /api/health

# Readiness probe
GET /api/status
```

### Logging

Configure structured logging:

```python
import logging.config

LOGGING_CONFIG = {
    "version": 1,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "standard",
        },
        "file": {
            "class": "logging.handlers.RotatingFileHandler",
            "filename": "maps_api.log",
            "maxBytes": 10485760,  # 10MB
            "backupCount": 5,
            "formatter": "standard",
        },
    },
    "formatters": {
        "standard": {
            "format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
        },
    },
    "root": {
        "level": "INFO",
        "handlers": ["console", "file"],
    },
}

logging.config.dictConfig(LOGGING_CONFIG)
```

## Performance Tuning

### Worker Configuration

Recommended worker count:

```bash
# Formula: (2 * CPU_CORES) + 1
workers = (2 * os.cpu_count()) + 1
```

### Caching

Add caching for profile listings:

```python
from functools import lru_cache

@lru_cache(maxsize=128)
def get_cached_profiles():
    manager = get_profile_manager()
    return manager.list_profiles()
```

### Connection Pooling

Configure connection limits:

```python
# In config.py
class APISettings(BaseSettings):
    max_concurrent_requests: int = 100
    request_timeout: int = 120
```

## Troubleshooting

### Common Issues

**Issue**: Upload fails for large files

**Solution**: Increase client_max_body_size in nginx and MAX_UPLOAD_SIZE in API config

**Issue**: Timeout on batch processing

**Solution**: Increase proxy timeouts in nginx and worker timeout in gunicorn

**Issue**: High memory usage

**Solution**: Reduce worker count or add memory limits to Docker container

### Logs

Check application logs:

```bash
# Docker
docker logs maps-api

# Direct deployment
tail -f maps_api.log
```

## Backup and Maintenance

### Profile Backups

```bash
# Backup profiles
tar -czf profiles_backup_$(date +%Y%m%d).tar.gz profiles/

# Restore profiles
tar -xzf profiles_backup_20251031.tar.gz
```

### Updates

```bash
# Pull latest code
git pull origin main

# Update dependencies
pip install -r requirements.txt --upgrade

# Restart service
docker-compose restart api
```
