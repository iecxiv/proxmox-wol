# proxmox-wol

English | [Español](README.es.md)

Wake-on-LAN for starting virtual machines and LXC containers on a running Proxmox VE host. The included script and systemd unit reproduce the user's working installation without refactoring.

## How it works

The script listens on vmbr0 for Ethernet WoL (0x0842) or UDP ports 7 and 9. It extracts a MAC address and searches local VM configurations first, then LXC configurations. If several match, it uses the first. It runs qm start or pct start only when it interprets the status as stopped.

The host must already be running. This does not power on a physical server or require a script inside the guests. There is a five-second sleep before each capture; packets sent during that interval can be missed.

Original method: https://forum.proxmox.com/threads/wake-on-lan-wol-for-vms-and-containers.143879/

## Files

- wol.sh: complete script with UDP 7 and 9 enabled.
- pve-wakeonlan.service: systemd unit.
- fix-wol-port.sh: patch for an existing installation that only listens on UDP 9. Not needed when installing the included wol.sh.

## Installation

Run as root on the Proxmox host. This repository is private: cloning requires authenticated GitHub access. Alternatively, download the files through an authenticated session and copy them to the host.

```bash
apt update
apt install -y git tcpdump
git clone https://github.com/iecxiv/proxmox-wol.git
cd proxmox-wol
```

Review wol.sh and replace vmbr0 if necessary. List interfaces:

```bash
ip -br link
```

Back up any existing installation before overwriting:

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
[ ! -f /root/scripts/wol.sh ] || cp -a /root/scripts/wol.sh "/root/scripts/wol.sh.bak.$STAMP"
[ ! -f /etc/systemd/system/pve-wakeonlan.service ] || cp -a /etc/systemd/system/pve-wakeonlan.service "/etc/systemd/system/pve-wakeonlan.service.bak.$STAMP"
```

Install from the repository directory:

```bash
bash -n wol.sh && \
install -d -m 700 /root/scripts && \
install -m 700 wol.sh /root/scripts/wol.sh && \
install -m 644 pve-wakeonlan.service /etc/systemd/system/pve-wakeonlan.service && \
systemctl daemon-reload && \
systemctl enable pve-wakeonlan.service && \
systemctl restart pve-wakeonlan.service

systemctl status pve-wakeonlan.service --no-pager -l
```

## Testing

Use the MAC configured on the target VM or LXC interface, not the host MAC or an auxiliary bridge-interface MAC. Replace 123 with the actual guest ID:

```bash
qm config 123
# For an LXC container:
pct config 123
```

With the target guest stopped, send WoL from a device on the network using UDP 7 or 9 and the appropriate broadcast address. Repeat the request if it coincides with the five-second sleep. Watch the logs:

```bash
journalctl -fu pve-wakeonlan.service
```

In another terminal, capture packets while sending WoL:

```bash
tcpdump -ni vmbr0 -e -vv -XX '(ether proto 0x0842) or (udp port 7) or (udp port 9)'
```

## Troubleshooting and limitations

- In the tested installation, incoming WoL used UDP 7 while the original filter only accepted UDP 9. Adding UDP 7 fixed it.
- No captured packets: check the interface, port and sender configuration.
- A captured MAC followed by 0 found: check the target MAC against guest configurations on this node.
- Empty or incorrect MAC: inspect the sed parser. It relies on a fixed position in tcpdump hexadecimal output and does not fully validate the magic packet.
- Unquoted expansions from the original script are preserved, including the MAC passed to grep. An empty MAC is not safely handled. This is a working contributed version, not a hardened implementation.
- tcpdump errors are suppressed with 2>/dev/null.
- The script searches local configuration paths; it does not implement remote guest startup across cluster nodes.
- It runs as root and does not authenticate WoL requests. Use only on a trusted network and do not expose it to the Internet. The sleep is not complete abuse protection.

## Manual restore

Replace the example backup names with your actual backup files:

```bash
systemctl stop pve-wakeonlan.service
cp -a /root/scripts/wol.sh.bak.YYYYMMDD-HHMMSS /root/scripts/wol.sh
cp -a /etc/systemd/system/pve-wakeonlan.service.bak.YYYYMMDD-HHMMSS /etc/systemd/system/pve-wakeonlan.service
systemctl daemon-reload
systemctl restart pve-wakeonlan.service
```

## Uninstall

These commands remove the installed service and script, but keep backups and the repository:

```bash
systemctl disable --now pve-wakeonlan.service
rm -f /etc/systemd/system/pve-wakeonlan.service
rm -f /root/scripts/wol.sh
systemctl daemon-reload
```
