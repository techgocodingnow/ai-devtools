#!/usr/bin/env bash
# Import Developer ID Application cert from .env into login keychain.
# Reads BUILD_CERTIFICATE_BASE64 + P12_PASSWORD.
#
# Usage: scripts/import-cert.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE=".env"
[[ -f "$ENV_FILE" ]] || { echo "$ENV_FILE missing"; exit 1; }

set -a
# shellcheck disable=SC1091
source "$ENV_FILE"
set +a

[[ -n "${BUILD_CERTIFICATE_BASE64:-}" ]] || { echo "BUILD_CERTIFICATE_BASE64 not set in .env"; exit 1; }
[[ -n "${P12_PASSWORD:-}" ]] || { echo "P12_PASSWORD not set in .env"; exit 1; }

TMP_P12="$(mktemp -t aidevtools-cert).p12"
trap 'rm -f "$TMP_P12"' EXIT

echo "==> Decoding cert"
echo -n "$BUILD_CERTIFICATE_BASE64" | base64 --decode -o "$TMP_P12"

KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

echo "==> Importing into login keychain"
security import "$TMP_P12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN"

echo "==> Allowing codesign to use key without prompt"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || \
  echo "  (note: may prompt for keychain password — enter your Mac login password)"

echo "==> Verify"
security find-identity -v -p codesigning | grep "Developer ID Application" \
  || { echo "ERROR: cert not found after import"; exit 1; }

echo "Done. Re-run scripts/release-local.sh --notarize --staple"
