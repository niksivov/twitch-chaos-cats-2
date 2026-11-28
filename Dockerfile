# syntax=docker/dockerfile:1

# --- Сборка Web-клиента -------------------------------------------------------
FROM debian:bookworm-slim AS build

ARG GODOT_VERSION=4.7.1
ARG GODOT_RELEASE=4.7.1-stable

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip \
      libfontconfig1 libfreetype6 \
      libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxkbcommon0 \
      libgl1 libegl1 libasound2 libpulse0 libudev1 libdbus-1-3 \
 && rm -rf /var/lib/apt/lists/*

# Godot editor: им же запускается headless-сервер в runtime-образе.
RUN set -eux; \
    curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"; \
    unzip -q /tmp/godot.zip -d /opt/godot; \
    mv "/opt/godot/Godot_v${GODOT_RELEASE}_linux.x86_64" /usr/local/bin/godot; \
    chmod +x /usr/local/bin/godot; \
    rm -rf /tmp/godot.zip /opt/godot

# Шаблоны экспорта (архив со всеми платформами, ~1.28 ГБ).
# Слой кэшируется Render между сборками.
RUN set -eux; \
    curl -fsSL -o /tmp/templates.tpz \
      "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz"; \
    mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable"; \
    unzip -q /tmp/templates.tpz -d /tmp/templates; \
    if [ -d /tmp/templates/templates ]; then SRC=/tmp/templates/templates; else SRC=/tmp/templates; fi; \
    mv "$SRC"/* "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable/"; \
    rm -rf /tmp/templates /tmp/templates.tpz

WORKDIR /app
COPY . /app

# Импорт ресурсов, затем Web-экспорт. build/ исключён из контекста сборки.
RUN set -eux; \
    godot --headless --path /app --import; \
    mkdir -p /app/build/web; \
    godot --headless --path /app --export-release "Web" /app/build/web/index.html

# --- Runtime ------------------------------------------------------------------
FROM node:22-bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates bash \
      libfontconfig1 libfreetype6 \
      libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxkbcommon0 \
      libgl1 libegl1 libasound2 libpulse0 libudev1 libdbus-1-3 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /usr/local/bin/godot /usr/local/bin/godot
COPY --from=build /app /app
COPY docker/start.sh /app/start.sh

RUN chmod +x /app/start.sh

ENV GODOT_PORT=8080 \
    SESSION_IDLE_TIMEOUT=600

EXPOSE 10000

CMD ["/app/start.sh"]
