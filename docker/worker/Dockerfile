########################################
# STAGE 1: REUSE WEB BUILD
########################################
# WHY: Workers need same code as web, so reuse the build stages
# BENEFIT: Docker shares layers = faster builds, less storage
FROM composer:2.6 AS composer-build

WORKDIR /app
COPY invoiceninja/composer.json invoiceninja/composer.lock ./
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --ignore-platform-reqs
COPY invoiceninja/ .
RUN composer dump-autoload --optimize --classmap-authoritative


########################################
# STAGE 2: WORKER RUNTIME
########################################
# KEY DIFFERENCE: No nginx/web server, just PHP CLI
FROM php:8.2-cli-alpine AS production

# Install runtime dependencies (same as web, minus nginx)
RUN apk add --no-cache \
    supervisor \
    postgresql-client \
    libpng \
    libzip \
    freetype \
    libjpeg-turbo \
    icu-libs \
    && rm -rf /var/cache/apk/*

# Install PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    postgresql-dev \
    libpng-dev \
    libzip-dev \
    freetype-dev \
    libjpeg-turbo-dev \
    icu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_pgsql \
    gd \
    zip \
    bcmath \
    intl \
    pcntl \
    && apk del .build-deps

# IMPORTANT: pcntl extension for signal handling
# WHY: Allows graceful shutdown when receiving SIGTERM
# LEARNING: Without this, workers ignore stop signals and get force-killed

# SECURITY: Non-root user
RUN addgroup -g 1000 invoiceninja \
    && adduser -D -u 1000 -G invoiceninja invoiceninja

WORKDIR /var/www/html

# Copy application code from build stage
COPY --from=composer-build --chown=invoiceninja:invoiceninja /app ./

# Set proper permissions
RUN chown -R invoiceninja:invoiceninja /var/www/html \
    && chmod -R 755 /var/www/html/storage

# Configure Supervisor for queue worker
COPY docker/worker/supervisord.conf /etc/supervisord.conf

# SECURITY: Run as non-root
USER invoiceninja

# HEALTH CHECK for workers (different from web)
# Checks if queue worker is processing jobs
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php artisan queue:health || exit 1

# Switch back to root for supervisor
USER root

# LEARNING POINT: Why supervisor for worker?
# - Automatically restarts if worker dies
# - Manages graceful shutdown (important for long-running jobs)
# - Logs to stdout/stderr (container best practice)

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

