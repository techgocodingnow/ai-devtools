#!/usr/bin/env bash
#
# install-git-hooks.sh — wire the GitNexus auto-reindex into git.
#
# .git/hooks/ is not tracked, so run this once per clone to (re)install the
# hooks. Idempotent: re-running overwrites the wrappers cleanly.
#
#   bash scripts/install-git-hooks.sh

set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO/.git/hooks"
HELPER="scripts/gitnexus-reindex.sh"   # repo-root-relative

[ -f "$REPO/$HELPER" ] || { echo "missing $HELPER" >&2; exit 1; }
chmod +x "$REPO/$HELPER"
mkdir -p "$HOOKS_DIR"

# post-checkout passes: $1 old-ref $2 new-ref $3 branch-flag (1 = branch switch).
# Only reindex on branch switches, not single-file checkouts.
write_hook() {
  local name="$1" guard="$2"
  cat >"$HOOKS_DIR/$name" <<EOF
#!/usr/bin/env bash
# Auto-installed by scripts/install-git-hooks.sh — refreshes GitNexus index.
$guard
exec "\$(git rev-parse --show-toplevel)/$HELPER"
EOF
  chmod +x "$HOOKS_DIR/$name"
  echo "installed .git/hooks/$name"
}

write_hook post-commit   ''
write_hook post-merge    ''
write_hook post-rewrite  ''
write_hook post-checkout '[ "${3:-0}" = "1" ] || exit 0'

echo "done."
