#!/usr/bin/env bash
# End-to-end test against a throwaway local restic repository. No root needed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap '[[ -n "${KEEP:-}" ]] || rm -rf "$WORK"' EXIT
BT="$ROOT/bin/backup-toolkit"

pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; exit 1; }

mkdir -p "$WORK"/{data/docs,data/cache,metrics,hooks/pre.d,hooks/post.d}
echo "s3cret-test-password" > "$WORK/password"
for i in $(seq 1 30); do head -c $((RANDOM % 4000 + 100)) /dev/urandom > "$WORK/data/docs/file-$i.bin"; done
echo "cache" > "$WORK/data/cache/skip.tmp"
printf '*.tmp\n' > "$WORK/excludes.txt"
printf '#!/bin/sh\ntouch %s/pre-ran\n' "$WORK" > "$WORK/hooks/pre.d/10-mark"
printf '#!/bin/sh\ntouch %s/post-ran\n' "$WORK" > "$WORK/hooks/post.d/10-mark"
chmod +x "$WORK"/hooks/*/*

cat > "$WORK/backup.env" <<CFG
RESTIC_REPOSITORY="$WORK/repo"
RESTIC_PASSWORD_FILE="$WORK/password"
BACKUP_PATHS="$WORK/data"
EXCLUDE_FILE="$WORK/excludes.txt"
BACKUP_TAG="ci"
HOOKS_DIR="$WORK/hooks"
METRICS_DIR="$WORK/metrics"
LOCK_FILE="$WORK/lock"
RESTORE_TEST_FILES=10
CFG
export BACKUP_TOOLKIT_CONFIG="$WORK/backup.env"

check()      { if "${@:2}" >/dev/null 2>&1; then pass "$1"; else fail "$1"; fi; }
check_fails(){ if "${@:2}" >/dev/null 2>&1; then fail "$1"; else pass "$1"; fi; }
metric()     { grep -q "$2" "$WORK/metrics/backup_toolkit_$1.prom"; }
in_latest()  { RESTIC_REPOSITORY="$WORK/repo" RESTIC_PASSWORD_FILE="$WORK/password" restic ls latest | grep -q "$1"; }
last_success(){ awk '/^backup_toolkit_backup_last_success/ {print $2}' "$WORK/metrics/backup_toolkit_backup.prom"; }

echo "backup-toolkit integration test"

check "init creates repository"               "$BT" init
check "init is idempotent"                    "$BT" init

check "first backup succeeds"                 "$BT" backup
check "pre and post hooks ran"                test -f "$WORK/pre-ran" -a -f "$WORK/post-ran"
check "metrics report exit code 0"            metric backup 'backup_toolkit_backup_last_exit_code{tag="ci"} 0'
check "metrics report 1 snapshot"             metric backup 'backup_toolkit_snapshots{tag="ci"} 1'
check_fails "excluded files are not in the snapshot" in_latest 'skip.tmp'

echo "changed" >> "$WORK/data/docs/file-1.bin"
check "second backup succeeds"                "$BT" backup
check "metrics report 2 snapshots"            metric backup 'backup_toolkit_snapshots{tag="ci"} 2'

check "restore test verifies random files"    "$BT" restore-test
check "restore-test metrics written"          metric restore_test 'backup_toolkit_restore_test_last_exit_code{tag="ci"} 0'

# A failing pre-hook must fail the run, keep the last success time and still run post-hooks.
success_before="$(last_success)"
rm -f "$WORK/post-ran"
printf '#!/bin/sh\nexit 3\n' > "$WORK/hooks/pre.d/20-fail"; chmod +x "$WORK/hooks/pre.d/20-fail"
check_fails "failing pre-hook fails the backup" "$BT" backup
check "post-hooks still ran after the failure" test -f "$WORK/post-ran"
check "metrics report the failure"            metric backup 'backup_toolkit_backup_last_exit_code{tag="ci"} 1'
check "last success time is preserved"        test "$success_before" = "$(last_success)"
rm -f "$WORK/hooks/pre.d/20-fail"

# A failing restic call (wrong password) must fail the run, not be swallowed.
echo "wrong" > "$WORK/password"
check_fails "restic errors fail the run"      "$BT" backup
echo "s3cret-test-password" > "$WORK/password"

# Concurrent runs are refused by the lock.
exec 8>"$WORK/lock"; flock -n 8
check_fails "concurrent run is refused"       "$BT" backup
exec 8>&-

echo "all tests passed"
