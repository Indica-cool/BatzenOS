#!/usr/bin/env bash
# net-doctor.sh — Diagnose und Reparatur des NetworkManager-Stacks,
# damit WLAN/LAN wieder ueber die GUI (Celestia Shell / Quickshell) verbindbar ist.
#
#   ./net-doctor.sh              nur diagnostizieren (aendert nichts)
#   ./net-doctor.sh --fix        gefundene Probleme reparieren (mit Backups)
#   ./net-doctor.sh --report FILE  Diagnose zusaetzlich in FILE schreiben
#   ./net-doctor.sh --yes        keine Rueckfragen bei --fix
#
# Alle Aenderungen an Configs werden vorher nach
# /var/backups/net-doctor/<timestamp>/ gesichert.

set -uo pipefail

FIX=0; ASSUME_YES=0; REPORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --report) REPORT="${2:-}"; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
  shift
done

# ---------------------------------------------------------------- Ausgabe ----
if [ -t 1 ] && [ -z "$REPORT" ]; then
  C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_B=$'\e[34m'; C_D=$'\e[2m'; C_0=$'\e[0m'
else
  C_R=""; C_G=""; C_Y=""; C_B=""; C_D=""; C_0=""
fi

FINDINGS=()      # "SEVERITY|Titel|Erklaerung"
FIXES_DONE=()
FIXES_SKIPPED=()

out() { printf '%s\n' "$*"; [ -n "$REPORT" ] && printf '%s\n' "$*" >>"$REPORT"; }
hdr() { out ""; out "${C_B}== $* ==${C_0}"; }
ok()  { out "  ${C_G}ok${C_0}    $*"; }
warn(){ out "  ${C_Y}warn${C_0}  $*"; }
bad() { out "  ${C_R}FEHL${C_0}  $*"; }
info(){ out "  ${C_D}info${C_0}  $*"; }

finding() { FINDINGS+=("$1|$2|$3"); }

have() { command -v "$1" >/dev/null 2>&1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if have sudo; then SUDO="sudo"; else SUDO=""; fi
fi
run_priv() { if [ -n "$SUDO" ]; then $SUDO "$@"; else "$@"; fi; }

confirm() {
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local a; printf '  -> %s [j/N] ' "$1" >&2; read -r a </dev/tty 2>/dev/null || return 1
  case "$a" in j|J|y|Y|ja|Ja) return 0 ;; *) return 1 ;; esac
}

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/var/backups/net-doctor/$STAMP"
backup_file() {
  [ -e "$1" ] || return 0
  run_priv mkdir -p "$BACKUP_DIR$(dirname "$1")" 2>/dev/null
  run_priv cp -a "$1" "$BACKUP_DIR$1" 2>/dev/null && info "Backup: $1 -> $BACKUP_DIR$1"
}

[ -n "$REPORT" ] && : >"$REPORT"

# ------------------------------------------------------------ 0. System ------
hdr "System"
if [ -r /etc/os-release ]; then . /etc/os-release; out "  Distro:  ${PRETTY_NAME:-unbekannt}"; fi
out "  Kernel:  $(uname -r)"
out "  Session: ${XDG_SESSION_TYPE:-?} / ${XDG_CURRENT_DESKTOP:-?}"
out "  User:    $(id -un) (Gruppen: $(id -Gn | tr ' ' ','))"

PKG=""
have pacman && PKG=pacman
have apt-get && PKG=${PKG:-apt}
have dnf && PKG=${PKG:-dnf}
have zypper && PKG=${PKG:-zypper}
out "  Paketmanager: ${PKG:-unbekannt}"

pkg_install() {
  case "$PKG" in
    pacman) run_priv pacman -S --needed --noconfirm "$@" ;;
    apt)    run_priv apt-get install -y "$@" ;;
    dnf)    run_priv dnf install -y "$@" ;;
    zypper) run_priv zypper --non-interactive install "$@" ;;
    *) return 1 ;;
  esac
}

# --------------------------------------------------- 1. NetworkManager -------
hdr "1. NetworkManager-Dienst"
NM_PRESENT=0
if have nmcli || systemctl list-unit-files 2>/dev/null | grep -q '^NetworkManager\.service'; then
  NM_PRESENT=1
fi
if [ "$NM_PRESENT" -eq 0 ]; then
  bad "NetworkManager ist gar nicht installiert."
  finding CRIT "NetworkManager fehlt" "Ohne NetworkManager kann die Shell-GUI nichts verbinden."
else
  NM_ACTIVE=$(systemctl is-active NetworkManager 2>/dev/null || echo unknown)
  NM_ENABLED=$(systemctl is-enabled NetworkManager 2>/dev/null || echo unknown)
  if [ "$NM_ACTIVE" = active ]; then ok "NetworkManager laeuft"; else
    bad "NetworkManager laeuft nicht (Status: $NM_ACTIVE)"
    finding CRIT "NetworkManager gestoppt" "systemctl start NetworkManager"
  fi
  if [ "$NM_ENABLED" = enabled ]; then ok "NetworkManager startet automatisch"; else
    warn "NetworkManager ist nicht enabled (Status: $NM_ENABLED) -> nach Reboot kein Netz"
    finding WARN "NetworkManager nicht enabled" "systemctl enable NetworkManager"
  fi
  have nmcli && out "  $(nmcli -t general status 2>/dev/null | head -1 | sed 's/^/nmcli general: /')"
