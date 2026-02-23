# ── Stage 1: Build Flutter web ────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy dependency manifests first (layer-cache friendly)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source and build
COPY . .
RUN flutter build web --release --no-tree-shake-icons

# ── Stage 2: Serve with Nginx ─────────────────────────────────
FROM nginx:1.27-alpine AS runner

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy Flutter web build output
COPY --from=builder /app/build/web /usr/share/nginx/html

# Custom Nginx config for SPA (single-page app) routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
