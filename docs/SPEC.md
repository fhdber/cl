# CONTRA-86 – Spezifikation (MVP)

Arbeitstitel. Polyphoner Analog-Synth im Geist von Juno-60/106. Kein Clone,
sondern dieselbe Architektur mit CONTRABEATZ-Fokus: schnell zu Pads, Bass,
Brass/Leads und Plucks, mit Charakter ab Werk (Drift, Chorus, Filtersättigung).

## Zweck
Ein Instrument, das 80s/90s-Sounds in Sekunden liefert, ohne Menütiefe.
Eine Seite, ein Hüllkurvengenerator, ein LFO – die Beschränkung ist das Konzept.

## Formate & Eckdaten
- Instrument (AU `aumu`), VST3, Standalone. Hersteller-Code `Cntb`, Plugin-Code `Cb86`
- Ausgang Stereo oder Mono, kein Audio-Eingang, MIDI-In
- 8 Stimmen, Voice-Stealing: ältester losgelassener Ton, sonst ältester Ton (3 ms Fade)
- Pitchbend ±2 Halbtöne, Modwheel = Vibrato (bis ±0,5 HT zusätzlich)
- Sustain-Pedal (CC64), All Notes Off (CC123), All Sound Off (CC120), Reset Controllers (CC121)
- Interne Rate: 2× Oversampling (IIR-Polyphase), Latenz wird gemeldet

## Signalfluss
```
            ┌──────────── pro Stimme (2× Rate) ────────────┐
MIDI ─► DCO │ Saw + Pulse(PWM) + Sub(-1 Okt) + Noise ─► Mixer │
            │      ─► 24-dB-Ladder-LPF (tanh) ─► VCA         │
            └───────────────────────┬──────────────────────┘
                                     Σ  (mono, wie im Original)
                                     ▼
                         Downsampling (2× → 1×)
                                     ▼
                         HPF (6 dB, global)
                                     ▼
                         Chorus Off / I / II / I+II  (→ Stereo)
                                     ▼
                         Volume ─► Out (L/R oder Mono)

Modulation: ENV (ADSR) ─► Filter, VCA (Mode Env), PWM (Quelle Env)
            LFO (Dreieck, global, mit Delay) ─► Pitch, Filter, PWM
            Drift (pro Stimme, zufällig) ─► Pitch, Filter
```

## Parameter

Skalierung: *lin* = linear, *log* = logarithmisch (Skew um den Mittelpunkt),
*%* = 0–100 % intern 0–1.

| Gruppe | ID | Name | Bereich | Default | Skalierung |
|---|---|---|---|---|---|
| DCO | `range` | Range | 16′ / 8′ / 4′ | 8′ | Auswahl |
| DCO | `pw` | Pulse Width | 0–100 % (50 %→5 % Duty) | 0 % | lin |
| DCO | `pwmSource` | PWM Source | LFO / Manual / Env | Manual | Auswahl |
| DCO | `sawLevel` | Saw | 0–100 % | 100 % | lin |
| DCO | `pulseLevel` | Pulse | 0–100 % | 0 % | lin |
| DCO | `subLevel` | Sub | 0–100 % | 0 % | lin |
| DCO | `noiseLevel` | Noise | 0–100 % | 0 % | lin |
| DCO | `lfoPitch` | LFO → Pitch | 0–100 % (bis ±2 HT) | 0 % | quadratisch |
| VCF | `hpf` | HPF | 20–2000 Hz | 20 Hz | log |
| VCF | `cutoff` | Cutoff | 20–20000 Hz | 8000 Hz | log |
| VCF | `resonance` | Resonance | 0–100 % (Selbstoszillation ≈ 100 %) | 10 % | lin |
| VCF | `envAmount` | Env → Filter | −100…+100 % (±8 Okt) | 0 % | lin |
| VCF | `lfoFilter` | LFO → Filter | 0–100 % (±4 Okt) | 0 % | lin |
| VCF | `keyTrack` | Key Track | 0–100 % | 50 % | lin |
| ENV | `attack` | Attack | 1 ms–5 s | 5 ms | log |
| ENV | `decay` | Decay | 1 ms–10 s | 400 ms | log |
| ENV | `sustain` | Sustain | 0–100 % | 80 % | lin |
| ENV | `release` | Release | 1 ms–10 s | 300 ms | log |
| VCA | `vcaMode` | VCA Mode | Env / Gate | Env | Auswahl |
| LFO | `lfoRate` | LFO Rate | 0,1–30 Hz | 3 Hz | log |
| LFO | `lfoDelay` | LFO Delay | 0–5 s | 0 s | log |
| FX | `chorus` | Chorus | Off / I / II / I+II | I | Auswahl |
| Voice | `voiceMode` | Voice Mode | Poly / Mono (Legato) | Poly | Auswahl |
| Voice | `glide` | Glide (nur Mono, legato) | 0–2 s | 0 s | log |
| Voice | `drift` | Drift | 0–100 % | 20 % | lin |
| Voice | `velocity` | Velocity | 0–100 % (→ VCA + Filter) | 50 % | lin |
| Out | `volume` | Volume | −48…+6 dB | −6 dB | lin (dB) |

