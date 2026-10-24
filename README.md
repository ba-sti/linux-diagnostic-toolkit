# Linux Diagnostic Toolkit

Ein menügesteuertes, weitgehend distributionsunabhängiges Bash-Werkzeug zur **lesenden** Diagnose von Linux-Systemen. Inspiriert vom Windows Diagnostic Toolkit. **45 Diagnosepunkte**, Einzel- oder Gesamtausführung, TXT-/HTML-Report und eine einfache Statusbewertung (GREEN/YELLOW/RED/N/A).

## Unterstützte Systeme

Vorrangig Debian 12/13, Ubuntu sowie Proxmox VE (Host und LXC/VM); weitere systemd-basierte Linux-Distributionen mit verfügbaren Standardwerkzeugen. Bestimmte Funktionen benötigen zusätzliche Tools oder erhöhte Rechte.

## Installation und Nutzung

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

## Bewertung und Datenschutz

Die Statusampel ist **heuristisch und keine Sicherheitszertifizierung**. GREEN bedeutet nur, dass die aufgerufenen Befehle überwiegend erfolgreich liefen; YELLOW weist auf Fehler/fehlende Berechtigungen/Timeouts hin; RED auf ausgewählte starke Indikatoren (z. B. Dateisystem >=95 %, bestimmte Kernelmeldungen). N/A bedeutet keine verwertbare Ausführung. Es gibt keine Änderungen an Paketen, Firewall, Services oder Konfiguration. Diagnosen können Benutzernamen, IPs, Logeinträge und andere vertrauliche Informationen enthalten: **Berichte vor einer Veröffentlichung prüfen und bereinigen**. Einige Kommandos sind in Containern möglicherweise nicht nutzbar. Eine Live-Netzwerkprüfung (Ping und DNS) ist enthalten; diese sind nicht rein offline.

## Diagnosepunkte und verwendete Befehle

Die Befehle werden pro Punkt getrennt ausgeführt; ein fehlendes optionales Programm verhindert die restlichen Tests nicht.

