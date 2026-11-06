#!/usr/bin/env bash
# Usage: backup.sh COMPOSE_PROJECT_DIR RECIPIENT_FILE BACKUP_DIRECTORY
set -euo pipefail
umask 077
if [[ $# != 3 ]]; then
  echo 'Usage: backup.sh COMPOSE_PROJECT_DIR RECIPIENT_FILE BACKUP_DIRECTORY' >&2
  exit 2
fi
for tool in age docker flock python3 sha256sum tar; do
  command -v "$tool" >/dev/null
done
project=$(cd -- "$1" && pwd -P)
recipient=$(realpath -- "$2")
backup_dir=$(cd -- "$3" && pwd -P)
test -f "$project/compose.yml"
test -r "$recipient"
cd -- "$project"
compose=(docker compose --project-directory "$project" -f "$project/compose.yml")
data_dir=$("${compose[@]}" config --format json | python3 -c '
import json, sys
mounts = json.load(sys.stdin)["services"]["hermes"]["volumes"]
print(next(m["source"] for m in mounts if m["type"] == "bind" and m["target"] == "/opt/data"))
')
data_dir=$(cd -- "$data_dir" && pwd -P)
if [[ "$backup_dir" == "$data_dir" || "$backup_dir" == "$data_dir/"* ]]; then
  echo 'The backup directory must be outside the Hermes data directory.' >&2
  exit 2
fi

exec 9>"$data_dir/.hermes-backup.lock"
flock -n 9 || exit 0
running=$("${compose[@]}" ps --status running -q hermes)
temporary=$(mktemp -d "$backup_dir/.hermes-backup.XXXXXXXX")
output="$backup_dir/hermes-$(date -u +%Y%m%dT%H%M%SZ)-${temporary##*.}.tar.gz.age"
archive=${output##*/}
restart=false
cleanup() {
  local status=$?
  rm -f -- "$temporary/$archive" "$temporary/$archive.sha256" || status=1
  rmdir -- "$temporary" || status=1
  if "$restart" && ! "${compose[@]}" start hermes >/dev/null; then
    echo 'Could not restart Hermes after backup.' >&2
    status=1
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ -n "$running" ]]; then
  restart=true
  "${compose[@]}" stop hermes
fi
tar -C "$data_dir" --exclude=./.hermes-backup.lock -czf - . | age -R "$recipient" > "$temporary/$archive"
(cd -- "$temporary" && sha256sum "$archive" > "$archive.sha256")
mv -- "$temporary/$archive" "$output"
mv -- "$temporary/$archive.sha256" "$output.sha256"
printf 'Backup saved: %s\n' "$output"
