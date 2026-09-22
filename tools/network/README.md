# net-doctor — Netzwerk/NetworkManager reparieren (Celestia Shell GUI)

Werkzeug für den Fall: **WLAN/LAN lässt sich über die GUI der Celestia Shell
nicht mehr verbinden**, obwohl die Hardware da ist.

> Hinweis: Dieses Verzeichnis gehört technisch nicht zur BatzenOS-App (die ist
> eine iOS-/SwiftUI-App). Das Skript liegt hier nur, damit du es bequem aus dem
> Repo auf deinen Linux-Rechner holen kannst.

## Benutzung

Auf **deinem Rechner** (nicht in der Cloud-Session) ausführen:

```bash
git clone https://github.com/indica-cool/batzenos.git
cd batzenos/tools/network

./net-doctor.sh                 # nur analysieren, ändert nichts
./net-doctor.sh --report /tmp/netz.txt   # Analyse zusätzlich in Datei
./net-doctor.sh --fix           # reparieren, fragt bei jedem Eingriff nach
./net-doctor.sh --fix --yes     # reparieren ohne Rückfragen
```

Alle geänderten Konfigurationsdateien werden vorher nach
`/var/backups/net-doctor/<zeitstempel>/` gesichert.

## Was geprüft und repariert wird

| # | Prüfung | Typisches Symptom |
|---|---|---|
| 1 | Läuft `NetworkManager.service`, startet er automatisch? | gar kein Netz |
| 2 | Konkurrenz: `systemd-networkd`, `dhcpcd`, `connman`, `netctl`, netplan `renderer: networkd` | Gerät wird `unmanaged`, Verbindung flappt |
| 3 | `rfkill` Soft-/Hard-Block, `nmcli radio wifi` | WLAN-Liste bleibt leer |
| 4 | Kernel-Treiber geladen? Firmware-Fehler im `dmesg`? | Gerät taucht nirgends auf |
| 5 | Gerätestatus `unmanaged` / `unavailable` | GUI zeigt Adapter nicht an |
| 6 | `unmanaged-devices=`, `managed=false`, `wifi.backend` (iwd ↔ wpa_supplicant), Dateirechte unter `system-connections/` | gespeicherte WLANs verschwinden |
| 7 | DNS: toter `resolv.conf`-Symlink, `dns=`-Modus vs. `systemd-resolved` | „verbunden, aber kein Internet" |
| 8 | **Polkit**: läuft ein Authentifizierungs-Agent, darf dein Benutzer NM-Aktionen ausführen? | **als root/`nmcli` geht alles, in der GUI passiert nichts** |
| 9 | D-Bus-Zugriff auf `org.freedesktop.NetworkManager` als Benutzer | GUI-Widget bleibt leer/grau |
| 10 | Quickshell/Celestia-Prozess, Netzwerkmodul, Backend-Mismatch (Shell spricht `iwd`, NM nutzt `wpa_supplicant`) | GUI-Liste leer trotz funktionierendem `nmcli` |

## Der wichtigste Punkt: Polkit

Wenn `nmcli` als root funktioniert, die GUI aber nichts verbindet, liegt es fast
immer an einem von zwei Dingen:

1. **Kein Polkit-Agent in der Wayland-Session.** Niemand zeigt den
   Passwortdialog an, also schlägt die Autorisierung still fehl. Das Skript
   installiert einen passenden Agent und legt ihn als systemd-User-Service an.
   Bei Hyprland zusätzlich in die Config:
   ```
   exec-once = /usr/lib/hyprpolkitagent
   ```
2. **Dein Benutzer darf die NM-Aktionen nicht.** Das Skript schreibt eine
   Polkit-Regel nach `/etc/polkit-1/rules.d/49-net-doctor-nm.rules`, die lokalen,
   aktiven Sitzungen einer Admin-Gruppe (`netdev`/`wheel`/`sudo`) die
   `org.freedesktop.NetworkManager.*`-Aktionen erlaubt — bewusst nur diese, kein
   allgemeiner Passwort-Bypass. Auf polkit 0.105 wird stattdessen die alte
   `.pkla`-Syntax geschrieben.

Nach dem Fix einmal **ab- und wieder anmelden**, damit Gruppenmitgliedschaft,
Polkit-Agent und D-Bus-Session frisch greifen.

## Rückgängig machen

```bash
sudo cp -a /var/backups/net-doctor/<zeitstempel>/etc/. /etc/
sudo rm -f /etc/polkit-1/rules.d/49-net-doctor-nm.rules
systemctl --user disable --now polkit-agent.service
sudo systemctl restart polkit NetworkManager
```