fi

# --------------------------------------- 2. Konkurrierende Netzdienste -------
hdr "2. Konkurrierende Netzwerkdienste"
CONFLICTS=()
for svc in systemd-networkd dhcpcd connman netctl wicd NetworkManager-wait-online; do
  st=$(systemctl is-active "$svc" 2>/dev/null || true)
  en=$(systemctl is-enabled "$svc" 2>/dev/null || true)
  if [ "$st" = active ] || [ "$en" = enabled ]; then
    case "$svc" in
      NetworkManager-wait-online)
        [ "$st" = failed ] && warn "$svc failed (blockiert nur den Boot, kein Verbindungsproblem)" ;;
      *)
        bad "$svc ist aktiv/enabled und streitet sich mit NetworkManager um die Interfaces"
        CONFLICTS+=("$svc")
        finding CRIT "Konflikt: $svc" "Zwei Manager auf einem Interface => Device wird unmanaged oder flappt." ;;
    esac
  fi
done
[ ${#CONFLICTS[@]} -eq 0 ] && ok "keine konkurrierenden Netzwerkdienste aktiv"

# Netplan (Ubuntu): renderer networkd entzieht NM die Geraete
NETPLAN_BAD=()
if [ -d /etc/netplan ]; then
  while IFS= read -r f; do
    if grep -qE '^\s*renderer:\s*networkd' "$f" 2>/dev/null; then
      bad "netplan $f nutzt renderer: networkd -> NetworkManager sieht das Geraet nicht"
      NETPLAN_BAD+=("$f")
      finding CRIT "netplan renderer networkd" "renderer auf NetworkManager umstellen ($f)"
    fi
  done < <(find /etc/netplan -name '*.yaml' 2>/dev/null)
  [ ${#NETPLAN_BAD[@]} -eq 0 ] && [ -n "$(ls -A /etc/netplan 2>/dev/null)" ] && ok "netplan-Konfiguration unauffaellig"
fi

# ------------------------------------------------------------ 3. rfkill -----
hdr "3. Funk-Sperren (rfkill)"
RFKILL_BLOCKED=0
if have rfkill; then
  if rfkill list 2>/dev/null | grep -q 'Soft blocked: yes'; then
    bad "Soft-Block aktiv (Software hat den Funk abgeschaltet)"
    RFKILL_BLOCKED=1
    finding CRIT "rfkill soft block" "rfkill unblock all"
  else ok "kein Soft-Block"; fi
  if rfkill list 2>/dev/null | grep -q 'Hard blocked: yes'; then
    bad "HARD-Block aktiv -> Hardware-Schalter / Fn-Taste am Geraet umlegen, das kann Software nicht fixen"
    finding CRIT "rfkill hard block" "Physischer WLAN-Schalter oder Fn+F-Taste ist aus."
  else ok "kein Hard-Block"; fi
  out "$(rfkill list 2>/dev/null | sed 's/^/    /')"
else
  info "rfkill nicht installiert (uebersprungen)"
fi

WIFI_RADIO=""
if have nmcli; then
  WIFI_RADIO=$(nmcli radio wifi 2>/dev/null)
  if [ "$WIFI_RADIO" = enabled ]; then ok "nmcli radio wifi: enabled"
  elif [ -n "$WIFI_RADIO" ]; then
    bad "nmcli radio wifi: $WIFI_RADIO -> WLAN in NM abgeschaltet"
    finding CRIT "WLAN-Radio aus" "nmcli radio wifi on"
  fi
fi

# ------------------------------------------------------ 4. Hardware/Treiber --
hdr "4. Hardware und Kernel-Treiber"
NO_DRIVER=0
if have lspci; then
  while IFS= read -r line; do
    out "    $line"
  done < <(lspci -k 2>/dev/null | grep -A3 -iE 'network controller|ethernet controller|wireless')
  # Controller ohne "Kernel driver in use"
  while IFS= read -r blk; do
    case "$blk" in
      *"Kernel driver in use"*) : ;;
      *) NO_DRIVER=1 ;;
    esac
  done < <(lspci -k 2>/dev/null | awk '/Network controller|Wireless/{p=1;b=$0;next} p&&/^\t/{b=b" "$0;next} p{print b;p=0} END{if(p)print b}')
  if [ "$NO_DRIVER" -eq 1 ]; then
    bad "Mindestens ein Netzwerk-Controller hat KEINEN geladenen Kernel-Treiber"
    finding CRIT "Treiber fehlt" "Firmware/Treiber-Paket nachinstallieren (linux-firmware, ggf. Vendor-Modul)."
  else
    ok "alle erkannten Controller haben einen Treiber geladen"
  fi
else
  info "lspci nicht verfuegbar (pciutils fehlt)"
fi
have lsusb && lsusb 2>/dev/null | grep -iE 'wlan|wireless|802\.11|ethernet' | sed 's/^/    /' | while read -r l; do out "$l"; done

FW_MISSING=0
if have dmesg; then
  FW_LINES=$( (dmesg 2>/dev/null || run_priv dmesg 2>/dev/null) | grep -iE 'firmware.*(fail|missing|not found|direct load)|iwlwifi.*(error|fail)|brcm.*(fail|missing)|rtw.*(fail|missing)' | tail -15 )
  if [ -n "$FW_LINES" ]; then
    bad "Kernel meldet Firmware-Probleme:"
    out "$(printf '%s\n' "$FW_LINES" | sed 's/^/    /')"
    FW_MISSING=1
    finding CRIT "Firmware fehlt/laedt nicht" "linux-firmware installieren bzw. passendes Vendor-Firmware-Paket."
  else
    ok "keine Firmware-Fehler im Kernel-Log"
  fi
fi

# ---------------------------------------------------- 5. NM-Geraetestatus ----
hdr "5. Geraete laut NetworkManager"
UNMANAGED_DEVS=()
UNAVAILABLE_DEVS=()
if have nmcli; then
  out "$(nmcli -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | sed 's/^/    /')"
  while IFS=: read -r dev typ state _; do
    [ "$typ" = loopback ] && continue
    case "$state" in
      unmanaged)   UNMANAGED_DEVS+=("$dev") ;;
      unavailable) UNAVAILABLE_DEVS+=("$dev") ;;
    esac
  done < <(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null)
  if [ ${#UNMANAGED_DEVS[@]} -gt 0 ]; then
    bad "unmanaged: ${UNMANAGED_DEVS[*]} -> NM fasst diese Geraete nicht an, GUI zeigt sie gar nicht erst"
    finding CRIT "Geraet unmanaged" "nmcli dev set <dev> managed yes + unmanaged-Eintraege aus /etc/NetworkManager entfernen"
  fi
  if [ ${#UNAVAILABLE_DEVS[@]} -gt 0 ]; then
    warn "unavailable: ${UNAVAILABLE_DEVS[*]} -> meist rfkill, fehlende Firmware oder falsches wifi.backend"
    finding WARN "Geraet unavailable" "Siehe rfkill/Firmware/Backend-Abschnitte."
  fi
  [ ${#UNMANAGED_DEVS[@]} -eq 0 ] && [ ${#UNAVAILABLE_DEVS[@]} -eq 0 ] && ok "alle Geraete werden von NM verwaltet"
fi

# ------------------------------------------------------- 6. NM-Konfiguration -
hdr "6. NetworkManager-Konfiguration"
NM_CONF=/etc/NetworkManager/NetworkManager.conf
CONF_FILES=("$NM_CONF")
while IFS= read -r f; do CONF_FILES+=("$f"); done < <(find /etc/NetworkManager/conf.d -name '*.conf' 2>/dev/null)

UNMANAGED_CONF=()
for f in "${CONF_FILES[@]}"; do
  [ -r "$f" ] || continue
  if grep -qE '^\s*unmanaged-devices\s*=' "$f" 2>/dev/null; then
    bad "$f setzt unmanaged-devices:"
    out "$(grep -nE '^\s*unmanaged-devices\s*=' "$f" | sed 's/^/      /')"
    UNMANAGED_CONF+=("$f")
    finding CRIT "unmanaged-devices in Config" "$f entfernt Geraete aus NM-Verwaltung"
  fi
  if grep -qE '^\s*managed\s*=\s*false' "$f" 2>/dev/null; then
    warn "$f: ifupdown managed=false (Debian/Ubuntu-Klassiker)"
    UNMANAGED_CONF+=("$f")
    finding WARN "ifupdown managed=false" "Interfaces aus /etc/network/interfaces werden NM entzogen"
  fi
done
[ ${#UNMANAGED_CONF[@]} -eq 0 ] && ok "keine unmanaged-Direktiven gefunden"

# wifi.backend vs. tatsaechlich laufender Supplicant
BACKEND=""
for f in "${CONF_FILES[@]}"; do
  [ -r "$f" ] || continue
  b=$(grep -E '^\s*wifi\.backend\s*=' "$f" 2>/dev/null | tail -1 | sed 's/.*=\s*//' | tr -d ' ')
  [ -n "$b" ] && BACKEND="$b" && info "wifi.backend=$b (aus $f)"
done
[ -z "$BACKEND" ] && BACKEND="wpa_supplicant" && info "wifi.backend nicht gesetzt -> Default wpa_supplicant"

IWD_ACTIVE=$(systemctl is-active iwd 2>/dev/null || true)
WPA_ACTIVE=$(systemctl is-active wpa_supplicant 2>/dev/null || true)
BACKEND_MISMATCH=""
case "$BACKEND" in
  iwd)
    if [ "$IWD_ACTIVE" != active ]; then
      bad "wifi.backend=iwd, aber iwd.service laeuft nicht -> WLAN bleibt tot"
      BACKEND_MISMATCH=iwd
      finding CRIT "Backend-Mismatch (iwd)" "Entweder iwd starten/enablen oder wifi.backend auf wpa_supplicant zuruecksetzen."
    else ok "Backend iwd aktiv und konsistent"; fi
    if [ "$WPA_ACTIVE" = active ]; then
      bad "iwd UND wpa_supplicant laufen gleichzeitig -> die beiden reissen sich das Geraet gegenseitig weg"
      finding CRIT "iwd + wpa_supplicant parallel" "Einen der beiden Supplicants abschalten."
    fi ;;
  wpa_supplicant)
    if [ "$IWD_ACTIVE" = active ]; then
      bad "Backend ist wpa_supplicant, aber iwd laeuft und belegt das WLAN-Geraet"
      BACKEND_MISMATCH=wpa
      finding CRIT "iwd laeuft trotz wpa_supplicant-Backend" "iwd stoppen/disablen oder Backend auf iwd stellen."
    else ok "Backend wpa_supplicant konsistent"; fi ;;
esac

# Rechte der gespeicherten Verbindungen: NM ignoriert Dateien mit zu offenen Rechten
BADPERM=()
if [ -d /etc/NetworkManager/system-connections ]; then
  while IFS= read -r f; do
    p=$(stat -c '%a %U:%G' "$f" 2>/dev/null)
    case "$p" in
      "600 root:root"|"700 root:root") : ;;
      *) BADPERM+=("$f"); bad "unsichere Rechte ($p) auf $f -> NM laedt die Verbindung NICHT" ;;
    esac
  done < <(run_priv find /etc/NetworkManager/system-connections -type f 2>/dev/null)
  if [ ${#BADPERM[@]} -gt 0 ]; then
    finding CRIT "Falsche Rechte auf gespeicherten Verbindungen" "chmod 600 + chown root:root noetig, sonst verschwinden gespeicherte WLANs aus der GUI."
  else
    ok "Rechte der gespeicherten Verbindungen in Ordnung"
  fi
fi

# --------------------------------------------------------------- 7. DNS ------
hdr "7. DNS"
DNS_MODE=""
for f in "${CONF_FILES[@]}"; do
  [ -r "$f" ] || continue
  d=$(grep -E '^\s*dns\s*=' "$f" 2>/dev/null | tail -1 | sed 's/.*=\s*//' | tr -d ' ')
  [ -n "$d" ] && DNS_MODE="$d"
done
info "NM dns-Modus: ${DNS_MODE:-default}"
RESOLVED_ACTIVE=$(systemctl is-active systemd-resolved 2>/dev/null || true)
info "systemd-resolved: ${RESOLVED_ACTIVE:-nicht vorhanden}"
if [ -L /etc/resolv.conf ]; then
  TARGET=$(readlink -f /etc/resolv.conf 2>/dev/null)
  if [ -e "$TARGET" ]; then ok "/etc/resolv.conf -> $TARGET"; else
    bad "/etc/resolv.conf ist ein toter Symlink ($TARGET) -> verbunden, aber keine Namensaufloesung"
    finding CRIT "resolv.conf kaputt" "Symlink reparieren (systemd-resolved) bzw. dns-Modus anpassen."
  fi
elif [ -s /etc/resolv.conf ]; then ok "/etc/resolv.conf vorhanden"
else
  bad "/etc/resolv.conf fehlt oder ist leer -> keine Namensaufloesung"
  finding CRIT "resolv.conf leer" "DNS-Backend von NM reparieren."
fi
if [ "$DNS_MODE" = systemd-resolved ] && [ "$RESOLVED_ACTIVE" != active ]; then
  bad "dns=systemd-resolved gesetzt, aber der Dienst laeuft nicht"
  finding CRIT "DNS-Mismatch" "systemd-resolved starten oder dns-Modus aendern."
fi

# ----------------------------------------------- 8. Polkit / GUI-Berechtigung -
hdr "8. Polkit (der haeufigste Grund, warum NUR die GUI nicht verbindet)"
POLKIT_AGENT=""
for p in hyprpolkitagent polkit-gnome-authentication-agent-1 polkit-kde-authentication-agent-1 \
         lxqt-policykit-agent mate-polkit xfce-polkit polkit-mate-authentication-agent-1 \
         gnome-shell plasma-polkit-agent; do
  if pgrep -x "$p" >/dev/null 2>&1 || pgrep -f "$p" >/dev/null 2>&1; then POLKIT_AGENT="$p"; break; fi
done
if [ -n "$POLKIT_AGENT" ]; then
  ok "Polkit-Authentifizierungsagent laeuft: $POLKIT_AGENT"
else
  bad "KEIN Polkit-Agent im Session-Kontext gefunden"
  out "        Genau das erzeugt das Muster: 'als root/nmcli geht alles, in der Shell-GUI passiert nichts'."
  out "        Die GUI darf die Verbindung nicht aktivieren, weil niemand den Passwortdialog anzeigt."
  finding CRIT "Polkit-Agent fehlt" "Agent installieren und in der Wayland-Session autostarten."
fi

POLKIT_VER=""
have pkaction && POLKIT_VER=$(pkaction --version 2>/dev/null | awk '{print $NF}')
[ -n "$POLKIT_VER" ] && info "polkit Version: $POLKIT_VER"

if have pkcheck; then
  for act in org.freedesktop.NetworkManager.settings.modify.system \
             org.freedesktop.NetworkManager.network-control \
             org.freedesktop.NetworkManager.enable-disable-wifi; do
    if pkcheck --action-id "$act" --process $$ >/dev/null 2>&1; then
      ok "erlaubt: $act"
    else
      warn "nicht ohne Nachfrage erlaubt: $act"
    fi
  done
fi

# Sitzung wirklich lokal/aktiv? (remote/inaktive Sessions bekommen von polkit nichts)
if have loginctl; then
  SID=$(loginctl show-user "$(id -un)" -p Display --value 2>/dev/null)
  if [ -n "$SID" ]; then
    ACT=$(loginctl show-session "$SID" -p Active --value 2>/dev/null)
    REM=$(loginctl show-session "$SID" -p Remote --value 2>/dev/null)
    [ "$ACT" = yes ] && ok "Session $SID ist aktiv" || { bad "Session $SID ist NICHT aktiv -> polkit verweigert"; finding CRIT "Session inaktiv" "loginctl meldet Active=no"; }
    [ "$REM" = yes ] && warn "Session ist remote -> viele polkit-Regeln greifen nicht"
  fi
fi

# ------------------------------------------- 9. D-Bus-Zugriff als Benutzer ----
hdr "9. D-Bus-Zugriff auf NetworkManager (das nutzt die Shell-GUI)"
if have busctl; then
  if busctl --system introspect org.freedesktop.NetworkManager /org/freedesktop/NetworkManager >/dev/null 2>&1; then
    ok "org.freedesktop.NetworkManager ist als $(id -un) ueber D-Bus erreichbar"
  else
    bad "D-Bus-Interface von NetworkManager als Benutzer NICHT erreichbar"
    out "        -> Die Shell kann keine Netzwerkliste holen. Meist: NM laeuft nicht, oder dbus-Policy/Session kaputt."
    finding CRIT "NM ueber D-Bus nicht erreichbar" "NetworkManager starten; Session-D-Bus pruefen."
  fi
fi
if have nmcli; then
  if nmcli -t -f RUNNING general 2>/dev/null | grep -q running; then
    ok "nmcli als Benutzer spricht mit dem Daemon"
  else
    bad "nmcli als Benutzer erreicht den Daemon nicht"
    finding CRIT "nmcli ohne Daemon-Kontakt" "NetworkManager-Dienst pruefen."
  fi
fi

# ------------------------------------------------- 10. Celestia Shell / QS ----
hdr "10. Celestia Shell / Quickshell"
SHELL_PROC=""
for p in quickshell qs celestia celestia-shell; do
  if pgrep -x "$p" >/dev/null 2>&1; then SHELL_PROC="$p"; break; fi
done
if [ -n "$SHELL_PROC" ]; then ok "Shell-Prozess laeuft: $SHELL_PROC"
else warn "kein Quickshell/Celestia-Prozess gefunden (laeuft die Shell gerade?)"; fi

for d in "$HOME/.config/quickshell" "$HOME/.config/celestia" "$HOME/.config/Celestia"; do
  [ -d "$d" ] && info "Config gefunden: $d"
done
# Welche Netzwerk-Backends bindet die Shell an?
for d in "$HOME/.config/quickshell" "$HOME/.config/celestia"; do
  [ -d "$d" ] || continue
  if grep -rslE 'nmcli|NetworkManager|org\.freedesktop\.NetworkManager|iwd|iwctl' "$d" 2>/dev/null | head -5 | grep -q .; then
    info "Shell-Module mit Netzwerkbezug:"
    grep -rslE 'nmcli|NetworkManager|org\.freedesktop\.NetworkManager|iwd|iwctl' "$d" 2>/dev/null | head -5 | sed 's/^/      /' | while read -r l; do out "$l"; done
    # Wenn die Shell iwctl/iwd nutzt, das Backend aber wpa_supplicant ist -> GUI bleibt leer
    if grep -rqlE 'iwctl|net\.connman\.iwd' "$d" 2>/dev/null && [ "$BACKEND" != iwd ]; then
      bad "Shell spricht iwd an, NetworkManager nutzt aber Backend '$BACKEND' -> GUI-Liste bleibt leer"
      finding CRIT "Shell/Backend-Mismatch" "Backend und Shell-Modul auf dasselbe Backend bringen."
    fi
  fi
done
if have nmcli; then
  CNT=$(nmcli -t -f SSID device wifi list 2>/dev/null | grep -c . || true)
  if [ "${CNT:-0}" -gt 0 ]; then ok "nmcli sieht $CNT WLAN-Netze — die GUI muss dieselben sehen"
  else warn "nmcli sieht 0 WLAN-Netze (Scan leer) -> Ursache liegt unterhalb der GUI"; fi
fi

# ----------------------------------------------------- 11. Zusammenfassung ---
hdr "Zusammenfassung"
CRIT_N=0; WARN_N=0
for f in "${FINDINGS[@]:-}"; do
  [ -z "$f" ] && continue
  sev=${f%%|*}; rest=${f#*|}; title=${rest%%|*}; expl=${rest#*|}
  case "$sev" in
    CRIT) CRIT_N=$((CRIT_N+1)); out "  ${C_R}[kritisch]${C_0} $title"; out "             $expl" ;;
    WARN) WARN_N=$((WARN_N+1)); out "  ${C_Y}[warnung ]${C_0} $title"; out "             $expl" ;;
  esac
done
[ $((CRIT_N+WARN_N)) -eq 0 ] && ok "Keine bekannten Fehlerbilder gefunden."
out ""
out "  kritisch: $CRIT_N   warnungen: $WARN_N"

if [ "$FIX" -eq 0 ]; then
  out ""
  out "  ${C_B}Reparatur:${C_0} ./net-doctor.sh --fix   (legt vorher Backups unter /var/backups/net-doctor/ an)"
  exit $([ $CRIT_N -gt 0 ] && echo 1 || echo 0)
fi

# ============================================================ REPARATUR ======
hdr "Reparatur"

did() { FIXES_DONE+=("$1"); out "  ${C_G}fix${C_0}   $1"; }
skip(){ FIXES_SKIPPED+=("$1"); out "  ${C_D}skip${C_0}  $1"; }

# 1. NetworkManager installieren/starten
if [ "$NM_PRESENT" -eq 0 ]; then
  if confirm "NetworkManager installieren?"; then
    case "$PKG" in
      pacman) pkg_install networkmanager ;;
      apt)    pkg_install network-manager ;;
      *)      pkg_install NetworkManager ;;
    esac && did "NetworkManager installiert"
  else skip "NetworkManager-Installation"; fi
fi

# 2. rfkill entsperren
if [ "$RFKILL_BLOCKED" -eq 1 ] && have rfkill; then
  run_priv rfkill unblock all && did "rfkill: alle Soft-Blocks aufgehoben"
fi
if have nmcli && [ "$WIFI_RADIO" != enabled ] && [ -n "$WIFI_RADIO" ]; then
  nmcli radio wifi on 2>/dev/null && did "WLAN-Radio in NM eingeschaltet"
fi

# 3. Konkurrierende Dienste abschalten
for svc in "${CONFLICTS[@]:-}"; do
  [ -z "$svc" ] && continue
  if confirm "$svc stoppen und disablen (kollidiert mit NetworkManager)?"; then
    run_priv systemctl disable --now "$svc" >/dev/null 2>&1 && did "$svc gestoppt und disabled"
  else skip "$svc bleibt aktiv"; fi
done

# netplan auf NetworkManager umstellen
for f in "${NETPLAN_BAD[@]:-}"; do
  [ -z "$f" ] && continue
  if confirm "$f auf 'renderer: NetworkManager' umstellen?"; then
    backup_file "$f"
    run_priv sed -i 's/^\(\s*\)renderer:\s*networkd/\1renderer: NetworkManager/' "$f" && did "$f auf NetworkManager umgestellt"
    have netplan && run_priv netplan generate >/dev/null 2>&1
  else skip "$f unveraendert"; fi
done

# 4. unmanaged-Direktiven entfernen
for f in "${UNMANAGED_CONF[@]:-}"; do
  [ -z "$f" ] && continue
  if confirm "unmanaged-Direktiven in $f auskommentieren?"; then
    backup_file "$f"
    run_priv sed -i -E 's/^(\s*unmanaged-devices\s*=.*)$/#\1  # net-doctor/; s/^(\s*managed\s*=\s*false.*)$/managed=true  # net-doctor (war: \1)/' "$f" \
      && did "unmanaged-Direktiven in $f neutralisiert"
  else skip "$f unveraendert"; fi
done
if have nmcli; then
  for dev in "${UNMANAGED_DEVS[@]:-}"; do
    [ -z "$dev" ] && continue
    run_priv nmcli device set "$dev" managed yes 2>/dev/null && did "Geraet $dev auf managed gesetzt"
  done
fi

# 5. Backend-Mismatch aufloesen
if [ "$BACKEND_MISMATCH" = iwd ]; then
  if confirm "wifi.backend ist iwd. iwd aktivieren (sonst auf wpa_supplicant zuruecksetzen)?"; then
    run_priv systemctl enable --now iwd >/dev/null 2>&1 && did "iwd aktiviert"
    run_priv systemctl disable --now wpa_supplicant >/dev/null 2>&1 && did "wpa_supplicant abgeschaltet"
  else
    F=/etc/NetworkManager/conf.d/10-net-doctor-backend.conf
    backup_file "$F"
    printf '[device]\nwifi.backend=wpa_supplicant\n' | run_priv tee "$F" >/dev/null
    run_priv systemctl enable --now wpa_supplicant >/dev/null 2>&1
    did "Backend auf wpa_supplicant zurueckgesetzt ($F)"
  fi
elif [ "$BACKEND_MISMATCH" = wpa ]; then
  if confirm "iwd laeuft, obwohl Backend wpa_supplicant ist. iwd abschalten?"; then
    run_priv systemctl disable --now iwd >/dev/null 2>&1 && did "iwd abgeschaltet"
    run_priv systemctl enable --now wpa_supplicant >/dev/null 2>&1 && did "wpa_supplicant aktiviert"
  else skip "iwd bleibt aktiv"; fi
fi

# 6. Rechte der gespeicherten Verbindungen
for f in "${BADPERM[@]:-}"; do
  [ -z "$f" ] && continue
  run_priv chown root:root "$f" && run_priv chmod 600 "$f" && did "Rechte korrigiert: $f"
done

# 7. Firmware nachinstallieren
if [ "$FW_MISSING" -eq 1 ] || [ "$NO_DRIVER" -eq 1 ]; then
  if confirm "linux-firmware (Treiber-Firmware) installieren/aktualisieren?"; then
    case "$PKG" in
      pacman) pkg_install linux-firmware ;;
      apt)    pkg_install linux-firmware ;;
      dnf)    pkg_install linux-firmware ;;
      zypper) pkg_install kernel-firmware ;;
    esac && did "Firmware-Paket installiert (Reboot noetig, damit der Treiber sie laedt)"
  else skip "Firmware-Installation"; fi
