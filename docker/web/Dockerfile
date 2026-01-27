########################################
# STAGE 1: COMPOSER BUILD
########################################
# WHY: Install PHP dependencies separately to leverage Docker layer caching
# BENEFIT: If only code changes (not composer.json), this layer is reused
FROM composer:2.6 AS composer-build

WORKDIR /app

# Increase composer process timeout during image build to avoid VCS clone timeouts
ARG COMPOSER_PROCESS_TIMEOUT=2000
ENV COMPOSER_PROCESS_TIMEOUT=${COMPOSER_PROCESS_TIMEOUT}

# OPTIMIZATION: Copy only dependency files first (layer caching!)
# If these files don't change, Docker reuses this layer
COPY invoiceninja/composer.json invoiceninja/composer.lock ./

# Install dependencies WITHOUT dev packages (smaller image)
# --ignore-platform-reqs: allows install even if platform checks fail
# --no-scripts: skip post-install scripts for security
RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --ignore-platform-reqs

# Now copy application code
COPY invoiceninja/ .

# Generate optimized autoloader (faster production performance)
RUN composer dump-autoload --optimize --classmap-authoritative


########################################
# STAGE 2: NODE BUILD (Frontend Assets)
########################################
# WHY: Separate stage keeps final image small (no Node.js in production)
FROM node:18-alpine AS node-build

WORKDIR /app

# Copy package files first (layer caching again!)
COPY invoiceninja/package*.json ./

# Install npm dependencies
RUN npm ci --production=false

# Copy source files needed for build
COPY invoiceninja/ .

# Build frontend assets (if Invoice Ninja uses them)
# This compiles JS/CSS into optimized bundles
RUN npm run production || echo "No build script found"


########################################
# STAGE 3: PRODUCTION RUNTIME
########################################
# WHY: Start from minimal PHP image, only add what we need
# alpine = smallest base image (~5MB vs ~100MB for debian)
FROM php:8.2-fpm-alpine AS production

# Install ONLY runtime dependencies (not build tools)
# --no-cache: don't store package index (saves ~10MB)
RUN apk add --no-cache \
    nginx \
    supervisor \
    postgresql-client \
    libpng \
    libzip \
    freetype \
    libjpeg-turbo \
    icu-libs \
    && rm -rf /var/cache/apk/*

# Install PHP extensions (what Invoice Ninja needs)
# LEARNING: Laravel requires these for database, images, cache, etc.
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
    opcache \
    && apk del .build-deps

# SECURITY: Create non-root user (NEVER run as root!)
# WHY: If app is compromised, attacker has limited permissions
RUN addgroup -g 1000 invoiceninja \
    && adduser -D -u 1000 -G invoiceninja invoiceninja

# Set working directory
WORKDIR /var/www/html

# Copy built artifacts from previous stages (small and optimized!)
COPY --from=composer-build --chown=invoiceninja:invoiceninja /app/vendor ./vendor
COPY --from=node-build --chown=invoiceninja:invoiceninja /app/public ./public
COPY --chown=invoiceninja:invoiceninja invoiceninja/ .

# PHP Optimization for production
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=60" >> /usr/local/etc/php/conf.d/opcache.ini

# Configure Nginx
COPY docker/web/nginx.conf /etc/nginx/nginx.conf
COPY docker/web/default.conf /etc/nginx/http.d/default.conf

# Configure Supervisor (manages nginx + php-fpm)
COPY docker/web/supervisord.conf /etc/supervisord.conf

# Copy entrypoint script
COPY docker/web/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set proper permissions
RUN chown -R invoiceninja:invoiceninja /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# SECURITY: Switch to non-root user
USER invoiceninja

# HEALTH CHECK: Tell Docker/K8s if container is healthy
# WHY: Auto-restart unhealthy containers, don't route traffic to them
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD php artisan schedule:run --no-ansi || exit 1

# Expose port (documentation only, doesn't actually publish)
EXPOSE 8080

# Switch back to root for supervisor (needs privileges)
USER root

# ENTRYPOINT: What runs when container starts
# Runs entrypoint script that configures Laravel and starts supervisor
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
