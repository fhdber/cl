# CONTRA-86 – Spezifikation (v0.3)

Arbeitstitel. Polyphoner Retro-Synth mit Juno-60/106-Kern, erweitert um das,
was 80s/90s-Produktionen fertig klingen lässt: Unison, zweite Hüllkurve,
Delay und Reverb. Ziel: Pads, Leads, Plucks, Bässe, Keys und FX in Sekunden,
direkt aus einer kategorisierten Preset-Library.

## Zweck
Ein Instrument, das 80s/90s-Sounds sofort liefert, ohne Menütiefe.
Eine Seite, klare Blöcke. Der Juno-Kern bleibt das Herz, die Erweiterungen
sind bewusst klein gehalten (je 2–4 Regler).

## Meilensteine
- **v0.1 (MVP, erledigt):** Juno-Kern, Chorus, 5 Presets, generisches UI
- **v0.2 (dieser):** ENV 2, Unison/Stereo, Delay, Reverb, ~40 Presets in
  Kategorien, Preset-Browser im Plugin
- **v0.2 UI:** eigenes CONTRABEATZ-UI (Konzept unten)
- **v0.3 (dieser):** CHARACTER – Drive, Tube, Voice-Cards (Drift), Phaser
- **später (Etappe B):** Ensemble-Chorus, Lo-Fi Digital, Tape

## Formate & Eckdaten
- Instrument (AU `aumu`), VST3, Standalone. Hersteller-Code `Cntb`, Plugin-Code `Cb86`
- Ausgang Stereo oder Mono, kein Audio-Eingang, MIDI-In
- 8 Stimmen, Voice-Stealing: ältester losgelassener Ton, sonst ältester Ton (3 ms Fade)
- Pitchbend ±2 Halbtöne, Modwheel = Vibrato (bis ±0,5 HT zusätzlich)
- Sustain-Pedal (CC64), All Notes Off (CC123), All Sound Off (CC120), Reset Controllers (CC121)
- Interne Rate: 2× Oversampling (IIR-Polyphase), Latenz wird gemeldet
- Delay folgt dem Host-Tempo (Fallback 120 BPM)

## Signalfluss
```
            ┌──────────────── pro Stimme (2× Rate) ─────────────────┐
MIDI ─► DCO │ Unison 1/3/5/7 × (Saw + Pulse) + Sub + Noise ─► Mixer L/R │
            │      ─► Drive ─► 24-dB-Ladder-LPF (tanh, L/R) ─► VCA     │
            └───────────────────────────┬──────────────────────────────┘
                                         Σ  (stereo)
                                         ▼
                             Tube (asymmetrisch, noch auf 2× Rate)
                                         ▼
                             Downsampling (2× → 1×)
                                         ▼
                             HPF (6 dB) ─► Chorus ─► Phaser ─► Delay (Ping-Pong)
                                         ▼
                             Reverb ─► Volume ─► Out (L/R oder Mono)

Modulation: ENV 1 ─► Filter, PWM (Quelle Env), VCA (Mode Env 1)
            ENV 2 ─► VCA (Mode Env 2, Default)
            Gate  ─► VCA (Mode Gate)
            LFO (Dreieck, global, mit Delay) ─► Pitch, Filter, PWM
            Drift (Voice-Card je Stimme + Wandern) ─► Pitch, Filter, Hüllkurven-Tempo, Pegel
```
Ohne Unison-Breite läuft die Stimme mono (ein Filter), mit Breite stereo
(zwei Filter, gemeinsamer Koeffizient).

## Parameter

Skalierung: *lin* = linear, *log* = logarithmisch (Skew um den Mittelpunkt),
*%* = 0–100 % intern 0–1. IDs v1 bleiben unverändert, neue IDs tragen Version 2.

