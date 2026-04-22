#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="gif_studio"
DIST_DIR="$ROOT_DIR/dist/linux"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
ARCHIVE_PATH="$DIST_DIR/${APP_NAME}-linux-x64.tar.gz"
PROXY_URL="http://127.0.0.1:65000"

log() {
  printf '[build_linux] %s\n' "$1"
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

if ! command -v flutter >/dev/null 2>&1; then
  log "flutter not found in PATH"
  exit 1
fi

cd "$ROOT_DIR"

log "Running flutter pub get"
run_flutter flutter pub get

log "Building Linux release bundle"
run_flutter flutter build linux --release

if [[ ! -d "$BUNDLE_DIR" ]]; then
  log "Expected bundle directory not found: $BUNDLE_DIR"
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -f "$ARCHIVE_PATH"

log "Packing bundle to $ARCHIVE_PATH"
tar -C "$BUNDLE_DIR" -czf "$ARCHIVE_PATH" .

log "Done"
log "Bundle directory: $BUNDLE_DIR"
log "Archive: $ARCHIVE_PATH"
