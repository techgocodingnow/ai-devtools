#!/usr/bin/env bash
#
# gitnexus-reindex.sh — refresh the GitNexus knowledge graph after a commit.
#
# Called by the git post-commit / post-merge / post-checkout / post-rewrite
# hooks (see scripts/install-git-hooks.sh). GitNexus is commit-keyed, so the
# index only needs refreshing when HEAD moves — `analyze` is a no-op when the
# stored lastCommit already matches HEAD.
#
# Runs `gitnexus analyze` detached in the background so the commit returns
# instantly, guarded by a single-flight lock so rapid commits don't stack.

set -u

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$REPO" ] || exit 0
[ -d "$REPO/.gitnexus" ] || exit 0   # not indexed — nothing to do

LOCK="$REPO/.gitnexus/.reindex.lock"   # atomic mkdir lock (bash 3.2 has no flock)
LOG="$REPO/.gitnexus/reindex.log"      # .gitnexus/.gitignore is "*" — never committed

# Reclaim a stale lock left by a killed run (older than ~10 minutes).
if [ -d "$LOCK" ]; then
  if [ -z "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
    exit 0   # fresh lock → a reindex is already running
  fi
  rmdir "$LOCK" 2>/dev/null || true
fi

# Detached background subshell: commit returns immediately.
nohup bash -c '
  REPO="'"$REPO"'"
  LOCK="'"$LOCK"'"
  LOG="'"$LOG"'"
  mkdir "$LOCK" 2>/dev/null || exit 0          # single-flight: lost the race
  trap "rmdir \"$LOCK\" 2>/dev/null" EXIT
  cd "$REPO" || exit 0
  HEAD="$(git rev-parse --short HEAD 2>/dev/null)"
  printf "[%s] reindex start %s\n" "$(date "+%Y-%m-%dT%H:%M:%S")" "$HEAD" >>"$LOG"
  if npx gitnexus analyze >>"$LOG" 2>&1; then
    printf "[%s] reindex ok %s\n" "$(date "+%Y-%m-%dT%H:%M:%S")" "$HEAD" >>"$LOG"
  else
    printf "[%s] reindex FAILED %s\n" "$(date "+%Y-%m-%dT%H:%M:%S")" "$HEAD" >>"$LOG"
  fi
' >/dev/null 2>&1 &

exit 0