| Gruppe | ID | Name | Bereich | Default | Skalierung |
|---|---|---|---|---|---|
| DCO | `range` | Range | 16′ / 8′ / 4′ | 8′ | Auswahl |
| DCO | `pw` | Pulse Width | 0–100 % (50 %→5 % Duty) | 0 % | lin |
| DCO | `pwmSource` | PWM Source | LFO / Manual / Env | Manual | Auswahl |
| DCO | `sawLevel` | Saw | 0–100 % | 100 % | lin |
| DCO | `pulseLevel` | Pulse | 0–100 % | 0 % | lin |
| DCO | `subLevel` | Sub | 0–100 % | 0 % | lin |
| DCO | `noiseLevel` | Noise | 0–100 % | 0 % | lin |
| DCO | `lfoPitch` | LFO → Pitch | 0–100 % (bis ±12 HT; 15 % ≈ Vibrato) | 0 % | quadratisch |
| Unison | `unison` | Unison | Off / 3 / 5 / 7 | Off | Auswahl |
| Unison | `unisonDetune` | Detune | 0–100 % (bis ±50 Cent) | 30 % | lin |
| Unison | `unisonWidth` | Width | 0–100 % | 70 % | lin |
| VCF | `hpf` | HPF | 20–2000 Hz | 20 Hz | log |
| VCF | `cutoff` | Cutoff | 20–20000 Hz | 8000 Hz | log |
| VCF | `resonance` | Resonance | 0–100 % (Selbstoszillation ≈ 100 %) | 10 % | lin |
| VCF | `envAmount` | Env 1 → Filter | −100…+100 % (±8 Okt) | 0 % | lin |
| VCF | `lfoFilter` | LFO → Filter | 0–100 % (±4 Okt) | 0 % | lin |
| VCF | `keyTrack` | Key Track | 0–100 % | 50 % | lin |
| ENV 1 | `attack` | Env 1 Attack | 1 ms–5 s | 5 ms | log |
| ENV 1 | `decay` | Env 1 Decay | 1 ms–10 s | 400 ms | log |
| ENV 1 | `sustain` | Env 1 Sustain | 0–100 % | 80 % | lin |
| ENV 1 | `release` | Env 1 Release | 1 ms–10 s | 300 ms | log |
| ENV 2 | `ampAttack` | Env 2 Attack | 1 ms–5 s | 5 ms | log |
| ENV 2 | `ampDecay` | Env 2 Decay | 1 ms–10 s | 400 ms | log |
| ENV 2 | `ampSustain` | Env 2 Sustain | 0–100 % | 80 % | lin |
| ENV 2 | `ampRelease` | Env 2 Release | 1 ms–10 s | 300 ms | log |
| VCA | `vcaMode` | VCA Mode | Env 1 / Gate / Env 2 | Env 2 | Auswahl |
| LFO | `lfoRate` | LFO Rate | 0,1–30 Hz | 3 Hz | log |
| LFO | `lfoDelay` | LFO Delay | 0–5 s | 0 s | log |
| FX | `chorus` | Chorus | Off / I / II / I+II | I | Auswahl |
| FX | `delayTime` | Delay Time | 1/16, 1/8T, 1/8, 1/8., 1/4T, 1/4, 1/4., 1/2 | 1/8. | Auswahl |
| FX | `delayFeedback` | Delay Feedback | 0–90 % | 35 % | lin |
| FX | `delayMix` | Delay Level | 0–100 % (Send, Dry bleibt) | 0 % | lin |
| FX | `reverbSize` | Reverb Size | 0–100 % | 60 % | lin |
| FX | `reverbMix` | Reverb Level | 0–100 % (Send, Dry bleibt) | 0 % | lin |
| Voice | `voiceMode` | Voice Mode | Poly / Mono (Legato) | Poly | Auswahl |
| Voice | `glide` | Glide (nur Mono, legato) | 0–2 s | 0 s | log |
| Character | `drive` | Drive | 0–100 % (bis +16 dB vor dem Filter, pegelkompensiert) | 0 % | lin |
| Character | `tube` | Tube | 0–100 % | 0 % | lin |
| Character | `drift` | Drift | 0–100 % | 20 % | lin |
| FX | `phaser` | Phaser | Off / Slow / Fast | Off | Auswahl |
| FX | `phaserMix` | Phaser Depth | 0–100 % | 60 % | lin |
| Voice | `velocity` | Velocity | 0–100 % (→ VCA + Filter) | 50 % | lin |
| Out | `volume` | Volume | −48…+6 dB | −6 dB | lin (dB) |

Smoothing: alle kontinuierlichen Klangparameter pro Sample (20 ms, Cutoff/HPF
multiplikativ), Delay-Zeit 200 ms (Tape-artiges Gleiten beim Umschalten).
Hüllkurven-/LFO-Zeiten wirken auf Raten, dort entsteht kein Zipper. Auswahl-
Parameter springen; Chorus blendet (50 ms), Reverb glättet intern.

## Verhalten im Detail
- **Hüllkurven:** analog-typisch exponentiell (Attack mit Overshoot-Ziel 1,3).
  Zeiten = Zeit bis Zielwert bzw. bis −60 dB. Retrigger startet ab aktuellem Pegel.
- **VCA Mode:** Env 1 = Juno-Verhalten (eine Hüllkurve für alles), Env 2 =
  getrennte Lautstärke-Hüllkurve, Gate = Orgel/Stab (1 ms / 5 ms).
- **Unison:** ungerade Stimmenzahl, mittlere Stimme unverstimmt (trägt den Sub),
  übrige symmetrisch verstimmt und im Stereobild verteilt. Pegel ∝ 1/√n.
  CPU: 7er-Unison ≈ 4× Oszillator-Last; Filter bleiben 1–2 pro Stimme.
- **Delay:** Ping-Pong (erstes Echo links), Feedback mit Bandpass 120 Hz–4,5 kHz
  und Soft-Clip – wird mit jeder Wiederholung dunkler, kann nicht explodieren.
- **Reverb:** Freeverb-Algorithmus, Input mit 200-Hz-Hochpass gegen Mulm.
- **LFO Delay:** startet neu, wenn eine Taste gedrückt wird, während keine andere
  gehalten ist; Tiefe blendet über die Delay-Zeit ein.
