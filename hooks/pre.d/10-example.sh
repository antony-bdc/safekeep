#!/usr/bin/env bash
# Example pre-backup hook. Hooks run in name order; a non-zero exit aborts the backup.
# Copy to /etc/safekeep/hooks/pre.d/ and make it executable.
#
# Typical uses:
#   - dump a database:   pg_dumpall > /srv/dumps/postgres.sql
#   - pause a game save: see dwellers-galaxy/scripts/backup-hook-pre.sh
set -euo pipefail
echo "pre-backup hook: nothing to do"
