#!/usr/bin/env bash
# net-autoconnect.sh — Rechner verbindet sich nach dem Hochfahren selbst
# mit WLAN und VPN, und die typischen Aussetzer werden dauerhaft abgestellt.
#
#   ./net-autoconnect.sh --list           vorhandene Verbindungen anzeigen
#   ./net-autoconnect.sh                  automatisch erkennen und einrichten
#   ./net-autoconnect.sh --wifi "SSID" --vpn "MeinVPN"
#   ./net-autoconnect.sh --status         zeigt, was aktuell eingerichtet ist
#   ./net-autoconnect.sh --undo           alle Aenderungen zuruecknehmen
#
# Optionen:
#   --no-harden     nur Autoconnect, keine Stabilitaets-Einstellungen
#   --ethernet      LAN-Verbindungen ebenfalls mit dem VPN koppeln
#   --yes           keine Rueckfragen
#
# Backups aller angefassten Dateien: /var/backups/net-doctor/<zeitstempel>/

set -uo pipefail

WIFI=""; VPN=""; MODE="setup"; HARDEN=1; DO_ETH=0; ASSUME_YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --wifi) WIFI="${2:-}"; shift ;;
    --vpn)  VPN="${2:-}"; shift ;;
    --list) MODE="list" ;;
    --status) MODE="status" ;;
    --undo) MODE="undo" ;;
    --no-harden) HARDEN=0 ;;
    --ethernet) DO_ETH=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ -t 1 ]; then
  C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_B=$'\e[34m'; C_D=$'\e[2m'; C_0=$'\e[0m'
else C_R=""; C_G=""; C_Y=""; C_B=""; C_D=""; C_0=""; fi

hdr(){ printf '\n%s== %s ==%s\n' "$C_B" "$*" "$C_0"; }
ok(){  printf '  %sok%s    %s\n' "$C_G" "$C_0" "$*"; }
warn(){ printf '  %swarn%s  %s\n' "$C_Y" "$C_0" "$*"; }
bad(){ printf '  %sFEHL%s  %s\n' "$C_R" "$C_0" "$*"; }
info(){ printf '  %sinfo%s  %s\n' "$C_D" "$C_0" "$*"; }
step(){ printf '  %sfix%s   %s\n' "$C_G" "$C_0" "$*"; }

command -v nmcli >/dev/null 2>&1 || { bad "nmcli fehlt — NetworkManager ist nicht installiert."; exit 1; }

SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
run_priv(){ if [ -n "$SUDO" ]; then $SUDO "$@"; else "$@"; fi; }

confirm(){ [ "$ASSUME_YES" -eq 1 ] && return 0
  local a; printf '  -> %s [j/N] ' "$1" >&2; read -r a </dev/tty 2>/dev/null || return 1
  case "$a" in j|J|y|Y|ja|Ja) return 0;; *) return 1;; esac; }

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/var/backups/net-doctor/$STAMP"
backup_file(){ [ -e "$1" ] || return 0
  run_priv mkdir -p "$BACKUP_DIR$(dirname "$1")" 2>/dev/null
  run_priv cp -a "$1" "$BACKUP_DIR$1" 2>/dev/null && info "Backup: $1"; }

HARDEN_CONF=/etc/NetworkManager/conf.d/20-net-autoconnect.conf

# --------------------------------------------------------------- Helfer -----
# Feldwert einer Verbindung holen
cget(){ nmcli -g "$2" connection show "$1" 2>/dev/null; }
# Alle Verbindungen eines Typs: gibt "name<TAB>uuid" aus
list_type(){ nmcli -t -f NAME,UUID,TYPE connection show 2>/dev/null \
  | awk -F: -v t="$1" '$3==t {print $1"\t"$2}'; }

cmod(){ # cmod <conn> <prop> <wert>   — still, meldet nur Fehler
  local out; out=$(run_priv nmcli connection modify "$1" "$2" "$3" 2>&1) \
    || { bad "nmcli connection modify $1 $2 -> $out"; return 1; }
  return 0; }

