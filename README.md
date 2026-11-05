# proxmox-wol

English | [Español](README.es.md)

Wake-on-LAN to start VMs and LXC containers on an already running Proxmox VE host. The original working wol.sh and systemd unit are preserved.

## Online installation

The following commands require a PUBLIC repository. If it is still private, the unauthenticated download will fail. Run as root in the Proxmox host shell, not inside a guest. curl must already be installed to run these commands:

```bash
apt-get update && apt-get install -y curl ca-certificates
```

Install using vmbr0:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh)" -- install
```

Choose another existing bridge:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh)" -- install --interface vmbr1
```

Uninstall:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh)" -- uninstall
```

These commands execute remote code as root. Review the source first. To avoid starting Bash after a failed download, and to inspect the script before execution, use:

```bash
curl -fSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh -o /root/wol_install.sh
# Inspect the downloaded file before executing it:
less /root/wol_install.sh
# Only run after a successful download and review:
bash /root/wol_install.sh install --interface vmbr0
```

The installer downloads wol.sh and pve-wakeonlan.service from main, installs missing curl/tcpdump dependencies, validates the interface and Bash syntax, backs up existing files under /root/proxmox-wol-backup.*, and installs/enables/restarts the service. On deployment failure it attempts to restore previous files and active/enabled state; review the result manually. Package changes are not rolled back. Service activity is checked, but this does not prove WoL works end to end. The online installer itself has not been tested on your host.

Uninstall removes /root/scripts/wol.sh and /etc/systemd/system/pve-wakeonlan.service after disabling the service. It keeps backups, packages and the downloaded installer. It does not restore an older installation automatically.

## Files

- wol_install.sh: online install/uninstall entry point.
- wol.sh: original script listening for Ethernet WoL 0x0842 and UDP 7/9 on vmbr0.
- pve-wakeonlan.service: systemd service running /root/scripts/wol.sh as root.
- fix-wol-port.sh: legacy UDP 7 patch; not required for a fresh installation.

## Configuration and testing

List available interfaces with ip -br link. The installer changes the interface in the installed copy, not the repository original. Use the MAC configured in the target VM/LXC, not the host or auxiliary interface MAC. Replace 123 with the actual guest ID:

```bash
qm config 123
# For LXC:
pct config 123
systemctl status pve-wakeonlan --no-pager -l
journalctl -fu pve-wakeonlan
```

With the guest stopped, send a magic packet from the network to its configured MAC using UDP 7 or 9 and the appropriate broadcast address. Capture in another terminal (adapt vmbr0 if needed):

```bash
tcpdump -ni vmbr0 -e -vv -XX '(ether proto 0x0842) or (udp port 7) or (udp port 9)'
```

## How it works and limitations

The script extracts a MAC from tcpdump output, searches local VM configurations first and then LXC configurations, and starts the first match if it interprets its state as stopped. The physical host must be on. It does not implement cross-node startup.

There is a five-second sleep before each capture; repeat requests if necessary. The sed parser relies on a fixed output position and does not fully validate magic packets. Original unquoted expansions are preserved; an empty MAC is not safely handled. tcpdump errors are hidden. This is a working contributed script, not a hardened implementation. Use only on trusted networks; requests are not authenticated and the service runs as root. Do not expose it to the Internet.

If no packets appear, check the sender, interface and port. If a MAC appears but the log says 0 found, compare it with local guest configurations. The original problem was UDP 7 packets being ignored by a UDP-9-only filter.

## Manual recovery

Choose the actual backup directory. It contains previous files only if they existed before installation. Stop the service, restore those files, reload systemd and restore the desired state:

```bash
systemctl stop pve-wakeonlan
# Replace BACKUP_DIR below with the real directory:
cp -a BACKUP_DIR/wol.sh /root/scripts/wol.sh
cp -a BACKUP_DIR/pve-wakeonlan.service /etc/systemd/system/pve-wakeonlan.service
systemctl daemon-reload
systemctl restart pve-wakeonlan
```

Review state.txt in the backup for the previous active/enabled state.

Original method: https://forum.proxmox.com/threads/wake-on-lan-wol-for-vms-and-containers.143879/
