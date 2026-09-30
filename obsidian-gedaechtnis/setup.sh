#!/usr/bin/env bash
# Macht einen Obsidian-Vault zur Wissensbasis und zum Gedächtnis von Claude Code.
#
#   bash setup.sh                 # Vault automatisch finden
#   bash setup.sh /pfad/zum/vault # Vault direkt angeben
#
# Mehrfach ausführbar: vorhandene Notizen bleiben unangetastet, der
# Claude-Abschnitt in ~/.claude/CLAUDE.md wird ersetzt statt verdoppelt.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
LINK="$CLAUDE_DIR/obsidian"
MD="$CLAUDE_DIR/CLAUDE.md"
SETTINGS="$CLAUDE_DIR/settings.json"
TODAY="$(date +%F)"

command -v python3 >/dev/null || { echo "python3 fehlt (sudo pacman -S python)"; exit 1; }

ask() { local a; read -r -p "$1" a </dev/tty; printf '%s' "$a"; }

# --- Vault bestimmen --------------------------------------------------------
VAULT="${1:-}"
if [ -z "$VAULT" ]; then
  mapfile -t FOUND < <(
    for f in "$HOME/.config/obsidian/obsidian.json" \
             "$HOME/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"; do
      [ -f "$f" ] || continue
      python3 - "$f" <<'PY'
import json, os, sys
for v in json.load(open(sys.argv[1])).get("vaults", {}).values():
    if os.path.isdir(v.get("path", "")):
        print(v["path"])
PY
    done | sort -u
  )
  case ${#FOUND[@]} in
    0) VAULT="$(ask 'Kein Vault gefunden. Pfad zum Vault: ')" ;;
    1) VAULT="${FOUND[0]}"; echo "Vault gefunden: $VAULT" ;;
    *) echo "Mehrere Vaults gefunden:"
       for i in "${!FOUND[@]}"; do echo "  $((i + 1))) ${FOUND[$i]}"; done
       n="$(ask 'Welcher soll Claudes Gedächtnis sein? Nummer: ')"
       [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#FOUND[@]} )) || { echo "Ungültige Auswahl."; exit 1; }
       VAULT="${FOUND[$((n - 1))]}" ;;
  esac
fi
VAULT="${VAULT/#\~/$HOME}"
[ -d "$VAULT" ] || { echo "Ordner nicht gefunden: $VAULT"; exit 1; }
VAULT="$(realpath "$VAULT")"
[ -d "$VAULT/.obsidian" ] || { echo "$VAULT ist kein Obsidian-Vault (.obsidian fehlt)."; exit 1; }

# --- Claude-Bereich im Vault ------------------------------------------------
BASE="$VAULT/Claude"
mkdir -p "$BASE/Erinnerungen" "$BASE/Sessions" "$BASE/Projekte" "$CLAUDE_DIR"
echo "Notizen in $BASE:"

new() {
  if [ -e "$1" ]; then echo "  bleibt: ${1#"$BASE"/}"; return; fi
  cat >"$1"
  echo "  neu:    ${1#"$BASE"/}"
}

new "$BASE/Profil.md" <<EOF
---
tags: [claude, profil]
erstellt: $TODAY
---
# Profil

Was Claude in jeder Session über mich wissen soll. Wird bei jedem Start geladen – kurz halten.

## Allgemein
- Sprache: Deutsch

## System
- PC: CachyOS (Arch-basiert), Claude Code lokal und per Remote Control

## Projekte
- [[BatzenOS]] – iOS-App (SwiftUI) für Finanzen und Flipping, Build über Codemagic

## Vorlieben
EOF

new "$BASE/Erinnerungen.md" <<EOF
---
tags: [claude, gedaechtnis]
erstellt: $TODAY
---
# Erinnerungen

Kurzfakten, die Claude sich merkt – eine Zeile pro Fakt, mit Datum.
Wird bei jedem Start geladen. Größere Themen stehen als eigene Notiz im Ordner Erinnerungen und werden hier verlinkt.

## Entscheidungen

## System & Setup
- $TODAY: Obsidian-Vault als Claude-Gedächtnis eingerichtet ($VAULT)

## Gelöste Probleme

## Offen
EOF

new "$BASE/Projekte/BatzenOS.md" <<EOF
---
tags: [claude, projekt]
erstellt: $TODAY
---
# BatzenOS

Die smarte Finanz- und Flipping-App mit integrierter GPT-Assistenz.

- Repo: github.com/Indica-cool/BatzenOS
- SwiftUI, Views: Dashboard, Budget, Tasks, Wishlist, FlipAssistant, ChatGPT, Speech
- Build: Codemagic (codemagic.yaml) → .ipa

## Stand

## Offen
EOF

# --- Link ohne Leerzeichen für die @-Imports --------------------------------
if [ -L "$LINK" ] || [ ! -e "$LINK" ]; then
  ln -sfn "$VAULT" "$LINK"
else
  echo "$LINK existiert und ist kein Link – bitte umbenennen und erneut starten."; exit 1
fi

# --- Anweisungen in ~/.claude/CLAUDE.md -------------------------------------
[ -f "$MD" ] && cp "$MD" "$MD.bak-$(date +%s)"
python3 - "$MD" "$VAULT" <<'PY'
import os, sys
path, vault = sys.argv[1:]
start, end = "<!-- obsidian-gedaechtnis:start -->", "<!-- obsidian-gedaechtnis:end -->"
block = f"""{start}
# Gedächtnis: mein Obsidian-Vault

Mein Obsidian-Vault ist deine Wissensbasis und dein Langzeitgedächtnis.
- Vault: {vault}
- Dein Bereich: {vault}/Claude/ (Profil.md, Erinnerungen.md, Erinnerungen/, Projekte/, Sessions/)

@~/.claude/obsidian/Claude/Profil.md
@~/.claude/obsidian/Claude/Erinnerungen.md

## Lesen
- Profil und Erinnerungen oben sind bereits geladen.
- Bevor du ein Thema angehst, durchsuche den ganzen Vault danach, auch meine eigenen Notizen außerhalb von Claude/. Nutze, was du findest, und nenne die Notiz, aus der es stammt.
- Ist Obsidian offen und der Befehl obsidian vorhanden, nutze die Obsidian-CLI (Skill obsidian-cli) für Suche, Backlinks, Tags und Daily Notes; sonst Grep über *.md.

## Obsidian-Skills
- Für Notizen den Skill obsidian-markdown nutzen (Properties, Wikilinks, Callouts, Embeds), für .base-Dateien obsidian-bases, für .canvas-Dateien json-canvas.
- Webseiten für den Vault mit dem Skill defuddle als sauberes Markdown holen.

## Schreiben
- Merke dir von dir aus, was künftigen Sessions hilft: Vorlieben, Entscheidungen, Details zu meinem System, gelöste Probleme mit Lösung, Projektstände. Sage ich „merk dir …“, speichere sofort.
- Kurzfakt: eine Zeile mit Datum unter der passenden Überschrift in Claude/Erinnerungen.md.
- Größeres Thema: eigene Notiz Claude/Erinnerungen/<Thema>.md, in Erinnerungen.md als [[<Thema>]] verlinken.
- Projekte: Claude/Projekte/<Projekt>.md mit Stand, Entscheidungen, offenen Punkten.
- Nach einer Session mit echtem Ergebnis: Claude/Sessions/JJJJ-MM-TT <Titel>.md mit Ziel, Ergebnis, wichtigen Befehlen und Lösungen, offenen Punkten.
- Veraltetes korrigieren statt doppelt anlegen. Profil.md und Erinnerungen.md kurz halten (je unter 150 Zeilen), Details in Unternotizen.
- Format: Markdown mit YAML-Frontmatter (tags, erstellt, aktualisiert) und Obsidian-Wikilinks [[...]].
- Meine eigenen Notizen außerhalb von Claude/ nur ändern, wenn ich es sage.
- Niemals Passwörter, API-Keys, Tokens oder private Schlüssel speichern.
{end}"""
text = open(path).read() if os.path.exists(path) else ""
if start in text and end in text:
    a, b = text.index(start), text.index(end) + len(end)
    text = text[:a] + block + text[b:]
else:
    text = (text.rstrip() + "\n\n" if text.strip() else "") + block + "\n"
open(path, "w").write(text)
PY

# --- Zugriff ohne Rückfragen in ~/.claude/settings.json ---------------------
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak-$(date +%s)"
python3 - "$SETTINGS" "$VAULT" <<'PY'
import json, os, sys
path, vault = sys.argv[1:]
raw = open(path).read() if os.path.exists(path) else ""
s = json.loads(raw) if raw.strip() else {}
p = s.setdefault("permissions", {})
dirs = p.setdefault("additionalDirectories", [])
if vault not in dirs:
    dirs.append(vault)
allow = p.setdefault("allow", [])
for rule in (f"Read(/{vault}/**)", f"Edit(/{vault}/**)"):
    if rule not in allow:
        allow.append(rule)
with open(path, "w") as f:
    json.dump(s, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

# --- Obsidian-Skills von kepano (github.com/kepano/obsidian-skills) ---------
if command -v claude >/dev/null; then
  echo "Installiere Obsidian-Skills …"
  claude plugin marketplace add kepano/obsidian-skills >/dev/null 2>&1 || true
  if claude plugin install -s user obsidian@obsidian-skills >/dev/null 2>&1; then
    echo "  Plugin obsidian@obsidian-skills installiert"
  else
    echo "  Installation fehlgeschlagen – in Claude: /plugin install obsidian@obsidian-skills"
  fi
else
  echo "claude nicht gefunden – Obsidian-Skills übersprungen."
fi

echo
echo "Fertig. Claude nutzt ab der nächsten lokalen Session $BASE als Gedächtnis."
echo "Laufende Sessions (auch 'claude remote-control') einmal neu starten."
