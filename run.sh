#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------------
# 19Cabs E2E Test Runner
# ------------------------------------------------------------------
# Pre-requisites:
#   - Android emulator running OR physical device connected via USB
#   - Backend running on localhost:3001
#   - Pricing service running on localhost:3002
#   - Customer app installed on device
#   - Maestro CLI installed (brew install maestro)
#   - .env file configured (copy from .env.example)
# ------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/e2e-results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Load env
if [ -f "$SCRIPT_DIR/.env" ]; then
  source "$SCRIPT_DIR/.env"
fi

DEVICE_SERIAL="${DEVICE_SERIAL:-}"
DEVICE_FLAG=""
if [ -n "$DEVICE_SERIAL" ]; then
  DEVICE_FLAG="--device $DEVICE_SERIAL"
fi

API_BASE_URL="${API_BASE_URL:-http://localhost:3001}"
DEV_SERVER_PORT="${DEV_SERVER_PORT:-8082}"

# Milton Keynes Central coordinates
MK_LAT="52.0349"
MK_LON="-0.7744"

echo "========================================"
echo "  19Cabs E2E Test Runner"
echo "  $(date)"
echo "========================================"

# ------------------------------------------------------------------
# 1. Health checks
# ------------------------------------------------------------------
echo ""
echo "[1/4] Health checks..."

# Check ADB device
if [ -n "$DEVICE_SERIAL" ]; then
  ADB_STATE=$(adb -s "$DEVICE_SERIAL" get-state 2>/dev/null || echo "offline")
else
  ADB_STATE=$(adb get-state 2>/dev/null || echo "offline")
fi

if [ "$ADB_STATE" != "device" ]; then
  echo "  FAIL: Android device not connected (state: $ADB_STATE)"
  exit 1
fi
echo "  OK: Android device connected"

# Check backend
if curl -sf "$API_BASE_URL/health" > /dev/null 2>&1; then
  echo "  OK: Backend running at $API_BASE_URL"
else
  echo "  WARN: Backend health check failed at $API_BASE_URL (continuing anyway)"
fi

# ------------------------------------------------------------------
# 2. Set mock location (emulator only)
# ------------------------------------------------------------------
echo ""
echo "[2/4] Setting location to Milton Keynes Central ($MK_LAT, $MK_LON)..."

# geo fix takes (longitude latitude) — note the order!
if [ -n "$DEVICE_SERIAL" ]; then
  adb -s "$DEVICE_SERIAL" emu geo fix "$MK_LON" "$MK_LAT" 2>/dev/null || echo "  WARN: geo fix failed (physical device? set location manually or use mock location app)"
else
  adb emu geo fix "$MK_LON" "$MK_LAT" 2>/dev/null || echo "  WARN: geo fix failed (physical device? set location manually or use mock location app)"
fi

# ------------------------------------------------------------------
# 3. Prepare app state
# ------------------------------------------------------------------
echo ""
echo "[3/5] Preparing app state..."

ADB_CMD="adb"
if [ -n "$DEVICE_SERIAL" ]; then
  ADB_CMD="adb -s $DEVICE_SERIAL"
fi

# Clear app data (fresh login)
$ADB_CMD shell pm clear com.nineteencabs.mobileapp > /dev/null 2>&1 || true
echo "  OK: Customer app data cleared"

# Grant location permissions so the app skips the location gate
$ADB_CMD shell pm grant com.nineteencabs.mobileapp android.permission.ACCESS_FINE_LOCATION 2>/dev/null || true
$ADB_CMD shell pm grant com.nineteencabs.mobileapp android.permission.ACCESS_COARSE_LOCATION 2>/dev/null || true
echo "  OK: Location permissions granted"

# Grant notification permission (Android 13+)
$ADB_CMD shell pm grant com.nineteencabs.mobileapp android.permission.POST_NOTIFICATIONS 2>/dev/null || true
echo "  OK: Notification permissions granted"

# Clear notifications
$ADB_CMD shell service call notification 1 > /dev/null 2>&1 || true
echo "  OK: Notifications cleared"

# ------------------------------------------------------------------
# 4. Launch app via deep link (bypasses Expo dev client launcher)
# ------------------------------------------------------------------
echo ""
echo "[4/5] Launching customer app via dev server deep link (port $DEV_SERVER_PORT)..."

# 10.0.2.2 is the emulator's alias for host localhost
ENCODED_URL="http%3A%2F%2F10.0.2.2%3A${DEV_SERVER_PORT}"
$ADB_CMD shell am start -a android.intent.action.VIEW \
  -d "exp+19cabs-customer://expo-development-client/?url=${ENCODED_URL}" \
  com.nineteencabs.mobileapp > /dev/null 2>&1 || true
echo "  OK: App launched with dev server deep link"

echo "  Waiting 15s for JS bundle to load..."
sleep 15

# ------------------------------------------------------------------
# 5. Run Maestro tests
# ------------------------------------------------------------------
echo ""
echo "[5/5] Running Maestro tests..."
echo "  Results will be saved to: $RESULTS_DIR"
echo ""

maestro $DEVICE_FLAG test \
  "$SCRIPT_DIR/maestro/flows/customer/customer_login.yaml" \
  --debug-output "$RESULTS_DIR" \
  2>&1 | tee "$RESULTS_DIR/maestro.log"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "========================================"
if [ $EXIT_CODE -eq 0 ]; then
  echo "  ALL TESTS PASSED"
else
  echo "  TESTS FAILED (exit code: $EXIT_CODE)"
  echo "  Check results at: $RESULTS_DIR"
fi
echo "  $(date)"
echo "========================================"

exit $EXIT_CODE
