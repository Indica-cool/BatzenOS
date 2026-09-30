#!/usr/bin/env bash
# Macht einen Obsidian-Vault (Zweites Gehirn) zur Wissensbasis und zum Gedächtnis von Claude Code.
#
#   bash setup.sh                 # Vault automatisch finden
#   bash setup.sh /pfad/zum/vault # Vault direkt angeben
#
# Mehrfach ausführbar: der Abschnitt in ~/.claude/CLAUDE.md wird ersetzt statt
# verdoppelt. Notizen im Vault legt das Skript nicht an – das macht das Onboarding.
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
MD="$CLAUDE_DIR/CLAUDE.md"
SETTINGS="$CLAUDE_DIR/settings.json"

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

# --- Anweisungen in ~/.claude/CLAUDE.md -------------------------------------
mkdir -p "$CLAUDE_DIR"
[ -f "$MD" ] && cp "$MD" "$MD.bak-$(date +%s)"
python3 - "$MD" "$VAULT" <<'PY'
import os, sys
path, vault = sys.argv[1:]
start, end = "<!-- obsidian-gedaechtnis:start -->", "<!-- obsidian-gedaechtnis:end -->"
block = f"""{start}
# Mein Zweites Gehirn (Obsidian)

Mein Obsidian-Vault ist deine Wissensbasis und dein Langzeitgedächtnis, in jeder Session und egal in welchem Ordner.
Vault: {vault}

- Struktur und Regeln des Vaults stehen in {vault}/CLAUDE.md. Arbeitest du außerhalb des Vaults, lies diese Datei, bevor du dort suchst oder speicherst. Ist sie noch die Setup-Anleitung („Zweites Gehirn Setup Guide“), starte das Setup nur, wenn ich im Vault-Ordner arbeite oder es verlange.
- Mein Profil steht in {vault}/00 Kontext/ (Über mich, ICP, Angebot, Schreibstil, Branding). Lies die passende Datei, wenn eine Aufgabe mich, meine Texte oder meine Projekte betrifft.
- Bevor du ein Thema angehst, durchsuche den Vault danach und nenne die Notiz, aus der etwas stammt. Ist Obsidian offen und der Befehl obsidian vorhanden, nutze die Obsidian-CLI (Skill obsidian-cli), sonst Grep über *.md.
- Sage ich „merk dir das“ oder „speicher das“, speichere es nach den Regeln der Vault-CLAUDE.md dort, wo es thematisch hingehört. Merke dir auch von dir aus, was künftigen Sessions hilft: Entscheidungen und Projektstände in die Datei unter 02 Projekte/, technische Erkenntnisse und gelöste Probleme samt Lösung nach 04 Ressourcen/.
- Nach einer Session mit echtem Ergebnis: Eintrag in 05 Daily Notes/JJJJ-MM-TT.md anlegen oder ergänzen, mit Ergebnis, wichtigen Befehlen und offenen Punkten.
- Niemals Passwörter, API-Keys, Tokens oder private Schlüssel im Vault speichern. Vor dem Löschen oder Überschreiben fragen.

## Obsidian-Skills
- Global installiert als Plugin obsidian@obsidian-skills (kepano). Nicht zusätzlich nach .claude/skills/ kopieren.
- Notizen: obsidian-markdown. .base-Dateien: obsidian-bases. .canvas-Dateien: json-canvas. Webseiten als Markdown: defuddle.
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
if [ -f "$VAULT/CLAUDE.md" ]; then
  echo "Fertig. Vault-Regeln: $VAULT/CLAUDE.md"
else
  echo "Fertig. Jetzt die Setup-Anleitung (CLAUDE.md) in den Vault legen:"
  echo "  $VAULT/CLAUDE.md"
  echo "und im Vault 'claude' starten – dann beginnt das Onboarding."
fi
echo "Laufende Sessions (auch 'claude remote-control') einmal neu starten."
