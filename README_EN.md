# Linux Diagnostic Toolkit

A menu-driven, mostly distribution-independent Bash tool for **read-only** Linux diagnostics. Inspired by the Windows Diagnostic Toolkit. **45 diagnostic checks**, single or full run, TXT/HTML reports, and basic statuses (GREEN/YELLOW/RED/N/A).

## Supported systems

Primarily Debian 12/13, Ubuntu and Proxmox VE (host and LXC/VM); other systemd-based Linux distributions with common utilities available. Some functions need optional packages or elevated privileges.

## Installation and usage

```bash
chmod +x linux-diagnostic-toolkit.sh
./linux-diagnostic-toolkit.sh                      # interactive menu (DE)
./linux-diagnostic-toolkit.sh --lang en            # English menu
./linux-diagnostic-toolkit.sh --all                # all 45 checks
./linux-diagnostic-toolkit.sh --check 19           # failed services
./linux-diagnostic-toolkit.sh --all --html         # only HTML report
./linux-diagnostic-toolkit.sh --all --txt          # only text report
./linux-diagnostic-toolkit.sh --all --output-dir /tmp/diagnostics
sudo ./linux-diagnostic-toolkit.sh --all           # optional, more detailed output
```

## Status rating and privacy

The status rating is **heuristic, not a security certification**. GREEN only means most commands completed successfully; YELLOW indicates errors/permissions/timeouts; RED indicates selected strong signals (e.g. filesystems >=95%, specific kernel messages). N/A means no command completed successfully. The toolkit does not alter packages, firewall rules, services or configurations. Reports may contain user names, IP addresses, logs and other confidential data: **review and sanitize them before publishing**. Some commands might not work in containers. Live connectivity checks (ping and DNS) are included, so a run is not entirely offline.

## Checks and underlying commands

Commands are executed separately per check; a missing optional program does not stop the other checks.

| # | Menu item | Linux commands |
|---:|---|---|
| 1 | System identity | `hostnamectl; hostname; uname -a` |
| 2 | OS release | `cat /etc/os-release; uname -r` |
| 3 | Uptime and load | `uptime; cat /proc/loadavg` |
| 4 | CPU hardware | `lscpu; grep -m1 'model name' /proc/cpuinfo` |
| 5 | Memory and swap | `free -h; cat /proc/meminfo` |
| 6 | Filesystem usage | `df -hT -x tmpfs -x devtmpfs` |
| 7 | Inodes | `df -i -x tmpfs -x devtmpfs` |
| 8 | Block devices | `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL` |
| 9 | Mounts | `findmnt -r; cat /proc/mounts` |
| 10 | Disk health (SMART) | `command -v smartctl && smartctl --scan-open` |
| 11 | Network interfaces | `ip -brief address; ip -s link` |
| 12 | Routes | `ip route; ip -6 route` |
| 13 | DNS configuration | `cat /etc/resolv.conf; command -v resolvectl && resolvectl status` |
| 14 | Local listeners | `ss -lntup` |
| 15 | Network connections | `ss -tunap` |
| 16 | Connectivity | `ping -c 2 -W 2 1.1.1.1` |
| 17 | DNS resolution | `getent ahostsv4 example.com` |
| 18 | Firewall | `command -v ufw && ufw status verbose; command -v nft && nft list ruleset; command -v iptables && iptables -S` |
| 19 | Failed services | `systemctl --failed --no-pager --plain` |
| 20 | Running services | `systemctl list-units --type=service --state=running --no-pager --plain` |
| 21 | Boot failures | `journalctl -b -p err --no-pager -n 100` |
| 22 | Kernel errors | `journalctl -k -b -p err --no-pager -n 100` |
| 23 | Recent critical logs | `journalctl --since '24 hours ago' -p crit --no-pager -n 100` |
| 24 | Recent warnings | `journalctl --since '24 hours ago' -p warning --no-pager -n 100` |
| 25 | Boot performance | `systemd-analyze; systemd-analyze blame --no-pager` |
| 26 | Top CPU processes | `ps -eo pid,ppid,user,%cpu,%mem,stat,comm --sort=-%cpu \| head -n 21` |
| 27 | Top RAM processes | `ps -eo pid,ppid,user,%cpu,%mem,rss,comm --sort=-rss \| head -n 21` |
| 28 | Process states | `ps -eo stat= \| sort \| uniq -c` |
| 29 | Open files limits | `cat /proc/sys/fs/file-nr; ulimit -n` |
| 30 | System limits | `ulimit -a; sysctl vm.swappiness fs.file-max` |
| 31 | Users and sessions | `who; w; last -n 10` |
| 32 | Login failures | `journalctl --since '24 hours ago' _COMM=sshd --no-pager -n 80; command -v lastb && lastb -n 10` |
| 33 | Sudo configuration | `ls -ld /etc/sudoers /etc/sudoers.d; command -v sudo && sudo -n -l` |
| 34 | Security updates | `command -v apt && apt list --upgradable; command -v dnf && dnf check-update; command -v zypper && zypper list-updates` |
| 35 | Package integrity | `command -v dpkg && dpkg --audit; command -v rpm && rpm -Va` |
| 36 | Scheduled jobs | `systemctl list-timers --all --no-pager; ls -l /etc/cron.*` |
| 37 | Time synchronization | `timedatectl; command -v chronyc && chronyc tracking` |
| 38 | Hardware information | `command -v dmidecode && dmidecode -t system; command -v lspci && lspci -nn` |
| 39 | Temperature sensors | `command -v sensors && sensors` |
| 40 | Virtualization | `systemd-detect-virt; command -v pveversion && pveversion -v` |
| 41 | Docker containers | `command -v docker && docker ps -a --no-trunc` |
| 42 | Podman containers | `command -v podman && podman ps -a --no-trunc` |
| 43 | SELinux and AppArmor | `command -v getenforce && getenforce; command -v aa-status && aa-status` |
| 44 | Network statistics | `cat /proc/net/dev; command -v nstat && nstat -az` |
| 45 | System resource pressure | `cat /proc/pressure/cpu /proc/pressure/io /proc/pressure/memory` |

## Project layout

```text
linux-diagnostic-toolkit/
├── linux-diagnostic-toolkit.sh
├── README.md
├── README_EN.md
├── LICENSE
└── .gitignore
```

## Known limitations

- Tool detection is intentionally simple. Missing commands, varying output formats and permissions may result in YELLOW.
- A failed ping is not necessarily an internet outage (ICMP might be blocked).
- SMART currently lists detected devices only; it does **not** provide a comprehensive SMART health check.
- `dpkg --audit` checks package status, not file integrity; `rpm -Va` may hit the timeout.
- Test on the target distribution before production use; this is not a replacement for monitoring, vulnerability scanning or incident response.

## License

MIT – see [LICENSE](LICENSE).