- **Velocity:** bei 127 klingt der Patch exakt wie programmiert; leiser = leiser
  und bis zu 3 Okt dunkler.
- **Drift / Voice-Cards:** jede der 8 Stimmen hat eine feste „Persönlichkeit“
  (wie Bauteiltoleranzen auf Voice-Cards): Stimmung bis ±6 Cent, Cutoff bis ±0,2 Okt,
  Hüllkurven-Tempo bis ±15 %, Pegel bis ±0,8 dB. Dazu pro Note ±2 Cent und langsames
  Wandern bis ±3 Cent. Alles skaliert mit Drift; 0 % = perfekt sauber.
- **Drive:** weiche Sättigung des Mixers vor dem Filter (Moog/Juno-Mixer übersteuert),
  pegelkompensiert, auf 2× Rate.
- **Tube:** asymmetrische Kennlinie auf der Stereosumme (geradzahlige Obertöne),
  bei kleinen Pegeln Verstärkung 1, DC-Blocker danach, auf 2× Rate.
- **Phaser:** 6 Allpass-Stufen pro Kanal, Sweep 200 Hz – 3 kHz logarithmisch,
  Feedback 0,5, L/R um 90° versetzt. Slow 0,15 Hz, Fast 0,9 Hz. Depth 100 % =
  volle Kerben (Dry und Wet gleich laut).
- **Chorus:** zwei gegenphasig modulierte Delays (L/R), Wet bandbegrenzt (BBD-Charakter).
  I: 0,513 Hz, 1,66–5,35 ms · II: 0,863 Hz, 1,66–5,35 ms · I+II: 9,75 Hz, 3,3–3,7 ms.
- **Mono:** Notenstapel, letzte Note gewinnt, Legato ohne Retrigger, Rückfall auf
  gehaltene Note beim Loslassen.

## Preset-Library
Rund 40 Factory-Presets in den Kategorien **Pad, Lead, Pluck, Bass, Keys, FX**,
Referenz: 80s Synthpop, 90s House/Trance, Retrowave. Jedes Preset ist zugleich
Host-Programm (Name „Kategorie / Name“), damit es auch über das DAW-Menü läuft.

**Preset-Leiste (oben im Plugin):** Auswahlmenü mit Kategorie-Überschriften,
◀ ▶ zum Durchsteppen. Folgt auch Programmwechseln aus dem Host.
Siehe UI-Konzept.

## UI-Konzept (v0.2)
Referenzen: Teenage-Engineering/Braun-Hardware – helles Alu-Gehäuse, schwarzes
Glas-Display, ein einziger warmer Akzent.

- **Gehäuse:** schwarzer, stark gerundeter Rahmen, darin Alu-Panel (kühles Hellgrau,
  sanfter Verlauf). Feine dunkle Linien teilen das Panel in Sektionen wie bei Hardware.
- **Display (oben, schwarz, Glanzkante):** links Kategorie + Preset-Name in Orange
  (Klick = Preset-Menü, ◀ ▶ = blättern), rechts Oszilloskop des Ausgangs in Orange.
  Beim Drehen/Hovern zeigt das Display Parametername + Wert (1,5 s), danach wieder
  das Preset – das Display ist die einzige Stelle mit Zahlen, das Panel bleibt ruhig.
- **Knobs:** heller Knopf, schwarzer Ring, roter Punkt als Zeiger, dünner oranger
  Wertebogen. Ein Hero-Knob in Orange: Cutoff. Doppelklick = Default,
  Shift/Cmd beim Ziehen = Feinjustierung (×0,15), Mausrad wird unterstützt.
- **Umschalter:** Segment-Pillen (aktives Segment schwarz mit orangem LED-Punkt)
  für Range, PWM, Unison, VCA, Chorus, Voice Mode.
- **Raster:** Reihe 1 OSC · UNISON · Reihe 2 FILTER · LFO · VOICE ·
  Reihe 3 ENV 1 · ENV 2 · SPACE (Delay, Reverb) · Reihe 4 CHARACTER · MOD FX
  (Chorus, Phaser). Fußzeile: Wortmarke „CONTRA-86“, Lautsprecher-
  Punktraster, Volume-Knob.
- **Typo:** Michroma (OFL) für Wortmarke, Sektionen, Labels und Display.
- **Skalierung:** feste Designfläche 1040 × 990, frei skalierbar 50–150 % mit festem
  Seitenverhältnis, vektorbasiert (HiDPI scharf).

## Nicht in v0.2 (bewusst)
Arpeggiator, Modulationsmatrix, Effekt-Reihenfolge, eigene Presets speichern
(Host-Speicherung funktioniert), MPE.

## Abnahme v0.3
- Build ohne Warnungen (macOS Universal, Linux-CI-Check)
- pluginval Level 5 (VST3), auval (AU), Render-Test aller Presets
- State aus v0.1 lädt weiter (v1-IDs unverändert)
- Manuell in FL, Ableton, Logic: Presets durchsteppen, automatisieren, speichern/laden
