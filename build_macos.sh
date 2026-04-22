#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="gif_studio"
DIST_DIR="$ROOT_DIR/dist/macos"
APP_BUNDLE="$ROOT_DIR/build/macos/Build/Products/Release/${APP_NAME}.app"
ARCHIVE_PATH="$DIST_DIR/${APP_NAME}-macos.zip"
PROXY_URL="http://127.0.0.1:65000"

log() {
  printf '[build_macos] %s\n' "$1"
}

run_flutter() {
  if "$@"; then
    return 0
  fi

  log "Command failed, retrying with proxy: $PROXY_URL"
  HTTP_PROXY="$PROXY_URL" \
  HTTPS_PROXY="$PROXY_URL" \
  http_proxy="$PROXY_URL" \
  https_proxy="$PROXY_URL" \
  "$@"
}

if [[ "$OSTYPE" != darwin* ]]; then
  log "This script must be run on macOS"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  log "flutter not found in PATH"
  exit 1
fi

if ! command -v ditto >/dev/null 2>&1; then
  log "ditto not found"
  exit 1
fi

cd "$ROOT_DIR"

log "Running flutter pub get"
run_flutter flutter pub get

log "Building macOS release app"
run_flutter flutter build macos --release

if [[ ! -d "$APP_BUNDLE" ]]; then
  log "Expected app bundle not found: $APP_BUNDLE"
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE_PATH"

log "Packing app bundle to $ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

log "Done"
log "App bundle: $APP_BUNDLE"
log "Archive: $ARCHIVE_PATH"