fi

# 8. Polkit-Agent + Regel  -- der GUI-Fix
if [ -z "$POLKIT_AGENT" ]; then
  AGENT_PKG=""; AGENT_BIN=""
  case "$PKG" in
    pacman) AGENT_PKG="hyprpolkitagent"; AGENT_BIN="/usr/lib/hyprpolkitagent" ;;
    apt)    AGENT_PKG="policykit-1-gnome"; AGENT_BIN="/usr/libexec/polkit-gnome-authentication-agent-1" ;;
    dnf)    AGENT_PKG="polkit-gnome"; AGENT_BIN="/usr/libexec/polkit-gnome-authentication-agent-1" ;;
    zypper) AGENT_PKG="polkit-gnome"; AGENT_BIN="/usr/libexec/polkit-gnome-authentication-agent-1" ;;
  esac
  if [ -n "$AGENT_PKG" ] && confirm "Polkit-Agent '$AGENT_PKG' installieren und autostarten?"; then
    pkg_install "$AGENT_PKG" && did "$AGENT_PKG installiert"
    # systemd-User-Unit, damit der Agent in jeder Session mitstartet
    mkdir -p "$HOME/.config/systemd/user"
    REAL_BIN=""
    for cand in "$AGENT_BIN" \
        "$(command -v hyprpolkitagent 2>/dev/null)" \
        /usr/lib/hyprpolkitagent \
        /usr/libexec/polkit-gnome-authentication-agent-1 \
        /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 \
        /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
        /usr/lib/x86_64-linux-gnu/polkit-gnome/polkit-gnome-authentication-agent-1 \
        /usr/lib/polkit-kde-authentication-agent-1 \
        /usr/bin/lxqt-policykit-agent; do
      [ -n "$cand" ] && [ -x "$cand" ] && REAL_BIN="$cand" && break
    done
    # letzter Versuch: im Dateisystem suchen
    if [ -z "$REAL_BIN" ]; then
      REAL_BIN=$(find /usr/lib /usr/libexec -maxdepth 3 -name '*polkit*authentication-agent*' -type f -perm -u+x 2>/dev/null | head -1)
    fi
    if [ -n "$REAL_BIN" ] && [ -e "$REAL_BIN" ]; then
      cat >"$HOME/.config/systemd/user/polkit-agent.service" <<UNIT