# ----------------------------------------------------------------- LIST -----
if [ "$MODE" = list ]; then
  hdr "Vorhandene Verbindungen"
  nmcli -f NAME,TYPE,DEVICE,AUTOCONNECT connection show
  echo
  info "WLAN-Namen oben aus Spalte NAME nehmen, dann z.B.:"
  info "  ./net-autoconnect.sh --wifi \"MeinWLAN\" --vpn \"MeinVPN\""
  exit 0
fi

# ----------------------------------------------------------------- UNDO -----
if [ "$MODE" = undo ]; then
  hdr "Zuruecknehmen"
  if [ -e "$HARDEN_CONF" ]; then
    backup_file "$HARDEN_CONF"; run_priv rm -f "$HARDEN_CONF" && step "$HARDEN_CONF entfernt"
  else info "keine Hardening-Datei vorhanden"; fi
  while IFS=$'\t' read -r name uuid; do
    [ -z "$name" ] && continue
    sec=$(cget "$name" connection.secondaries)
    if [ -n "$sec" ]; then
      cmod "$name" connection.secondaries "" && step "VPN-Kopplung von '$name' entfernt"
    fi
  done < <(nmcli -t -f NAME,UUID,TYPE connection show 2>/dev/null \
           | awk -F: '$3=="802-11-wireless"||$3=="802-3-ethernet"{print $1"\t"$2}')
  run_priv systemctl reload NetworkManager 2>/dev/null || run_priv systemctl restart NetworkManager
  step "NetworkManager neu geladen"
  echo; info "Autoconnect-Flags der einzelnen Verbindungen wurden bewusst NICHT"
  info "zurueckgesetzt — die willst du in aller Regel behalten."
  exit 0
fi

# --------------------------------------------------- Verbindungen finden ----
hdr "Verbindungen erkennen"

if [ -z "$WIFI" ]; then
  WIFI=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null \
         | awk -F: '$2=="802-11-wireless"{print $1; exit}')
  [ -n "$WIFI" ] && info "aktives WLAN erkannt: $WIFI"
fi
if [ -z "$WIFI" ]; then
  mapfile -t WIFIS < <(list_type 802-11-wireless)
  if [ "${#WIFIS[@]}" -eq 1 ]; then
    WIFI="${WIFIS[0]%%$'\t'*}"; info "einziges WLAN-Profil: $WIFI"
  elif [ "${#WIFIS[@]}" -eq 0 ]; then
    bad "Kein WLAN-Profil vorhanden. Einmal ueber die GUI verbinden, dann dieses Skript erneut."
    exit 1
  else
    bad "Mehrere WLAN-Profile gefunden — bitte eines waehlen:"
    printf '        %s\n' "${WIFIS[@]%%$'\t'*}"
    info "  ./net-autoconnect.sh --wifi \"<Name>\""
    exit 1
  fi
fi
nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$WIFI" \
  || { bad "WLAN-Profil '$WIFI' existiert nicht (--list zeigt alle)."; exit 1; }
ok "WLAN: $WIFI"

VPN_TYPE=""
if [ -z "$VPN" ]; then
  mapfile -t VPNS < <(list_type vpn; list_type wireguard)
  if [ "${#VPNS[@]}" -eq 1 ]; then
    VPN="${VPNS[0]%%$'\t'*}"; info "einziges VPN-Profil erkannt: $VPN"
  elif [ "${#VPNS[@]}" -gt 1 ]; then
    warn "Mehrere VPN-Profile vorhanden — bitte eines angeben mit --vpn \"<Name>\":"
    printf '        %s\n' "${VPNS[@]%%$'\t'*}"
  else
    warn "Kein VPN-Profil vorhanden — es wird nur das WLAN eingerichtet."
    warn "VPN zuerst einmalig in der GUI anlegen, dann dieses Skript erneut laufen lassen."
  fi