Smoothing: alle kontinuierlichen Klangparameter pro Sample (20 ms, Cutoff/HPF
multiplikativ). Hüllkurven- und LFO-Zeiten/Raten wirken auf Raten, nicht auf
Pegel – dort entsteht kein Zipper, deshalb kein Smoothing. Auswahl-Parameter
springen; der Chorus blendet beim Umschalten (50 ms).

## Verhalten im Detail
- **Hüllkurve:** analog-typisch exponentiell (Attack mit Overshoot-Ziel 1,3).
  Zeiten = Zeit bis Zielwert bzw. bis −60 dB. Retrigger startet ab aktuellem Pegel.
- **Gate-Mode:** VCA folgt der Taste (1 ms Attack, 5 ms Release); ENV wirkt dann
  nur noch auf Filter/PWM – der klassische Juno-Organ/Pluck-Trick.
- **LFO Delay:** startet neu, wenn eine Taste gedrückt wird, während keine andere
  gehalten ist; Tiefe blendet über die Delay-Zeit ein.
- **Velocity:** bei 127 klingt der Patch exakt wie programmiert; leiser = leiser
  und bis zu 3 Okt dunkler.
- **Drift:** pro Stimme fester Zufallsversatz (bis ±8 Cent) + langsame
  Zufallsbewegung (bis ±3 Cent) + Cutoff-Versatz (bis ±0,15 Okt).
- **Chorus:** zwei gegenphasige modulierte Delays (L/R), Wet bandbegrenzt (BBD-Charakter).
  I: 0,513 Hz, 1,66–5,35 ms · II: 0,863 Hz, 1,66–5,35 ms · I+II: 9,75 Hz, 3,3–3,7 ms.
- **Mono:** Notenstapel, letzte Note gewinnt, Legato ohne Retrigger, Rückfall auf
  gehaltene Note beim Loslassen.

## Factory-Presets (Host-Programme)
1. **Init** – Saw, offenes Filter
2. **Juno Pad** – Saw + PWM-LFO, langsamer Attack, Chorus I, leichter LFO auf Filter
3. **Saw Bass** – Mono, Saw + Sub, kurze Filter-Env, Chorus Off
4. **Brass Stab** – Saw, Env → Filter positiv, Attack ~40 ms, Chorus II
5. **House Pluck** – Pulse + Saw, Gate-Mode, kurze Filter-Env, Chorus I+II

## Nicht im MVP (bewusst)
Unison/Supersaw, Arpeggiator, zweite Hüllkurve, Effekte außer Chorus,
MPE, Preset-Browser, eigenes UI (folgt als nächster Meilenstein nach UI-Konzept).

## Abnahme MVP
- Build ohne Warnungen (macOS Universal, Linux-CI-Check)
- pluginval Level 5 (VST3), auval (AU)
- Alle 5 Presets klingen wie beschrieben, State lädt in FL, Ableton, Logic
