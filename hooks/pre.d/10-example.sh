#!/usr/bin/env bash
# Example pre-backup hook. Hooks run in name order; a non-zero exit aborts the backup.
# Copy to /etc/backup-toolkit/hooks/pre.d/ and make it executable.
#
# Typical uses:
#   - dump a database:   pg_dumpall > /srv/dumps/postgres.sql
#   - pause a game save: see minecraft-server-ops/scripts/backup-hook-pre.sh
set -euo pipefail
echo "pre-backup hook: nothing to do"