| # | Menüpunkt | Linux-Befehle |
|---:|---|---|
| 1 | Systemidentität | `hostnamectl; hostname; uname -a` |
| 2 | Betriebssystem | `cat /etc/os-release; uname -r` |
| 3 | Laufzeit und Last | `uptime; cat /proc/loadavg` |
| 4 | CPU-Hardware | `lscpu; grep -m1 'model name' /proc/cpuinfo` |
| 5 | RAM und Swap | `free -h; cat /proc/meminfo` |
| 6 | Dateisystembelegung | `df -hT -x tmpfs -x devtmpfs` |
| 7 | Inodes | `df -i -x tmpfs -x devtmpfs` |
| 8 | Blockgeräte | `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL` |
| 9 | Mounts | `findmnt -r; cat /proc/mounts` |
| 10 | Datenträger SMART | `command -v smartctl && smartctl --scan-open` |
| 11 | Netzwerkschnittstellen | `ip -brief address; ip -s link` |
| 12 | Routing | `ip route; ip -6 route` |
| 13 | DNS-Konfiguration | `cat /etc/resolv.conf; command -v resolvectl && resolvectl status` |
| 14 | Lauschende Ports | `ss -lntup` |
| 15 | Netzwerkverbindungen | `ss -tunap` |
| 16 | Netzwerkerreichbarkeit | `ping -c 2 -W 2 1.1.1.1` |
| 17 | DNS-Auflösung | `getent ahostsv4 example.com` |
| 18 | Firewall | `command -v ufw && ufw status verbose; command -v nft && nft list ruleset; command -v iptables && iptables -S` |
| 19 | Fehlerhafte Dienste | `systemctl --failed --no-pager --plain` |
| 20 | Aktive Dienste | `systemctl list-units --type=service --state=running --no-pager --plain` |
| 21 | Boot-Fehler | `journalctl -b -p err --no-pager -n 100` |
| 22 | Kernel-Fehler | `journalctl -k -b -p err --no-pager -n 100` |
| 23 | Kritische Logs | `journalctl --since '24 hours ago' -p crit --no-pager -n 100` |
| 24 | Warnungen | `journalctl --since '24 hours ago' -p warning --no-pager -n 100` |
| 25 | Startdauer | `systemd-analyze; systemd-analyze blame --no-pager` |
| 26 | CPU-intensive Prozesse | `ps -eo pid,ppid,user,%cpu,%mem,stat,comm --sort=-%cpu \| head -n 21` |
| 27 | RAM-intensive Prozesse | `ps -eo pid,ppid,user,%cpu,%mem,rss,comm --sort=-rss \| head -n 21` |
| 28 | Prozesszustände | `ps -eo stat= \| sort \| uniq -c` |
| 29 | Dateideskriptoren | `cat /proc/sys/fs/file-nr; ulimit -n` |
| 30 | Systemlimits | `ulimit -a; sysctl vm.swappiness fs.file-max` |
| 31 | Benutzer und Sitzungen | `who; w; last -n 10` |
| 32 | Fehlgeschlagene Logins | `journalctl --since '24 hours ago' _COMM=sshd --no-pager -n 80; command -v lastb && lastb -n 10` |
| 33 | Sudo-Konfiguration | `ls -ld /etc/sudoers /etc/sudoers.d; command -v sudo && sudo -n -l` |
| 34 | Sicherheitsupdates | `command -v apt && apt list --upgradable; command -v dnf && dnf check-update; command -v zypper && zypper list-updates` |
| 35 | Paketintegrität | `command -v dpkg && dpkg --audit; command -v rpm && rpm -Va` |
| 36 | Geplante Aufgaben | `systemctl list-timers --all --no-pager; ls -l /etc/cron.*` |
| 37 | Zeitsynchronisation | `timedatectl; command -v chronyc && chronyc tracking` |
| 38 | Hardwareinformationen | `command -v dmidecode && dmidecode -t system; command -v lspci && lspci -nn` |
| 39 | Temperatursensoren | `command -v sensors && sensors` |
| 40 | Virtualisierung | `systemd-detect-virt; command -v pveversion && pveversion -v` |
| 41 | Docker Container | `command -v docker && docker ps -a --no-trunc` |
| 42 | Podman Container | `command -v podman && podman ps -a --no-trunc` |
| 43 | SELinux und AppArmor | `command -v getenforce && getenforce; command -v aa-status && aa-status` |
| 44 | Netzwerkstatistik | `cat /proc/net/dev; command -v nstat && nstat -az` |
| 45 | System-Ressourcendruck | `cat /proc/pressure/cpu /proc/pressure/io /proc/pressure/memory` |

## Projektaufbau

```text
linux-diagnostic-toolkit/
├── linux-diagnostic-toolkit.sh
├── README.md
├── README_EN.md
├── LICENSE
└── .gitignore
```

## Bekannte Grenzen

- Die Tool-Erkennung ist bewusst einfach gehalten. Fehlende Befehle, abweichende Ausgabeformate oder fehlende Rechte können YELLOW ergeben.
- Ein fehlgeschlagener Ping bedeutet nicht zwangsläufig eine gestörte Internetverbindung (ICMP kann blockiert sein).
- Der SMART-Test listet aktuell nur unterstützte Geräte; es findet **keine** vollständige SMART-Gesundheitsprüfung statt.
- `dpkg --audit` prüft Paketstatus, nicht die Integrität aller Dateien. `rpm -Va` kann die Laufzeitgrenze erreichen.
- Vor Produktiveinsatz auf der jeweiligen Distribution prüfen; kein Ersatz für Monitoring, Schwachstellenscanner oder Incident-Response-Werkzeuge.

## Lizenz

MIT – siehe [LICENSE](LICENSE).