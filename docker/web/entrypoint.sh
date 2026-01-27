#!/bin/sh
# Entrypoint script for Invoice Ninja on Cloud Run
# Handles Laravel setup, Cloud SQL connection, and migrations

set -e

echo "🚀 Starting Invoice Ninja..."

# Wait for Cloud SQL proxy (Cloud Run handles this automatically)
# Connection will be available at /cloudsql/PROJECT:REGION:INSTANCE

# Configure DB_HOST for Cloud SQL Unix socket connection
if [ -n "$DB_CONNECTION_NAME" ]; then
    # Use Cloud SQL Unix socket (faster, more secure than TCP)
    export DB_HOST="/cloudsql/${DB_CONNECTION_NAME}"
    export DB_PORT=""  # Unix sockets don't use ports
    echo "✓ Cloud SQL connection configured: $DB_HOST"
else
    # Fallback to TCP connection (for local development)
    export DB_HOST="${DB_HOST:-127.0.0.1}"
    export DB_PORT="${DB_PORT:-5432}"
    echo "⚠ Using TCP connection: $DB_HOST:$DB_PORT"
fi

# Set Laravel storage permissions (Cloud Run uses ephemeral storage)
echo "Setting storage permissions..."
mkdir -p storage/framework/sessions
mkdir -p storage/framework/views
mkdir -p storage/framework/cache
mkdir -p storage/logs
mkdir -p bootstrap/cache

# Fix permissions (as root before switching to invoiceninja user)
chown -R invoiceninja:invoiceninja storage bootstrap/cache
chmod -R 755 storage bootstrap/cache

echo "✓ Storage configured"

# Generate application key if not set (should be in Secret Manager)
if [ -z "$APP_KEY" ]; then
    echo "⚠ WARNING: APP_KEY not set! Generating new key..."
    php artisan key:generate --force
else
    echo "✓ APP_KEY configured"
fi

# Cache configuration for better performance
echo "Caching Laravel configuration..."
php artisan config:cache
php artisan route:cache
php artisan view:cache
echo "✓ Configuration cached"

# Run database migrations (only on first deploy or when schema changes)
# Use a flag file to prevent running on every container restart
MIGRATION_FLAG="/tmp/.migrations_completed"
if [ "$RUN_MIGRATIONS" = "true" ] && [ ! -f "$MIGRATION_FLAG" ]; then
    echo "Running database migrations..."
    php artisan migrate --force
    touch "$MIGRATION_FLAG"
    echo "✓ Migrations completed"
elif [ -f "$MIGRATION_FLAG" ]; then
    echo "ℹ Skipping migrations (already completed)"
else
    echo "ℹ Skipping migrations (RUN_MIGRATIONS not set)"
fi

# Optimize for production
if [ "$APP_ENV" = "production" ]; then
    echo "Applying production optimizations..."
    php artisan optimize
    echo "✓ Optimizations applied"
fi

echo "✅ Invoice Ninja ready!"

# Start supervisor (nginx + php-fpm)
exec /usr/bin/supervisord -c /etc/supervisord.conf
