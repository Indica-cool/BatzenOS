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

---

# net-autoconnect — WLAN + VPN automatisch beim Hochfahren

Zweites Skript, für die Dauerlösung: Der Rechner verbindet sich nach dem Booten
von selbst mit WLAN und VPN, und die typischen Aussetzer werden abgestellt.

```bash
./net-autoconnect.sh --list      # welche Profile gibt es?
./net-autoconnect.sh             # erkennt WLAN + VPN automatisch, richtet ein
./net-autoconnect.sh --wifi "Heimnetz" --vpn "MeinVPN"
./net-autoconnect.sh --ethernet  # VPN auch am LAN-Kabel automatisch
./net-autoconnect.sh --status    # was ist gerade eingerichtet?
./net-autoconnect.sh --undo      # alles zurücknehmen
```

Ohne Argumente nimmt es das aktive WLAN und — falls es nur eines gibt — das
vorhandene VPN-Profil. Bei mehreren fragt es nach, statt zu raten.

## Was es einstellt und warum

**Damit das WLAN beim Booten kommt:**

- `connection.autoconnect=yes` und Priorität 100 — dein Netz wird zuerst probiert.
- `connection.autoconnect-retries=0` — unbegrenzt weiterprobieren. Der Standard
  ist 4: Wenn der Router beim Kaltstart langsamer hoch ist als der Laptop, gibt
  NetworkManager auf und bleibt offline. Genau das Muster „nach dem Hochfahren
  kein Netz, manuell klappt es sofort".
- `connection.permissions=""` — systemweite statt benutzergebundener Verbindung.
  Steht dort `user:name`, startet das WLAN frühestens nach dem Login, nie beim Boot.
- Feste statt zufälliger MAC-Adresse — Zufalls-MACs zerschießen
  DHCP-Reservierungen, MAC-Filter und Captive Portals.

**Damit das VPN mitkommt:**

- Klassische VPN-Plugins (OpenVPN, WireGuard via Plugin, IPsec, Fortinet …)
  werden als `connection.secondaries` an die WLAN-Verbindung gehängt.
  NetworkManager startet sie damit automatisch, sobald das Netz steht — in der
  richtigen Reihenfolge, ohne Timer-Gebastel.
- `vpn.persistent=yes` — nach einem Abbruch baut sich das VPN selbst wieder auf.
- **Secret-Flags auf 0.** Das ist der eigentliche Knackpunkt: Liegt das
  VPN-Passwort im Benutzer-Keyring (Flag 1, „agent-owned"), kann beim Hochfahren
  niemand danach fragen — es gibt noch keine Sitzung. Das VPN startet dann nie
  automatisch. Das Skript stellt die Flags um; danach musst du das Passwort
  **einmalig** neu hinterlegen:
  ```bash
  sudo nmcli connection up "MeinVPN" --ask
  ```
  oder in der GUI „für alle Benutzer speichern" ankreuzen.
- Reine WireGuard-Verbindungen (NM-Typ `wireguard`) brauchen das alles nicht —
  sie sind eigene Geräte mit Schlüssel in der Verbindung. Dort genügt
  `autoconnect=yes` mit Priorität 50, und das Skript erkennt den Unterschied.

**Damit es nicht wiederkommt:**

- `wifi.powersave=2` — Stromsparmodus der WLAN-Karte aus. Häufigste Ursache für
  Abbrüche im Leerlauf und für „verbunden, aber nichts geht mehr".
- `wifi.scan-rand-mac-address=no` global.
- Konkurrierende Manager (`systemd-networkd`, `dhcpcd`, `connman`, `netctl`)
  werden auf Nachfrage nicht nur abgeschaltet, sondern **maskiert** — so holt
  sie kein Paket-Update versehentlich zurück.
- `NetworkManager.service` wird enabled.

Alles landet in `/etc/NetworkManager/conf.d/20-net-autoconnect.conf`, sauber
kommentiert und mit `--undo` restlos entfernbar.

## Reihenfolge

```bash
./net-doctor.sh --fix        # erst reparieren (Polkit, Treiber, Backend)
./net-autoconnect.sh         # dann automatisieren
sudo reboot                  # und einmal wirklich testen
nmcli connection show --active
```

## Was das Skript nicht kann

Einen Kernel-Treiber herbeizaubern, den es für deinen Chip nicht gibt, und ein
VPN einrichten, das noch gar nicht als Profil existiert. Das VPN legst du einmal
in der GUI an — danach übernimmt das Skript.