[Unit]
Description=Polkit Authentication Agent (net-doctor)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=$REAL_BIN
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
UNIT
      systemctl --user daemon-reload >/dev/null 2>&1
      systemctl --user enable --now polkit-agent.service >/dev/null 2>&1 \
        && did "Polkit-Agent als User-Service aktiviert (~/.config/systemd/user/polkit-agent.service)"
      out "        Falls die Shell ohne graphical-session.target startet, zusaetzlich in die"
      out "        Compositor-Autostart-Zeile aufnehmen, z.B. Hyprland: exec-once = $REAL_BIN"
    else
      warn "Agent-Binary nicht gefunden — bitte manuell autostarten"
    fi
  else skip "Polkit-Agent"; fi
fi

# Polkit-Regel: lokale aktive Nutzer duerfen Netzwerk schalten, ohne Passwortdialog
if confirm "Polkit-Regel schreiben, damit lokale aktive Nutzer Netzwerke ohne Passwort schalten duerfen?"; then
  # polkit 0.105 (alte Debian/Ubuntu-Staende) kann kein JS -> .pkla, alles neuere -> rules.d
  if [ -d /etc/polkit-1/rules.d ] && [ "$POLKIT_VER" != "0.105" ]; then
    RULE=/etc/polkit-1/rules.d/49-net-doctor-nm.rules
    backup_file "$RULE"
    run_priv tee "$RULE" >/dev/null <<'RULE_EOF'
