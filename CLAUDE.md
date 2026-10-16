# CONTRABEATZ Plugin Lab

Eigene Audio-Plugins für FL Studio, Ableton Live und Logic Pro.
Ziel: Werkzeuge, die den CONTRABEATZ-Sound schneller und unverwechselbarer machen.

## Über mich
Musikproduzent und Brand Designer, kein ausgebildeter C++-Entwickler.
Erkläre Entscheidungen kurz und verständlich. Hinterfrage meine Ideen,
wenn sie technisch riskant, klanglich fragwürdig oder unnötig komplex sind.
System: macOS

## Stack
- JUCE (aktuelle stabile Version), Build über CMake, kein Projucer
- C++17/20
- Formate: VST3 + AU (Pflicht), CLAP (optional), Standalone für Tests
- macOS: Universal Binary (arm64 + x86_64), Windows: x64

## Projektstruktur
- `Source/PluginProcessor.*` – DSP und Parameter
- `Source/PluginEditor.*` – UI
- `Source/DSP/` – eigene DSP-Klassen
- `Source/UI/` – eigene Komponenten und LookAndFeel
- `docs/SPEC.md` – Spezifikation des aktuellen Plugins (vor dem Coden lesen)

## Befehle
- Konfigurieren: `cmake -B build -DCMAKE_BUILD_TYPE=Release`
- Bauen: `cmake --build build --config Release`
- Validieren: `pluginval --strictness-level 5 --validate <Pfad zum .vst3>`
- AU prüfen (macOS): `auval -a`, dann `auval -v aumu Cb86 Cntb` (Instrument)
- Render-Test (Presets, NaN, Pegel, Blockgrößen, WAVs):
  `cmake -B build -DCONTRA86_TOOLS=ON && cmake --build build --target CONTRA86_Render`,
  dann `./build/CONTRA86_Render_artefacts/Release/CONTRA86_Render renders`
- CI: `.github/workflows/build.yml` baut macOS Universal, prüft auval + pluginval

## Arbeitsweise
1. Vor neuem Feature: `docs/SPEC.md` prüfen. Fehlt Zweck, Signalfluss oder
   Parameterdefinition (Name, Bereich, Default, Skalierung), erst nachfragen.
2. MVP zuerst. Auf Feature-Creep hinweisen.
3. Kleine Schritte: Nach jeder Änderung bauen. Jeder Schritt muss kompilieren.
4. Nach jedem Schritt sagen, was ich hören oder sehen sollte.
5. Bei Fehlern: Build-Output selbst lesen, Ursache nennen, dann fixen.
6. Keine Platzhalter, kein auskommentierter Altcode.

## Audio-Regeln (nicht verhandelbar)
- processBlock ist echtzeitsicher: keine Allokation, keine Locks, kein I/O, kein Logging
- Parameter über AudioProcessorValueTreeState, immer mit Smoothing
- Alle Sample-Rates (44.1–192 kHz) und Buffer-Größen, auch 1 und wechselnde
- Latenz über setLatencySamples melden
- Oversampling bei Nichtlinearitäten
- State und Presets müssen in allen drei DAWs korrekt laden
- Mono und Stereo sauber unterstützen
- CPU-Last im Blick behalten, bei teuren Algorithmen Alternativen nennen

## UI
Klar, reduziert, funktional, im Stil der CONTRABEATZ-Marke.
Skalierbar (HiDPI), Doppelklick = Default, Feinjustierung per Modifier.
UI-Konzept beschreiben, bevor es umgesetzt wird.

## Definition of Done (pro Meilenstein)
- Build ohne Warnungen
- pluginval Level 5 bestanden, auval bestanden (macOS)
- Manuell getestet in FL Studio, Ableton, Logic: laden, automatisieren,
  speichern, neu öffnen, exportieren

## Release (später)
Code-Signing und Notarisierung (macOS), Installer, Versionierung,
Preset-Ordner, kurze Nutzer-Doku. JUCE-Lizenz vor Verkauf prüfen.

## Antwortstil
Direkt, ohne Füllsätze. Bei Entscheidungen: Optionen mit klarer Empfehlung.
Nach größeren Schritten: drei konkrete nächste Schritte.
