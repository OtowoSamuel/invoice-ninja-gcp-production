```
┌─────────────────────────────────────────────────────────────────────┐
│                    DOCKER MULTI-STAGE BUILD FLOW                     │
└─────────────────────────────────────────────────────────────────────┘

                         WEB CONTAINER BUILD
┌─────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ STAGE 1: COMPOSER BUILD (500MB)                              │   │
│  │                                                               │   │
│  │  FROM composer:2.6                                           │   │
│  │  ├─ COPY composer.json composer.lock                        │   │
│  │  ├─ RUN composer install (downloads PHP deps)               │   │
│  │  ├─ COPY application code                                   │   │
│  │  └─ RUN composer dump-autoload                              │   │
│  │                                                               │   │
│  │  OUTPUT: /app/vendor/ (compiled PHP dependencies)           │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              ↓                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ STAGE 2: NODE BUILD (400MB)                                 │   │
│  │                                                               │   │
│  │  FROM node:18-alpine                                         │   │
│  │  ├─ COPY package*.json                                      │   │
│  │  ├─ RUN npm ci (downloads JS deps)                          │   │
│  │  ├─ COPY application code                                   │   │
│  │  └─ RUN npm run production (compile CSS/JS)                 │   │
│  │                                                               │   │
│  │  OUTPUT: /app/public/ (compiled assets)                     │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              ↓                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ STAGE 3: PRODUCTION (150MB) ← THIS GOES TO PRODUCTION!     │   │
│  │                                                               │   │
│  │  FROM php:8.2-fpm-alpine                                     │   │
│  │  ├─ Install runtime deps (nginx, postgres-client)          │   │
│  │  ├─ Create non-root user (invoiceninja)                    │   │
│  │  ├─ COPY --from=composer-build /app/vendor ./vendor        │   │
│  │  ├─ COPY --from=node-build /app/public ./public            │   │
│  │  ├─ COPY application code                                   │   │
│  │  ├─ Configure nginx + php-fpm + supervisor                 │   │
│  │  ├─ USER invoiceninja (switch to non-root)                 │   │
│  │  └─ CMD [supervisord]                                       │   │
│  │                                                               │   │
│  │  ✅ No build tools (compiler, npm, etc.)                   │   │
│  │  ✅ Only runtime deps + compiled code                       │   │
│  │  ✅ Non-root user for security                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘

                         WORKER CONTAINER BUILD
┌─────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ STAGE 1: COMPOSER BUILD (reused from web)                   │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                              ↓                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ STAGE 2: PRODUCTION (140MB)                                 │   │
│  │                                                               │   │
│  │  FROM php:8.2-cli-alpine (NO web server!)                   │   │
│  │  ├─ Install runtime deps (postgres-client, pcntl)          │   │
│  │  ├─ Create non-root user                                    │   │
│  │  ├─ COPY --from=composer-build /app/vendor ./vendor        │   │
│  │  ├─ COPY application code                                   │   │
│  │  ├─ Configure supervisor for queue worker                  │   │
│  │  ├─ USER invoiceninja                                       │   │
│  │  └─ CMD [supervisord]                                       │   │
│  │                                                               │   │
│  │  KEY DIFFERENCE: php:cli (not fpm), no nginx               │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘

                       DOCKER COMPOSE ORCHESTRATION
┌─────────────────────────────────────────────────────────────────────┐
│                                                                       │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐                   │
│   │ DATABASE │     │  REDIS   │     │ MAILHOG  │                   │
│   │ Postgres │     │  Cache   │     │  SMTP    │                   │
│   │  :5432   │     │  :6379   │     │  :1025   │                   │
│   └────┬─────┘     └────┬─────┘     └────┬─────┘                   │
│        │                │                │                           │
│        │  ┌─────────────┴────────────────┘                          │
│        │  │                                                          │
│        │  │     ┌──────────────────┐                                │
│        └──┼────→│   WEB CONTAINER  │                                │
│           │     │                  │                                │
│           │     │  Nginx + PHP-FPM │                                │
│           │     │  Port: 8000      │←─── HTTP Requests              │
│           │     │                  │                                │
│           │     │  Health: /health │                                │
│           │     └──────────────────┘                                │
│           │                                                          │
│           │     ┌──────────────────┐                                │
│           └────→│ WORKER CONTAINER │                                │
│                 │                  │                                │
│                 │  Queue Worker    │                                │
│                 │  No HTTP Port    │←─── Queue Jobs from Redis      │
│                 │                  │                                │
│                 │  Health: queue   │                                │
│                 └──────────────────┘                                │
│                                                                       │
│  NETWORK: invoiceninja (bridge)                                     │
│  VOLUMES: db-data (persistent), redis-data (persistent)             │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘

                         LAYER CACHING EXAMPLE
┌─────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  BUILD #1 (First Build)                  BUILD #2 (Code Change)     │
│  ───────────────────────                 ──────────────────────     │
│                                                                       │
│  ┌─────────────────────┐                 ┌─────────────────────┐   │
│  │ FROM php:8.2-alpine │                 │ FROM php:8.2-alpine │   │
│  │ ⏱️  Pulled from hub │                 │ ✅ CACHED (instant) │   │
│  └─────────────────────┘                 └─────────────────────┘   │
│           ↓                                        ↓                 │
│  ┌─────────────────────┐                 ┌─────────────────────┐   │
│  │ RUN apk add nginx   │                 │ RUN apk add nginx   │   │
│  │ ⏱️  30 seconds      │                 │ ✅ CACHED (instant) │   │
│  └─────────────────────┘                 └─────────────────────┘   │
│           ↓                                        ↓                 │
│  ┌─────────────────────┐                 ┌─────────────────────┐   │
│  │ COPY composer.json  │                 │ COPY composer.json  │   │
│  │ ✅ First copy       │                 │ ✅ CACHED (same)    │   │
│  └─────────────────────┘                 └─────────────────────┘   │
│           ↓                                        ↓                 │
│  ┌─────────────────────┐                 ┌─────────────────────┐   │
│  │ RUN composer install│                 │ RUN composer install│   │
│  │ ⏱️  2 minutes       │                 │ ✅ CACHED (instant) │   │
│  └─────────────────────┘                 └─────────────────────┘   │
│           ↓                                        ↓                 │
│  ┌─────────────────────┐                 ┌─────────────────────┐   │
│  │ COPY app code       │                 │ COPY app code       │   │
│  │ ✅ First copy       │                 │ ❌ CHANGED! Rebuild │   │
│  └─────────────────────┘                 └─────────────────────┘   │
│           ↓                                        ↓                 │
│  ┌─────────────────────┐                 ┌─────────────────────┐   │
│  │ Final config        │                 │ Final config        │   │
│  │ ⏱️  10 seconds      │                 │ ⏱️  10 seconds      │   │
│  └─────────────────────┘                 └─────────────────────┘   │
│                                                                       │
│  TOTAL TIME: 3+ minutes                  TOTAL TIME: 15 seconds     │
│                                          (12x faster!)                │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘

                        SECURITY MODEL
┌─────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  ❌ BAD: Running as Root                                            │
│  ─────────────────────────                                          │
│                                                                       │
│    Container                    Host System                          │
│    ┌────────────┐               ┌────────────┐                      │
│    │ Process    │               │ If escaped │                      │
│    │ (root:0)   │──escaped?───→ │ = root!    │                      │
│    │            │               │ Full access│                      │
│    └────────────┘               └────────────┘                      │
│    Can: Everything              Can: Install malware                │
│                                 Can: Access all containers           │
│                                                                       │
│  ✅ GOOD: Non-Root User                                             │
│  ─────────────────────────                                          │
│                                                                       │
│    Container                    Host System                          │
│    ┌────────────┐               ┌────────────┐                      │
│    │ Process    │               │ If escaped │                      │
│    │ (1000:1000)│──escaped?───→ │ = user 1000│                      │
│    │            │               │ Limited!   │                      │
│    └────────────┘               └────────────┘                      │
│    Can: Read own files          Cannot: Install software            │
│    Cannot: Install packages     Cannot: Access root files           │
│    Cannot: Bind port <1024      Cannot: Modify system               │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘

                    GRACEFUL SHUTDOWN FLOW
┌─────────────────────────────────────────────────────────────────────┐
│                                                                       │
│  $ docker stop worker-container                                      │
│  │                                                                    │
│  ├─→ Docker sends SIGTERM to supervisor                             │
│  │                                                                    │
│  ├─→ Supervisor sends SIGTERM to worker process                     │
│  │                                                                    │
│  ├─→ Worker process:                                                │
│  │   ┌──────────────────────────────────────────────┐              │
│  │   │ 1. Stops accepting new jobs                  │              │
│  │   │ 2. Finishes current job (email sending...)  │              │
│  │   │ 3. Cleans up connections                     │              │
│  │   │ 4. Exits with status 0                       │              │
│  │   └──────────────────────────────────────────────┘              │
│  │                                                                    │
│  ├─→ Supervisor waits (up to stopwaitsecs=60)                       │
│  │                                                                    │
│  ├─→ ✅ Worker exits cleanly: Container stops                       │
│  │                                                                    │
│  └─→ ❌ Timeout (60s): Supervisor sends SIGKILL (force kill)        │
│                                                                       │
│  WHY: Prevents data loss, maintains data integrity                  │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```