// net-doctor: lokale, aktive Sitzungen duerfen Netzwerkverbindungen schalten.
// Bewusst NUR Netzwerk-Actions, kein Passwort-Bypass fuer irgendetwas anderes.
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 &&
        subject.local && subject.active && subject.isInGroup("@NETGROUP@")) {
        return polkit.Result.YES;
    }
});
RULE_EOF
    # Gruppe waehlen: bevorzugt eine, in der der Benutzer schon ist; sonst eine, die es gibt.
    NETGROUP=""
    MYGROUPS=$(id -nG "$(id -un)" | tr ' ' '\n')
    for g in netdev wheel sudo; do
      getent group "$g" >/dev/null 2>&1 || continue
      if printf '%s\n' "$MYGROUPS" | grep -qx "$g"; then NETGROUP="$g"; break; fi
    done
    if [ -z "$NETGROUP" ]; then
      for g in netdev wheel sudo; do
        getent group "$g" >/dev/null 2>&1 && NETGROUP="$g" && break
      done
    fi
    [ -z "$NETGROUP" ] && NETGROUP=netdev && run_priv groupadd -f netdev >/dev/null 2>&1
    run_priv sed -i "s/@NETGROUP@/$NETGROUP/" "$RULE"
    did "Polkit-Regel $RULE geschrieben (Gruppe: $NETGROUP)"
    id -nG "$(id -un)" | tr ' ' '\n' | grep -qx "$NETGROUP" || {
      warn "Du bist nicht in Gruppe '$NETGROUP'"
      if confirm "Benutzer $(id -un) der Gruppe $NETGROUP hinzufuegen?"; then
        run_priv gpasswd -a "$(id -un)" "$NETGROUP" >/dev/null 2>&1 && did "Benutzer zu $NETGROUP hinzugefuegt (neu anmelden noetig)"
      fi; }
  else
    PKLA=/etc/polkit-1/localauthority/50-local.d/49-net-doctor-nm.pkla
    run_priv mkdir -p "$(dirname "$PKLA")"
    backup_file "$PKLA"
    run_priv tee "$PKLA" >/dev/null <<'PKLA_EOF'
