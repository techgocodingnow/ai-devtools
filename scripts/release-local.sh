#!/usr/bin/env bash
# Local dry-run of the release pipeline — mirrors .github/workflows/release.yml
# so you can catch signing / notarization / DMG issues BEFORE pushing a tag.
#
# Usage:
#   scripts/release-local.sh                    # build + sign + verify + dmg (no notarize)
#   scripts/release-local.sh --notarize         # full pipeline incl. Apple notary submit
#   scripts/release-local.sh --notarize --staple
#
# Requires:
#   - Xcode + command-line tools
#   - Developer ID Application cert in your login keychain
#   - Homebrew + create-dmg + jq        (brew install create-dmg jq)
#   - For --notarize: keychain profile created via:
#       xcrun notarytool store-credentials AI_DEVTOOLS_NOTARY \
#         --apple-id "<apple-id>" --team-id "L23PD654Q3" --password "<app-specific-pw>"
#     Override profile name with NOTARY_PROFILE env var.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

NOTARIZE=0
STAPLE=0
for arg in "$@"; do
    case "$arg" in
        --notarize) NOTARIZE=1 ;;
        --staple)   STAPLE=1; NOTARIZE=1 ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *) echo "Unknown arg: $arg" >&2; exit 1 ;;
    esac
done

SCHEME="AiDevtools"
PROJECT="AiDevtools/AiDevtools.xcodeproj"
CONFIGURATION="Release"
APP_NAME="AiDevtools"
DMG_NAME="AiDevtools.dmg"
TEAM_ID="L23PD654Q3"
NOTARY_PROFILE="${NOTARY_PROFILE:-AI_DEVTOOLS_NOTARY}"

BUILD_DIR="build/local"
ARCHIVE_PATH="${BUILD_DIR}/AiDevtools.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_DIR="${BUILD_DIR}/dmg"
EXPORT_OPTIONS="build-config/ExportOptions.plist"

echo "==> Cleaning $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DMG_DIR"

echo "==> Pre-flight checks"
command -v xcodebuild >/dev/null || { echo "xcodebuild missing"; exit 1; }
command -v create-dmg >/dev/null || { echo "create-dmg missing — brew install create-dmg"; exit 1; }
command -v jq         >/dev/null || { echo "jq missing — brew install jq"; exit 1; }

echo "==> Verify Developer ID cert present"
security find-identity -v -p codesigning | grep -q "Developer ID Application.*${TEAM_ID}" \
    || { echo "ERROR: 'Developer ID Application' cert for team ${TEAM_ID} not found in keychain"; exit 1; }

echo "==> Archive (hardened runtime + secure timestamp)"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
    archive | xcbeautify 2>/dev/null || \
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
    archive

test -d "$ARCHIVE_PATH" || { echo "Archive missing"; exit 1; }

echo "==> Export Developer ID build"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS"

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
test -d "$APP_PATH" || { echo "Exported .app missing"; exit 1; }

echo "==> Verify signing"
echo "--- codesign -dv ---"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | tee "${BUILD_DIR}/codesign-dv.txt"

echo "--- hardened runtime / timestamp checks ---"
grep -E "flags=.*runtime" "${BUILD_DIR}/codesign-dv.txt" \
    || { echo "ERROR: hardened runtime not enabled — notarization will fail"; exit 1; }
grep -E "Timestamp=" "${BUILD_DIR}/codesign-dv.txt" \
    || { echo "ERROR: secure timestamp missing — notarization will fail"; exit 1; }

echo "--- entitlements ---"
codesign -d --entitlements :- "$APP_PATH" || true

echo "--- deep verify ---"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "--- gatekeeper assess (informational; pre-notarize will fail) ---"
spctl -a -t exec -vv "$APP_PATH" || true

echo "==> Create DMG"
create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 640 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 180 180 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 460 180 \
    --no-internet-enable \
    "${DMG_DIR}/${DMG_NAME}" \
    "$APP_PATH"

ls -lh "${DMG_DIR}/${DMG_NAME}"

if [[ "$NOTARIZE" -eq 0 ]]; then
    echo
    echo "==> Done (no notarize). DMG: ${DMG_DIR}/${DMG_NAME}"
    echo "    Re-run with --notarize to test the Apple notary path."
    exit 0
fi

echo "==> Notarize via profile '${NOTARY_PROFILE}'"
SUBMIT_OUTPUT=$(xcrun notarytool submit "${DMG_DIR}/${DMG_NAME}" \
    --keychain-profile "$NOTARY_PROFILE" \
    --output-format json \
    --wait)
echo "$SUBMIT_OUTPUT" | jq .

SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | jq -r '.id')
STATUS=$(echo "$SUBMIT_OUTPUT" | jq -r '.status')

if [[ "$STATUS" != "Accepted" ]]; then
    echo "==> Notarization FAILED ($STATUS) — fetching log"
    xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE"
    exit 1
fi

if [[ "$STAPLE" -eq 1 ]]; then
    echo "==> Stapling"
    xcrun stapler staple "${DMG_DIR}/${DMG_NAME}"
    xcrun stapler validate "${DMG_DIR}/${DMG_NAME}"
    echo "==> Final gatekeeper assess"
    spctl -a -t open --context context:primary-signature -vv "${DMG_DIR}/${DMG_NAME}"
fi

echo
echo "==> Done. DMG: ${DMG_DIR}/${DMG_NAME}"
