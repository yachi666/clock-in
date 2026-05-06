#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Presence.xcodeproj"
SCHEME="Presence"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUNDLE_ID="com.lzn.clockin.presence"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DeviceDerivedData}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/Presence.app"

usage() {
  cat <<'EOF'
Usage:
  scripts/install-to-device.sh [device-id-or-name]

Examples:
  scripts/install-to-device.sh
  scripts/install-to-device.sh znphone
  scripts/install-to-device.sh 627AA3CD-D2F4-5551-BA41-E59A958C092B

Environment:
  CONFIGURATION=Debug|Release        Build configuration. Defaults to Debug.
  DERIVED_DATA_PATH=/path/to/build   DerivedData output path.
  SKIP_LAUNCH=1                      Install only; do not launch after install.
EOF
}

is_uuid() {
  [[ "$1" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]
}

first_connected_device_id() {
  xcrun devicectl list devices 2>/dev/null \
    | sed -nE '/ connected /s/.*([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}).*/\1/p' \
    | head -n 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

DEVICE="${1:-$(first_connected_device_id)}"
if [[ -z "$DEVICE" ]]; then
  echo "No connected iPhone found. Connect a device or pass a device id/name." >&2
  xcrun devicectl list devices || true
  exit 1
fi

if is_uuid "$DEVICE"; then
  XCODE_DESTINATION="id=$DEVICE"
else
  XCODE_DESTINATION="platform=iOS,name=$DEVICE"
fi

echo "==> Building $SCHEME ($CONFIGURATION) for device: $DEVICE"
xcodebuild build \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$XCODE_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded, but app bundle was not found at: $APP_PATH" >&2
  exit 1
fi

echo "==> Installing $APP_PATH"
xcrun devicectl device install app \
  --device "$DEVICE" \
  "$APP_PATH"

if [[ "${SKIP_LAUNCH:-0}" != "1" ]]; then
  echo "==> Launching $BUNDLE_ID"
  xcrun devicectl device process launch \
    --device "$DEVICE" \
    --terminate-existing \
    "$BUNDLE_ID"
fi

echo "==> Done"