[net-doctor: NetworkManager fuer lokale Nutzer]
Identity=unix-group:sudo;unix-group:netdev;unix-group:wheel
Action=org.freedesktop.NetworkManager.*
ResultAny=no
ResultInactive=no
ResultActive=yes
PKLA_EOF
    did "Polkit-Regel $PKLA geschrieben (alte polkit-Syntax)"
  fi
  run_priv systemctl restart polkit >/dev/null 2>&1 && did "polkit neu gestartet"
else skip "Polkit-Regel"; fi

# 9. DNS reparieren
if [ -L /etc/resolv.conf ] && [ ! -e "$(readlink -f /etc/resolv.conf)" ]; then
  if confirm "/etc/resolv.conf (toter Symlink) reparieren?"; then
    backup_file /etc/resolv.conf
    if [ "$RESOLVED_ACTIVE" = active ] && [ -e /run/systemd/resolve/stub-resolv.conf ]; then
      run_priv ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf && did "resolv.conf -> systemd-resolved"
    else
      run_priv rm -f /etc/resolv.conf
      printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' | run_priv tee /etc/resolv.conf >/dev/null
      did "resolv.conf mit Fallback-Nameservern neu geschrieben (NM ueberschreibt das beim naechsten Connect)"
    fi
  else skip "resolv.conf"; fi
