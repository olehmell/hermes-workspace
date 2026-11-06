#!/usr/bin/env bash
# Snapshot all non-ignored vault changes, then fast-forward-push only inbox.
# Usage: git-inbox-sync.sh CHECKOUT STATE_DIRECTORY
set -euo pipefail
umask 077
if [[ $# != 2 ]]; then
  echo 'Usage: git-inbox-sync.sh CHECKOUT STATE_DIRECTORY' >&2
  exit 2
fi
command -v flock >/dev/null
repo=$(cd -- "$1" && pwd -P)
state=$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$2")
if [[ "$state" == "$repo" || "$state" == "$repo/"* ]]; then
  echo 'The sync state directory must be outside the checkout.' >&2
  exit 2
fi
export GIT_TERMINAL_PROMPT=0
mkdir -p -- "$state"
exec 9>"$state/sync.lock"
flock -n 9 || exit 0
log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }
on_exit() {
  local rc=$1
  if (( rc != 0 )); then
    log "FAILED (exit $rc); local work preserved"
    printf '%s exit=%s\n' "$(date -u +%FT%TZ)" "$rc" >"$state/last-error"
  fi
}
trap 'on_exit $?' EXIT
cd -- "$repo"
test "$(git rev-parse --show-toplevel)" = "$repo"
branch=$(git symbolic-ref --quiet --short HEAD)
if [[ "$branch" != inbox ]]; then
  log "Refusing sync: expected inbox, found $branch"
  exit 2
fi
for operation in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
  if [[ -e "$(git rev-parse --git-path "$operation")" ]]; then
    log "Refusing sync: Git operation in progress ($operation)"
    exit 2
  fi
done
if [[ -n "$(git ls-files -u)" ]]; then
  log 'Refusing sync: unmerged files'
  exit 2
fi
git add --all
if ! git diff --cached --quiet; then
  git commit -m "chore: sync Hermes inbox $(date -u +%FT%TZ)"
else
  log 'No new changes to commit'
fi
snapshot=$(git rev-parse refs/heads/inbox)
if [[ "$(git symbolic-ref --quiet --short HEAD)" != inbox ]]; then
  log 'Branch changed during sync; stopping before push'
  exit 2
fi
remote=$(git ls-remote --heads origin refs/heads/inbox)
if [[ -n "$remote" ]]; then
  git fetch --no-tags origin '+refs/heads/inbox:refs/remotes/origin/inbox'
  if ! git merge-base --is-ancestor refs/remotes/origin/inbox "$snapshot"; then
    log 'Remote inbox has commits missing locally; manual integration required'
    exit 3
  fi
fi
# A captured SHA prevents a concurrent branch switch from pushing another branch.
# No force push, checkout, reset, rebase, merge or stash in this scheduled job.
git push --porcelain --no-follow-tags --recurse-submodules=no origin "$snapshot:refs/heads/inbox"
printf '%s %s\n' "$(date -u +%FT%TZ)" "$snapshot" >"$state/last-success.tmp"
mv "$state/last-success.tmp" "$state/last-success"
rm -f "$state/last-error"
log "OK: inbox pushed at $snapshot"