fi
if [ -n "$VPN" ]; then
  nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$VPN" \
    || { bad "VPN-Profil '$VPN' existiert nicht (--list zeigt alle)."; exit 1; }
  VPN_TYPE=$(cget "$VPN" connection.type)
  VPN_UUID=$(cget "$VPN" connection.uuid)
  ok "VPN: $VPN (Typ: $VPN_TYPE)"
fi

# --------------------------------------------------------------- STATUS -----
if [ "$MODE" = status ]; then
  hdr "Aktueller Zustand"
  printf '  %-28s %s\n' "WLAN autoconnect:"  "$(cget "$WIFI" connection.autoconnect)"
  printf '  %-28s %s\n' "WLAN Prioritaet:"   "$(cget "$WIFI" connection.autoconnect-priority)"
  printf '  %-28s %s\n' "WLAN Wiederholungen:" "$(cget "$WIFI" connection.autoconnect-retries)"
  printf '  %-28s %s\n' "WLAN Berechtigungen:" "$(cget "$WIFI" connection.permissions)"
  printf '  %-28s %s\n' "gekoppeltes VPN:"   "$(cget "$WIFI" connection.secondaries)"
  if [ -n "$VPN" ]; then
    printf '  %-28s %s\n' "VPN Typ:"          "$VPN_TYPE"
    printf '  %-28s %s\n' "VPN UUID:"         "$(cget "$VPN" connection.uuid)"
    printf '  %-28s %s\n' "VPN Berechtigungen:" "$(cget "$VPN" connection.permissions)"
    [ "$VPN_TYPE" = vpn ] && printf '  %-28s %s\n' "VPN persistent:" "$(cget "$VPN" vpn.persistent)"
    [ "$VPN_TYPE" = vpn ] && printf '  %-28s %s\n' "VPN Secret-Flags:" "$(cget "$VPN" vpn.data | tr ',' '\n' | grep -- '-flags' | tr '\n' ' ')"
  fi
  [ -e "$HARDEN_CONF" ] && { echo; info "$HARDEN_CONF:"; sed 's/^/      /' "$HARDEN_CONF"; } \
                        || { echo; info "keine Hardening-Datei aktiv"; }
  exit 0
fi

# ================================================================ SETUP ======
hdr "1. WLAN: automatisch verbinden"

cmod "$WIFI" connection.autoconnect yes            && step "autoconnect eingeschaltet"
cmod "$WIFI" connection.autoconnect-priority 100   && step "Prioritaet 100 (dieses Netz zuerst)"
# 0 = unbegrenzt weiterprobieren. Default 4 -> nach 4 Fehlversuchen gibt NM auf,
# genau das erzeugt "nach dem Booten ist kein Netz da, manuell klappt es sofort".
cmod "$WIFI" connection.autoconnect-retries 0      && step "unbegrenzte Verbindungsversuche"
# Leere Permissions = Systemverbindung. Steht hier "user:name", startet die
# Verbindung erst NACH dem Login und nie beim Hochfahren.
PERM=$(cget "$WIFI" connection.permissions)
if [ -n "$PERM" ]; then
  if confirm "WLAN ist an Benutzer '$PERM' gebunden und startet daher erst nach dem Login. Systemweit machen?"; then
    cmod "$WIFI" connection.permissions "" && step "WLAN auf systemweit umgestellt"
  else warn "bleibt benutzergebunden — Autoconnect beim Boot wird nicht funktionieren"; fi
else ok "WLAN ist bereits systemweit"; fi

if [ "$HARDEN" -eq 1 ]; then
  # Zufaellige MAC bricht DHCP-Reservierungen, Captive Portals und manche Router.
  cmod "$WIFI" 802-11-wireless.cloned-mac-address permanent && step "feste MAC-Adresse (keine Zufalls-MAC)"
fi