fi

# 10. NetworkManager aktivieren und neu starten
run_priv systemctl enable NetworkManager >/dev/null 2>&1 && did "NetworkManager enabled"
if confirm "NetworkManager jetzt neu starten (kurzer Verbindungsabbruch)?"; then
  run_priv systemctl restart NetworkManager && did "NetworkManager neu gestartet"
  sleep 3
else skip "Neustart von NetworkManager"; fi

# ----------------------------------------------------------- Verifikation ---
hdr "Verifikation"
if have nmcli; then
  out "$(nmcli -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null | sed 's/^/    /')"
  nmcli device wifi rescan >/dev/null 2>&1; sleep 2
  CNT=$(nmcli -t -f SSID device wifi list 2>/dev/null | grep -c . || true)
  if [ "${CNT:-0}" -gt 0 ]; then ok "$CNT WLAN-Netze sichtbar — die GUI sollte sie jetzt ebenfalls listen"
  else warn "immer noch 0 Netze — siehe Firmware/Treiber oben, evtl. Reboot noetig"; fi
  if busctl --system introspect org.freedesktop.NetworkManager /org/freedesktop/NetworkManager >/dev/null 2>&1; then
    ok "D-Bus-Zugriff als $(id -un) funktioniert"
  else bad "D-Bus-Zugriff weiterhin blockiert"; fi
fi

hdr "Ergebnis"
out "  Durchgefuehrt: ${#FIXES_DONE[@]}   Uebersprungen: ${#FIXES_SKIPPED[@]}"
[ -d "$BACKUP_DIR" ] && out "  Backups unter: $BACKUP_DIR"
out ""
out "  Danach einmal abmelden/neu anmelden (oder Celestia Shell neu starten),"
out "  damit Gruppen, Polkit-Agent und D-Bus-Session frisch greifen."
