#!/usr/bin/env bash
set -Eeuo pipefail
ACTION=${1:-install}
[[ $# -eq 0 ]] || shift
IFACE=vmbr0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interface) [[ $# -ge 2 ]] || { echo 'Missing interface' >&2; exit 1; }; IFACE=$2; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo 'Run as root on the Proxmox host.' >&2; exit 1; }
[[ $ACTION == install || $ACTION == uninstall ]] || { echo 'Usage: wol_install.sh install [--interface vmbr0] | uninstall' >&2; exit 1; }
SERVICE=pve-wakeonlan.service
SCRIPT=/root/scripts/wol.sh
UNIT=/etc/systemd/system/$SERVICE
if [[ $ACTION == uninstall ]]; then
  systemctl disable --now "$SERVICE"
  rm -f "$UNIT" "$SCRIPT"
  systemctl daemon-reload
  echo 'Uninstalled. Backups, dependencies and repository files were kept.'
  exit 0
fi
command -v pveversion >/dev/null || { echo 'Proxmox VE host required.' >&2; exit 1; }
[[ $IFACE =~ ^[a-zA-Z0-9_.:-]+$ ]] || { echo 'Invalid interface name.' >&2; exit 1; }
ip link show dev "$IFACE" >/dev/null
if ! command -v curl >/dev/null || ! command -v tcpdump >/dev/null; then
  apt-get update
  apt-get install -y curl ca-certificates tcpdump
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
BASE=https://raw.githubusercontent.com/iecxiv/proxmox-wol/main
curl --fail --silent --show-error --location --retry 3 "$BASE/wol.sh" -o "$TMP/wol.sh"
curl --fail --silent --show-error --location --retry 3 "$BASE/pve-wakeonlan.service" -o "$TMP/$SERVICE"
sed -i "s/-UlnXi vmbr0 /-UlnXi $IFACE /" "$TMP/wol.sh"
bash -n "$TMP/wol.sh"
grep -Fq "-UlnXi $IFACE " -- /dev/null 2>/dev/null && exit 1
# Validate the expected capture command and service before replacing files.
grep -Fq -- "-UlnXi $IFACE " "$TMP/wol.sh"
grep -Fxq 'ExecStart=/root/scripts/wol.sh' "$TMP/$SERVICE"
BACKUP=$(mktemp -d /root/proxmox-wol-backup.XXXXXXXX)
HAD_SCRIPT=0; HAD_UNIT=0; WAS_ACTIVE=0; WAS_ENABLED=0
if [[ -e $SCRIPT ]]; then cp -a "$SCRIPT" "$BACKUP/wol.sh"; HAD_SCRIPT=1; fi
if [[ -e $UNIT ]]; then cp -a "$UNIT" "$BACKUP/$SERVICE"; HAD_UNIT=1; fi
systemctl is-active --quiet "$SERVICE" && WAS_ACTIVE=1
systemctl is-enabled --quiet "$SERVICE" 2>/dev/null && WAS_ENABLED=1
printf 'interface=%s\nactive=%s\nenabled=%s\n' "$IFACE" "$WAS_ACTIVE" "$WAS_ENABLED" > "$BACKUP/state.txt"
rollback() {
  trap - ERR
  set +e
  echo "Installation failed; restoring files from $BACKUP" >&2
  systemctl disable --now "$SERVICE"
  if [[ $HAD_SCRIPT == 1 ]]; then cp -a "$BACKUP/wol.sh" "$SCRIPT"; else rm -f "$SCRIPT"; fi
  if [[ $HAD_UNIT == 1 ]]; then cp -a "$BACKUP/$SERVICE" "$UNIT"; else rm -f "$UNIT"; fi
  systemctl daemon-reload
  [[ $WAS_ENABLED == 0 ]] || systemctl enable "$SERVICE"
  [[ $WAS_ACTIVE == 0 ]] || systemctl start "$SERVICE"
  echo 'Review the restored service state manually. Installed packages were not removed.' >&2
  exit 1
}
trap rollback ERR
systemctl stop "$SERVICE" 2>/dev/null || true
mkdir -p /root/scripts
install -m 700 "$TMP/wol.sh" "$SCRIPT"
install -m 644 "$TMP/$SERVICE" "$UNIT"
systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl restart "$SERVICE"
sleep 6
systemctl is-active --quiet "$SERVICE"
trap - ERR
echo "Installed on $IFACE. Backup: $BACKUP"
echo 'Service activity is not an end-to-end WoL test. Send a magic packet to verify.'
systemctl status "$SERVICE" --no-pager -l