# ------------------------------------------------------------- Ethernet -----
ETH_CONNS=()
while IFS=$'\t' read -r n u; do [ -n "$n" ] && ETH_CONNS+=("$n"); done < <(list_type 802-3-ethernet)
if [ "${#ETH_CONNS[@]}" -gt 0 ]; then
  hdr "2. LAN"
  for e in "${ETH_CONNS[@]}"; do
    cmod "$e" connection.autoconnect yes && step "'$e': autoconnect ein"
    cmod "$e" connection.autoconnect-retries 0
    p=$(cget "$e" connection.permissions)
    [ -n "$p" ] && cmod "$e" connection.permissions "" && step "'$e': systemweit"
  done
fi

# ------------------------------------------------------------------ VPN -----
if [ -n "$VPN" ]; then
  hdr "3. VPN: automatisch nach dem Netz starten"

  VPERM=$(cget "$VPN" connection.permissions)
  if [ -n "$VPERM" ]; then
    cmod "$VPN" connection.permissions "" && step "VPN auf systemweit umgestellt"
  fi

  if [ "$VPN_TYPE" = wireguard ]; then
    # WireGuard ist in NM ein eigenes Geraet, kein VPN-Plugin:
    # kein secondaries noetig, eigenes autoconnect genuegt.
    cmod "$VPN" connection.autoconnect yes          && step "WireGuard: autoconnect ein"
    cmod "$VPN" connection.autoconnect-priority 50  && step "WireGuard: Prioritaet 50 (nach dem WLAN)"
    cmod "$VPN" connection.autoconnect-retries 0
    ok "WireGuard startet beim Hochfahren selbst — Schluessel liegen in der Verbindung, kein Keyring noetig."
  else
    # Klassisches VPN-Plugin: NM startet es als "secondary" der Netzverbindung.
    VPN_UUID=$(cget "$VPN" connection.uuid)
    attach_vpn(){ # attach_vpn <basis-verbindung>
      local base="$1" cur
      cur=$(cget "$base" connection.secondaries)
      case ",$cur," in
        *",$VPN_UUID,"*) ok "'$base': VPN bereits gekoppelt"; return 0 ;;
      esac
      if [ -z "$cur" ]; then cmod "$base" connection.secondaries "$VPN_UUID"
      else cmod "$base" connection.secondaries "$cur,$VPN_UUID"; fi \
        && step "'$base': VPN wird nach dem Verbinden automatisch gestartet"
    }
    attach_vpn "$WIFI"
    if [ "$DO_ETH" -eq 1 ]; then
      for e in "${ETH_CONNS[@]:-}"; do [ -n "$e" ] && attach_vpn "$e"; done
    elif [ "${#ETH_CONNS[@]}" -gt 0 ]; then
      info "LAN nicht gekoppelt — mit --ethernet auch am Kabel automatisch ins VPN"
    fi

    # VPN nicht zusaetzlich selbst autoconnecten lassen: sonst zwei parallele Starts.
    cmod "$VPN" connection.autoconnect no
    # Bei Abbruch neu aufbauen statt einfach offline bleiben.
    cmod "$VPN" vpn.persistent yes && step "VPN baut sich nach Abbruch selbst wieder auf"

    # Passwoerter muessen SYSTEMWEIT gespeichert sein. Liegen sie im
    # Benutzer-Keyring (flag 1 = agent-owned), kann beim Hochfahren niemand
    # danach fragen und das VPN startet nicht.
    FLAGS=$(cget "$VPN" vpn.data | tr ',' '\n' | sed 's/^ *//' | grep -- '-flags *=' || true)
    NEED_PW=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      key="${line%%=*}"; key="${key// /}"
      val="${line##*=}"; val="${val// /}"
      if [ "$val" != 0 ]; then
        run_priv nmcli connection modify "$VPN" +vpn.data "$key=0" >/dev/null 2>&1 \
          && step "Secret '$key' von Keyring auf systemweit umgestellt" && NEED_PW=1
      fi
    done <<<"$FLAGS"
    if [ "$NEED_PW" -eq 1 ]; then
      warn "Das VPN-Passwort muss einmalig neu hinterlegt werden, damit es systemweit liegt:"
      warn "  sudo nmcli connection up \"$VPN\" --ask"
      warn "oder in der GUI die VPN-Verbindung oeffnen, Passwort eintragen und"
      warn "\"fuer alle Benutzer speichern\" waehlen."
    else
      ok "VPN-Zugangsdaten liegen bereits systemweit"
    fi
  fi
