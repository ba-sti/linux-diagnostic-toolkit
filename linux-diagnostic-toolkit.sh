#!/usr/bin/env bash
# Linux Diagnostic Toolkit 1.0.0 - read-only diagnostic collector
# Copyright (c) 2026. MIT License.
set -uo pipefail
export LC_ALL=C
VERSION=1.0.1
LANG_UI=de
NO_COLOR=0
REPORT_DIR="${HOME:-/tmp}/linux-diagnostic-reports"
TIMEOUT_SECONDS=12
declare -a TITLES COMMANDS LEVELS OUTPUTS
COMMAND_COUNT=45

usage() { cat <<USAGE
Linux Diagnostic Toolkit $VERSION
Usage: $(basename "$0") [--lang de|en] [--all] [--check 1-45] [--html] [--txt] [--output-dir DIR] [--timeout SECONDS] [--help]
All checks are read-only. Run as root only when necessary for more details.
USAGE
}
msg() { if [[ "$LANG_UI" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }
init_catalog() {
  local rows
  rows=$(cat <<'CATALOG'
System identity|Systemidentität|hostnamectl; hostname; uname -a
OS release|Betriebssystem|cat /etc/os-release; uname -r
Uptime and load|Laufzeit und Last|uptime; cat /proc/loadavg
CPU hardware|CPU-Hardware|lscpu; grep -m1 'model name' /proc/cpuinfo
Memory and swap|RAM und Swap|free -h; cat /proc/meminfo
Filesystem usage|Dateisystembelegung|df -hT -x tmpfs -x devtmpfs
Inodes|Inodes|df -i -x tmpfs -x devtmpfs
Block devices|Blockgeräte|lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
Mounts|Mounts|findmnt -r; cat /proc/mounts
Disk health (SMART)|Datenträger SMART|command -v smartctl && smartctl --scan-open
Network interfaces|Netzwerkschnittstellen|ip -brief address; ip -s link
Routes|Routing|ip route; ip -6 route
DNS configuration|DNS-Konfiguration|cat /etc/resolv.conf; command -v resolvectl && resolvectl status
Local listeners|Lauschende Ports|ss -lntup
Network connections|Netzwerkverbindungen|ss -tunap
Connectivity|Netzwerkerreichbarkeit|ping -c 2 -W 2 1.1.1.1
DNS resolution|DNS-Auflösung|getent ahostsv4 example.com
Firewall|Firewall|command -v ufw && ufw status verbose; command -v nft && nft list ruleset; command -v iptables && iptables -S
Failed services|Fehlerhafte Dienste|systemctl --failed --no-pager --plain
Running services|Aktive Dienste|systemctl list-units --type=service --state=running --no-pager --plain
Boot failures|Boot-Fehler|journalctl -b -p err --no-pager -n 100
Kernel errors|Kernel-Fehler|journalctl -k -b -p err --no-pager -n 100
Recent critical logs|Kritische Logs|journalctl --since '24 hours ago' -p crit --no-pager -n 100
Recent warnings|Warnungen|journalctl --since '24 hours ago' -p warning --no-pager -n 100
Boot performance|Startdauer|systemd-analyze; systemd-analyze blame --no-pager
Top CPU processes|CPU-intensive Prozesse|ps -eo pid,ppid,user,%cpu,%mem,stat,comm --sort=-%cpu | head -n 21
Top RAM processes|RAM-intensive Prozesse|ps -eo pid,ppid,user,%cpu,%mem,rss,comm --sort=-rss | head -n 21
Process states|Prozesszustände|ps -eo stat= | sort | uniq -c
Open files limits|Dateideskriptoren|cat /proc/sys/fs/file-nr; ulimit -n
System limits|Systemlimits|ulimit -a; sysctl vm.swappiness fs.file-max
Users and sessions|Benutzer und Sitzungen|who; w; last -n 10
Login failures|Fehlgeschlagene Logins|journalctl --since '24 hours ago' _COMM=sshd --no-pager -n 80; command -v lastb && lastb -n 10
Sudo configuration|Sudo-Konfiguration|ls -ld /etc/sudoers /etc/sudoers.d; command -v sudo && sudo -n -l
Security updates|Sicherheitsupdates|command -v apt && apt list --upgradable; command -v dnf && dnf check-update; command -v zypper && zypper list-updates
Package integrity|Paketintegrität|command -v dpkg && dpkg --audit; command -v rpm && rpm -Va
Scheduled jobs|Geplante Aufgaben|systemctl list-timers --all --no-pager; ls -l /etc/cron.*
Time synchronization|Zeitsynchronisation|timedatectl; command -v chronyc && chronyc tracking
Hardware information|Hardwareinformationen|command -v dmidecode && dmidecode -t system; command -v lspci && lspci -nn
Temperature sensors|Temperatursensoren|command -v sensors && sensors
Virtualization|Virtualisierung|systemd-detect-virt; command -v pveversion && pveversion -v
Docker containers|Docker Container|command -v docker && docker ps -a --no-trunc
Podman containers|Podman Container|command -v podman && podman ps -a --no-trunc
SELinux and AppArmor|SELinux und AppArmor|command -v getenforce && getenforce; command -v aa-status && aa-status
Network statistics|Netzwerkstatistik|cat /proc/net/dev; command -v nstat && nstat -az
System resource pressure|System-Ressourcendruck|cat /proc/pressure/cpu /proc/pressure/io /proc/pressure/memory
CATALOG
)
  local id=0 en de cmd
  while IFS='|' read -r en de cmd; do
    ((id+=1)); TITLES[id]="$en|$de"; COMMANDS[id]="$cmd"
  done <<< "$rows"
}
print_catalog() {
 local i name
 for ((i=1;i<=COMMAND_COUNT;i++)); do
  if [[ "$LANG_UI" == en ]]; then name=${TITLES[i]%%|*}; else name=${TITLES[i]#*|}; fi
  printf '%2d  %s\n' "$i" "$name"
 done
}
# Execute each independent command in a subprocess; timeouts prevent hangs.
run_one() {
 local id=$1 name cmd part result rc combined='' success=0 failed=0 missing=0
 if [[ "$LANG_UI" == en ]]; then name=${TITLES[id]%%|*}; else name=${TITLES[id]#*|}; fi
 cmd=${COMMANDS[id]}
 IFS=';' read -r -a parts <<< "$cmd"
 for part in "${parts[@]}"; do
   part="${part#${part%%[![:space:]]*}}"
   [[ -z "$part" ]] && continue
   combined+=$'\n'"\$ $part"$'\n'
   # shellcheck disable=SC2086
   result=$(timeout "${TIMEOUT_SECONDS}s" bash -o pipefail -c "$part" 2>&1) && rc=0 || rc=$?
   if [[ $rc -eq 0 ]]; then ((success+=1))
   elif [[ $rc -eq 124 ]]; then ((failed+=1)); result+=$'\n[TIMEOUT]'
   elif [[ $rc -eq 127 || "$result" == *'command not found'* ]]; then ((missing+=1))
   else ((failed+=1)); fi
   combined+="$result"$'\n'
 done
 OUTPUTS[id]=$combined
 if ((failed>0)); then LEVELS[id]='YELLOW'
 elif ((success==0)); then LEVELS[id]='N/A'
 else LEVELS[id]='GREEN'; fi
 # Explicit evidence, not merely shell exit codes, for a few concrete health checks.
 case "$id" in
  6|7) if grep -Eq '[[:space:]](9[5-9]|100)%[[:space:]]' <<< "$combined"; then LEVELS[id]='RED'; fi ;;
  19) if grep -Eq '^[[:space:]]*[1-9][0-9]* loaded units listed|^[[:space:]]*● .* (failed|not-found)' <<< "$combined"; then LEVELS[id]='RED'; fi ;;
  21|22|23) if grep -Eiq 'segfault|out of memory|oom-killer|I/O error|read-only file system|kernel panic' <<< "$combined"; then LEVELS[id]='RED'; fi ;;
 esac
 printf '[%2d/45] %-42s %s\n' "$id" "$name" "${LEVELS[id]}"
}
# In interactive menu mode show the raw command output before returning.
show_check_details() {
 local id=$1 name
 if [[ "$LANG_UI" == en ]]; then name=${TITLES[id]%%|*}; else name=${TITLES[id]#*|}; fi
 printf '\n============================================================\n'
 printf '%02d - %s [%s]\n' "$id" "$name" "${LEVELS[id]}"
 printf '============================================================\n'
 printf '%s\n' "${OUTPUTS[id]}"
}
pause_menu() {
 local prompt
 prompt=$(msg 'Beliebige Taste drücken, um zum Menü zurückzukehren ...' 'Press any key to return to the menu ...')
 printf '\n%s' "$prompt"
 if [[ -r /dev/tty ]]; then
  IFS= read -r -s -n 1 < /dev/tty || true
 elif [[ -t 0 ]]; then
  IFS= read -r -s -n 1 || true
 fi
 printf '\n'
}
html_escape() { local s=$1; s=${s//&/\&amp;}; s=${s//</\&lt;}; s=${s//>/\&gt;}; s=${s//\"/\&quot;}; printf '%s' "$s"; }
save_reports() {
 local do_txt=$1 do_html=$2 stamp host base i name verdict c green=0 yellow=0 red=0 na=0
 stamp=$(date '+%Y%m%d-%H%M%S'); host=$(hostname -s 2>/dev/null || echo linux)
 host=${host//[^a-zA-Z0-9._-]/_}; mkdir -p -- "$REPORT_DIR" || return 1
 base="$REPORT_DIR/linux-diagnostic-${host}-${stamp}"
 for ((i=1;i<=COMMAND_COUNT;i++)); do
  [[ -z ${LEVELS[i]:-} ]] && continue
  case "${LEVELS[i]}" in GREEN) ((green+=1));; YELLOW) ((yellow+=1));; RED) ((red+=1));; *) ((na+=1));; esac
 done
 if ((do_txt)); then
  {
   printf 'Linux Diagnostic Toolkit %s | %s | %s\n' "$VERSION" "$host" "$(date -Is)"
   printf 'GREEN=%d YELLOW=%d RED=%d N/A=%d\n' "$green" "$yellow" "$red" "$na"
   for ((i=1;i<=COMMAND_COUNT;i++)); do
    [[ -z ${LEVELS[i]:-} ]] && continue
    if [[ "$LANG_UI" == en ]]; then name=${TITLES[i]%%|*}; else name=${TITLES[i]#*|}; fi
    printf '\n======= %02d %s [%s] =======\n%s\n' "$i" "$name" "${LEVELS[i]}" "${OUTPUTS[i]}"
   done
  } > "${base}.txt"
  printf 'TXT: %s\n' "${base}.txt"
 fi
 if ((do_html)); then
  {
   cat <<HTML
<!doctype html><html lang="$LANG_UI"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Linux Diagnostic Toolkit</title>
<style>:root{color-scheme:dark}body{background:#101827;color:#e6edf5;font:15px system-ui,sans-serif;margin:0}.wrap{max-width:1200px;margin:auto;padding:28px}h1{margin-bottom:4px}small{color:#9aabc0}.summary{display:flex;flex-wrap:wrap;gap:12px;margin:22px 0}.pill{background:#1b273a;border-radius:9px;padding:14px 20px}details{background:#192438;border:1px solid #2b3a51;border-radius:10px;margin:10px 0}summary{cursor:pointer;padding:16px;font-weight:600}pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:16px;margin:0;border-top:1px solid #2b3a51;font:12px/1.5 ui-monospace,monospace}.GREEN{color:#55dca2}.YELLOW{color:#ffd36f}.RED{color:#ff6a79}.NA{color:#9caabe}input{background:#243247;color:white;border:1px solid #42516b;border-radius:8px;padding:10px;width:100%;box-sizing:border-box}</style></head><body><main class="wrap"><h1>Linux Diagnostic Toolkit</h1><small>$(html_escape "$host") · $(html_escape "$(date -Is)") · v$VERSION</small><div class="summary"><div class="pill GREEN">GREEN $green</div><div class="pill YELLOW">YELLOW $yellow</div><div class="pill RED">RED $red</div><div class="pill NA">N/A $na</div></div><input id="filter" aria-label="Filter checks" placeholder="Search / Suchen..."><section id="checks">
HTML
   for ((i=1;i<=COMMAND_COUNT;i++)); do
    [[ -z ${LEVELS[i]:-} ]] && continue
    if [[ "$LANG_UI" == en ]]; then name=${TITLES[i]%%|*}; else name=${TITLES[i]#*|}; fi
    verdict=${LEVELS[i]}; [[ "$verdict" == 'N/A' ]] && c=NA || c=$verdict
    printf '<details><summary>%02d. %s — <span class="%s">%s</span></summary><pre>%s</pre></details>\n' "$i" "$(html_escape "$name")" "$c" "$verdict" "$(html_escape "${OUTPUTS[i]}")"
   done
   cat <<'HTML'
</section></main><script>document.getElementById('filter').addEventListener('input',function(){let q=this.value.toLowerCase();document.querySelectorAll('details').forEach(x=>x.hidden=!x.textContent.toLowerCase().includes(q));});</script></body></html>
HTML
  } > "${base}.html"
  printf 'HTML: %s\n' "${base}.html"
 fi
 printf '%s\n' "$(msg 'Hinweis: Berichte können private System- und Netzwerkinformationen enthalten.' 'Note: Reports may contain private system and network information.')"
}
main() {
 local all=0 check='' txt=1 html=1 arg
 while (($#)); do
  arg=$1; shift
  case "$arg" in
   --lang) (($#)) || { usage >&2; return 2; }; LANG_UI=$1; shift; [[ "$LANG_UI" == de || "$LANG_UI" == en ]] || return 2;;
   --all) all=1;;
   --check) (($#)) || return 2; check=$1; shift;;
   --html) html=1; txt=0;;
   --txt) txt=1; html=0;;
   --output-dir) (($#)) || return 2; REPORT_DIR=$1; shift;;
   --timeout) (($#)) || return 2; TIMEOUT_SECONDS=$1; shift; [[ "$TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || return 2;;
   --help|-h) usage; return 0;;
   *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; return 2;;
  esac
 done
 init_catalog
 if [[ -n "$check" ]]; then
  [[ "$check" =~ ^[0-9]+$ ]] && ((10#$check>=1 && 10#$check<=COMMAND_COUNT)) || { echo 'Check must be 1-45' >&2; return 2; }
  run_one "$((10#$check))"; save_reports "$txt" "$html"; return
 fi
 if ((all)); then local i; for ((i=1;i<=COMMAND_COUNT;i++)); do run_one "$i"; done; save_reports "$txt" "$html"; return; fi
 while true; do
  printf '\n===== Linux Diagnostic Toolkit v%s =====\n' "$VERSION"
  print_catalog
  printf '\n A = %s | Q = %s\n' "$(msg 'Komplettcheck' 'Run all checks')" "$(msg 'Beenden' 'Quit')"
  read -r -p '> ' choice || break
  case "$choice" in
   a|A) local i; for ((i=1;i<=COMMAND_COUNT;i++)); do run_one "$i"; done; save_reports "$txt" "$html"; pause_menu;;
   q|Q) break;;
   *) if [[ "$choice" =~ ^[0-9]+$ ]] && ((10#$choice>=1 && 10#$choice<=COMMAND_COUNT)); then run_one "$((10#$choice))"; show_check_details "$((10#$choice))"; save_reports "$txt" "$html"; pause_menu; else echo "Invalid / Ungültig"; pause_menu; fi;;
  esac
 done
}
main "$@"