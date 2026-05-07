#!/usr/bin/env bash
# Bump MARKETING_VERSION, commit, tag vX.Y.Z, and push — CI builds + signs + notarizes + releases.
#
# Usage:
#   scripts/release.sh 1.1.0
#   scripts/release.sh 1.2.0-beta.1
#
# Requires: git, repo on a clean working tree, push access.
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>   e.g. 1.1.0 or 1.2.0-beta.1" >&2
    exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]]; then
    echo "Invalid version: $VERSION (expected MAJOR.MINOR.PATCH[-PRERELEASE])" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit or stash before releasing." >&2
    exit 1
fi

TAG="v${VERSION}"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists." >&2
    exit 1
fi

PBXPROJ="AiDevtools/AiDevtools.xcodeproj/project.pbxproj"
/usr/bin/sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${VERSION};/g" "$PBXPROJ"

echo "Bumped MARKETING_VERSION to $VERSION"
grep -E "MARKETING_VERSION" "$PBXPROJ" | head -2

git add "$PBXPROJ"
git commit -m "chore: release ${TAG}"
git tag -a "$TAG" -m "Release ${TAG}"

echo
echo "Local commit + tag created. Push with:"
echo "    git push origin main && git push origin $TAG"
echo
echo "CI will build, sign, notarize, and publish the release."