fi

# ------------------------------------------------------------- Hardening ----
if [ "$HARDEN" -eq 1 ]; then
  hdr "4. Stabilitaet dauerhaft absichern"
  backup_file "$HARDEN_CONF"
  run_priv mkdir -p "$(dirname "$HARDEN_CONF")" 2>/dev/null
  run_priv tee "$HARDEN_CONF" >/dev/null <<'CONF_EOF'
# net-autoconnect: Einstellungen gegen die haeufigsten WLAN-Aussetzer.
# Entfernen mit: ./net-autoconnect.sh --undo

[connection]
# Stromsparmodus der WLAN-Karte aus (2 = disable).
# Der Sparmodus ist die haeufigste Ursache fuer Abbruechen im Leerlauf
# und fuer "verbunden, aber nichts geht mehr".
wifi.powersave=2
# 0 = unbegrenzt weiterprobieren statt nach 4 Versuchen aufzugeben.
connection.autoconnect-retries=0

[device]
# Keine zufaellige MAC beim Scannen: bricht sonst DHCP-Reservierungen,
# Captive Portals und MAC-Filter im Router.
wifi.scan-rand-mac-address=no
CONF_EOF
  if [ -s "$HARDEN_CONF" ]; then step "$HARDEN_CONF geschrieben"
  else bad "$HARDEN_CONF konnte nicht geschrieben werden (Rechte? Pfad?)"; fi

  # Konkurrierende Manager dauerhaft ruhigstellen — das war der Ausgangsfehler.
  for svc in systemd-networkd dhcpcd connman netctl; do
    st=$(systemctl is-enabled "$svc" 2>/dev/null || true)
    if [ "$st" = enabled ] || [ "$(systemctl is-active "$svc" 2>/dev/null)" = active ]; then
      if confirm "$svc dauerhaft abschalten (maskieren)? Er streitet sich mit NetworkManager."; then
        run_priv systemctl disable --now "$svc" >/dev/null 2>&1
        run_priv systemctl mask "$svc" >/dev/null 2>&1 && step "$svc maskiert — kann nicht versehentlich wiederkommen"
      fi
    fi
  done
  run_priv systemctl enable NetworkManager >/dev/null 2>&1 && step "NetworkManager startet beim Hochfahren"
fi

# ---------------------------------------------------------------- Anwenden --
hdr "5. Anwenden"
run_priv systemctl reload NetworkManager 2>/dev/null \
  || run_priv systemctl restart NetworkManager 2>/dev/null
step "NetworkManager neu geladen"

hdr "Ergebnis"
printf '  %-28s %s\n' "WLAN autoconnect:"  "$(cget "$WIFI" connection.autoconnect)"
printf '  %-28s %s\n' "WLAN Prioritaet:"   "$(cget "$WIFI" connection.autoconnect-priority)"
printf '  %-28s %s\n' "gekoppeltes VPN:"   "$(cget "$WIFI" connection.secondaries)"
[ -n "$VPN" ] && printf '  %-28s %s\n' "VPN Typ:" "$VPN_TYPE"
[ -d "$BACKUP_DIR" ] && printf '  %-28s %s\n' "Backups:" "$BACKUP_DIR"
echo
info "Echter Test: einmal neu starten. Danach sollten WLAN und VPN ohne Zutun stehen."
info "Pruefen mit:  nmcli connection show --active"
