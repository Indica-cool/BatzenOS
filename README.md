# Stoff Plan

Privates, lokales Substanz-Tagebuch für Android — als Harm-Reduction-Tool.
Alle Daten bleiben auf dem Gerät; nichts wird in eine Cloud gesendet.

## Features

- Einträge mit Substanz, Dosis (mg/g/µg/…), Konsumform, Datum + Uhrzeit
- Wirkungsverlauf: Onset, Peak, Comedown + freie Wirkungsbeschreibung
- Mood-Skala (1–10) vor und nach Konsum
- Kontext: Ort, Begleitung, Notizen
- Manueller Export nach JSON oder CSV (via Share-Sheet)
- Komplett offline, keine Analytics, kein Tracking

## Tech

- Kotlin + Jetpack Compose (Material 3)
- Room (SQLite) für lokale Persistenz
- Navigation-Compose
- Min SDK 24 (Android 7.0+), Target SDK 34

## APK bauen

### Mit Codemagic

`codemagic.yaml` enthält einen `android-workflow`, der `assembleDebug` und
`assembleRelease` baut. Die `.apk`-Dateien landen unter
`app/build/outputs/apk/{debug,release}/`.

### Lokal

Voraussetzungen: JDK 17, Android SDK (cmdline-tools), Gradle 8.7+.

```bash
# Einmalig: Wrapper-Jar generieren
gradle wrapper --gradle-version 8.7

# Debug-APK bauen
./gradlew :app:assembleDebug

# Unsignierte Release-APK
./gradlew :app:assembleRelease
```

Die fertige APK liegt unter `app/build/outputs/apk/debug/app-debug.apk`
und kann per `adb install` oder Datei-Sideload aufs Handy.

## Harm Reduction

Tagebücher helfen Muster zu erkennen — Frequenz, Dosis-Drift, Stimmungs-Drops,
problematische Kombinationen. Wenn du Sorge hast oder Hilfe brauchst:

- DE: Sucht- und Drogenhotline 01806 313031
- AT: Drogenberatung checkit.wien
- CH: Safer Nightlife Schweiz
