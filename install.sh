#!/usr/bin/env bash
# Installs safekeep on a systemd host. Safe to run again for upgrades.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }
cd "$(dirname "$0")"

for dep in restic jq curl flock shuf; do
  command -v "$dep" >/dev/null || { echo "missing dependency: $dep (apt install restic jq curl util-linux coreutils)" >&2; exit 1; }
done

install -m 0755 bin/safekeep /usr/local/bin/safekeep
install -d -m 0700 /etc/safekeep /etc/safekeep/hooks/pre.d /etc/safekeep/hooks/post.d
install -d -m 0755 /var/lib/node_exporter/textfile_collector

# Never overwrite existing config.
[[ -e /etc/safekeep/backup.env ]]   || install -m 0600 config/backup.env.example /etc/safekeep/backup.env
[[ -e /etc/safekeep/excludes.txt ]] || install -m 0644 config/excludes.txt /etc/safekeep/excludes.txt
if [[ ! -e /etc/safekeep/restic.password ]]; then
  umask 077
  head -c 48 /dev/urandom | base64 > /etc/safekeep/restic.password
  echo ">> generated /etc/safekeep/restic.password. Store a copy OFF this machine: without it backups are unreadable."
fi

install -m 0644 systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now safekeep.timer safekeep-restore-test.timer

echo ">> installed. Next: edit /etc/safekeep/backup.env, then run 'safekeep init' and 'safekeep backup'."
