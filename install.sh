#!/usr/bin/env bash
# Installs backup-toolkit on a systemd host. Safe to run again for upgrades.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }
cd "$(dirname "$0")"

for dep in restic jq curl flock shuf; do
  command -v "$dep" >/dev/null || { echo "missing dependency: $dep (apt install restic jq curl util-linux coreutils)" >&2; exit 1; }
done

install -m 0755 bin/backup-toolkit /usr/local/bin/backup-toolkit
install -d -m 0700 /etc/backup-toolkit /etc/backup-toolkit/hooks/pre.d /etc/backup-toolkit/hooks/post.d
install -d -m 0755 /var/lib/node_exporter/textfile_collector

# Never overwrite existing config.
[[ -e /etc/backup-toolkit/backup.env ]]   || install -m 0600 config/backup.env.example /etc/backup-toolkit/backup.env
[[ -e /etc/backup-toolkit/excludes.txt ]] || install -m 0644 config/excludes.txt /etc/backup-toolkit/excludes.txt
if [[ ! -e /etc/backup-toolkit/restic.password ]]; then
  umask 077
  head -c 48 /dev/urandom | base64 > /etc/backup-toolkit/restic.password
  echo ">> generated /etc/backup-toolkit/restic.password. Store a copy OFF this machine: without it backups are unreadable."
fi

install -m 0644 systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now backup-toolkit.timer backup-toolkit-restore-test.timer

echo ">> installed. Next: edit /etc/backup-toolkit/backup.env, then run 'backup-toolkit init' and 'backup-toolkit backup'."
