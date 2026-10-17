#include "Presets.h"
#include "Parameters.h"

namespace presets
{
namespace
{
    namespace id = params::id;

    // Auswahl-Indizes, damit die Tabelle lesbar bleibt
    constexpr float range4 = 2;
    constexpr float pwmLfo = 0;
    constexpr float vcaEnv1 = 0, vcaGate = 1;
    constexpr float chorusOff = 0, chorus1 = 1, chorus2 = 2, chorus12 = 3;
    constexpr float uni3 = 1, uni5 = 2, uni7 = 3;
    constexpr float d16 = 0, d8 = 2, d8d = 3, d4 = 5, d4d = 6;
    constexpr float mono = 1;
    constexpr float phaserSlow = 1, phaserFast = 2;

    struct Value { const char* id; float value; };

    struct Preset
    {
        const char* category;
        const char* name;
        std::initializer_list<Value> values;
    };

    // Werte in Parametereinheiten: % als 0..1, Zeiten in s, Frequenzen in Hz,
    // Auswahl-Parameter als Index. Nicht genannte Parameter stehen auf Default.
    const Preset factory[] =
    {
        { "Init", "Init", {} },

        // ── Pads ──────────────────────────────────────────────────────────
        { "Pad", "Juno Pad", { { id::pulseLevel, 0.7f }, { id::pw, 0.6f }, { id::pwmSource, pwmLfo },
            { id::lfoRate, 0.5f }, { id::lfoFilter, 0.06f },
            { id::cutoff, 2500 }, { id::resonance, 0.15f }, { id::envAmount, 0.1f },
            { id::attack, 0.9f }, { id::decay, 2.0f }, { id::sustain, 0.85f }, { id::release, 1.6f },
            { id::ampAttack, 0.9f }, { id::ampDecay, 2.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 1.6f },
            { id::drift, 0.3f }, { id::velocity, 0.3f }, { id::chorus, chorus1 },
            { id::reverbMix, 0.25f }, { id::reverbSize, 0.7f }, { id::tube, 0.15f }} },

        { "Pad", "Glass Pad", { { id::sawLevel, 0.5f }, { id::pulseLevel, 0.6f }, { id::pw, 0.3f },
            { id::hpf, 200 }, { id::cutoff, 5000 }, { id::resonance, 0.25f }, { id::envAmount, -0.15f },
            { id::attack, 0.01f }, { id::decay, 4.0f }, { id::sustain, 0.5f },
            { id::ampAttack, 0.6f }, { id::ampDecay, 3.0f }, { id::ampSustain, 0.8f }, { id::ampRelease, 2.5f },
            { id::chorus, chorus2 }, { id::delayMix, 0.2f }, { id::delayTime, d4d }, { id::delayFeedback, 0.4f },
            { id::reverbMix, 0.35f }, { id::reverbSize, 0.85f }, { id::velocity, 0.3f } } },

        { "Pad", "Dark Strings", { { id::pulseLevel, 0.4f }, { id::pw, 0.5f }, { id::pwmSource, pwmLfo },
            { id::lfoRate, 0.35f }, { id::lfoPitch, 0.08f }, { id::lfoDelay, 1.5f },
            { id::cutoff, 900 }, { id::resonance, 0.1f }, { id::keyTrack, 0.7f }, { id::envAmount, 0.15f },
            { id::attack, 1.2f }, { id::decay, 3.0f }, { id::sustain, 0.6f },
            { id::ampAttack, 1.0f }, { id::ampDecay, 2.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 2.0f },
            { id::chorus, chorus2 }, { id::reverbMix, 0.3f }, { id::reverbSize, 0.8f }, { id::velocity, 0.3f }, { id::volume, -2.0f }, { id::phaser, phaserSlow }, { id::phaserMix, 0.6f }} },

        { "Pad", "Supersaw Pad", { { id::unison, uni7 }, { id::unisonDetune, 0.45f }, { id::unisonWidth, 0.9f },
            { id::cutoff, 4000 }, { id::envAmount, 0.1f },
            { id::attack, 0.5f }, { id::decay, 3.0f }, { id::sustain, 0.7f },
            { id::ampAttack, 0.8f }, { id::ampDecay, 2.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 2.0f },
            { id::chorus, chorus1 }, { id::delayMix, 0.15f }, { id::delayTime, d4d },
            { id::reverbMix, 0.35f }, { id::reverbSize, 0.85f }, { id::velocity, 0.3f }, { id::volume, -8.0f }} },

        { "Pad", "Air Pad", { { id::sawLevel, 0.5f }, { id::pulseLevel, 0.3f }, { id::pw, 0.4f }, { id::pwmSource, pwmLfo },
            { id::noiseLevel, 0.35f }, { id::lfoRate, 0.2f }, { id::lfoFilter, 0.12f },
            { id::hpf, 300 }, { id::cutoff, 1800 }, { id::resonance, 0.45f },
            { id::ampAttack, 2.0f }, { id::ampDecay, 3.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 3.0f },
            { id::chorus, chorus2 }, { id::reverbMix, 0.45f }, { id::reverbSize, 0.95f }, { id::velocity, 0.2f }, { id::volume, -1.0f }} },

        { "Pad", "Sweep Pad", { { id::pulseLevel, 0.5f }, { id::pw, 0.5f }, { id::pwmSource, pwmLfo },
            { id::unison, uni3 }, { id::unisonDetune, 0.25f }, { id::unisonWidth, 0.8f },
            { id::lfoRate, 0.12f }, { id::lfoFilter, 0.35f }, { id::cutoff, 700 }, { id::resonance, 0.5f },
            { id::ampAttack, 0.7f }, { id::ampDecay, 2.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 2.0f },
            { id::chorus, chorus1 }, { id::delayMix, 0.15f }, { id::delayTime, d4 }, { id::delayFeedback, 0.45f },
            { id::reverbMix, 0.3f }, { id::velocity, 0.3f } } },

        { "Pad", "Warm Poly", { { id::sawLevel, 0.8f }, { id::subLevel, 0.4f },
            { id::cutoff, 1200 }, { id::envAmount, 0.2f },
            { id::attack, 0.3f }, { id::decay, 1.5f }, { id::sustain, 0.5f },
            { id::ampAttack, 0.3f }, { id::ampDecay, 1.0f }, { id::ampSustain, 0.85f }, { id::ampRelease, 1.2f },
            { id::chorus, chorus1 }, { id::reverbMix, 0.2f }, { id::drift, 0.35f } } },

        { "Pad", "Synthwave Pad", { { id::unison, uni5 }, { id::unisonDetune, 0.3f }, { id::unisonWidth, 0.8f },
            { id::pulseLevel, 0.6f }, { id::pw, 0.5f }, { id::pwmSource, pwmLfo }, { id::lfoRate, 0.4f },
            { id::cutoff, 1500 }, { id::resonance, 0.2f }, { id::lfoFilter, 0.05f },
            { id::ampAttack, 1.2f }, { id::ampDecay, 2.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 2.5f },
            { id::chorus, chorus2 }, { id::delayMix, 0.2f }, { id::delayTime, d4d }, { id::delayFeedback, 0.5f },
            { id::reverbMix, 0.4f }, { id::reverbSize, 0.9f }, { id::velocity, 0.3f } } },

        { "Pad", "Solina Strings", { { id::pulseLevel, 0.5f }, { id::pw, 0.5f }, { id::pwmSource, pwmLfo }, { id::lfoRate, 0.35f },
            { id::cutoff, 3500 }, { id::resonance, 0.05f },
            { id::ampAttack, 0.6f }, { id::ampDecay, 2.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 1.5f },
            { id::chorus, chorus2 }, { id::phaser, phaserSlow }, { id::phaserMix, 0.8f },
            { id::reverbMix, 0.3f }, { id::drift, 0.4f }, { id::velocity, 0.3f }, { id::volume, -2.0f } } },

        { "Pad", "Phase Pad", { { id::sawLevel, 0.6f }, { id::pulseLevel, 0.8f }, { id::pw, 0.5f }, { id::pwmSource, pwmLfo },
            { id::lfoRate, 0.3f }, { id::cutoff, 2200 }, { id::resonance, 0.3f },
            { id::ampAttack, 1.0f }, { id::ampDecay, 2.0f }, { id::ampSustain, 0.9f }, { id::ampRelease, 2.5f },
            { id::chorus, chorus1 }, { id::phaser, phaserSlow }, { id::phaserMix, 1.0f },
            { id::delayMix, 0.2f }, { id::delayTime, d4d }, { id::reverbMix, 0.45f }, { id::reverbSize, 0.9f },
            { id::velocity, 0.3f }, { id::volume, -6.0f } } },

        // ── Leads ─────────────────────────────────────────────────────────
        { "Lead", "Supersaw Lead", { { id::voiceMode, mono }, { id::glide, 0.06f },
            { id::unison, uni7 }, { id::unisonDetune, 0.35f }, { id::unisonWidth, 0.7f },
            { id::cutoff, 6000 }, { id::envAmount, 0.1f }, { id::decay, 0.8f }, { id::sustain, 0.7f },
            { id::ampDecay, 0.5f }, { id::ampSustain, 0.9f }, { id::ampRelease, 0.35f },
            { id::lfoRate, 5.5f }, { id::lfoPitch, 0.13f }, { id::lfoDelay, 0.5f },
            { id::chorus, chorusOff }, { id::delayMix, 0.25f }, { id::delayTime, d8d },
            { id::reverbMix, 0.2f }, { id::volume, -1.0f }} },

        { "Lead", "Retro Square", { { id::voiceMode, mono }, { id::glide, 0.03f },
            { id::sawLevel, 0.0f }, { id::pulseLevel, 1.0f }, { id::subLevel, 0.3f },
            { id::cutoff, 3000 }, { id::resonance, 0.2f }, { id::envAmount, 0.2f }, { id::decay, 0.4f }, { id::sustain, 0.4f },
            { id::ampDecay, 0.3f }, { id::ampSustain, 0.9f }, { id::ampRelease, 0.2f },
            { id::lfoRate, 5.0f }, { id::lfoPitch, 0.14f }, { id::lfoDelay, 0.4f },
            { id::chorus, chorus1 }, { id::delayMix, 0.2f }, { id::delayTime, d8d }, { id::reverbMix, 0.15f } } },

        { "Lead", "Hook Lead", { { id::pulseLevel, 0.5f }, { id::pw, 0.4f }, { id::pwmSource, pwmLfo }, { id::lfoRate, 4.0f },
            { id::unison, uni3 }, { id::unisonDetune, 0.15f }, { id::unisonWidth, 0.6f },
            { id::cutoff, 2500 }, { id::resonance, 0.25f }, { id::envAmount, 0.3f }, { id::decay, 0.5f }, { id::sustain, 0.4f },
            { id::ampSustain, 0.9f }, { id::ampRelease, 0.3f },
            { id::chorus, chorus2 }, { id::delayMix, 0.3f }, { id::delayTime, d4d }, { id::delayFeedback, 0.45f },
            { id::reverbMix, 0.2f }, { id::volume, -1.0f }} },

        { "Lead", "Acid Lead", { { id::voiceMode, mono }, { id::glide, 0.08f },
            { id::cutoff, 500 }, { id::resonance, 0.75f }, { id::envAmount, 0.6f }, { id::keyTrack, 0.6f },
            { id::decay, 0.25f }, { id::sustain, 0.1f },
            { id::ampSustain, 0.9f }, { id::ampRelease, 0.1f },
            { id::chorus, chorusOff }, { id::delayMix, 0.2f }, { id::delayTime, d8d }, { id::delayFeedback, 0.4f },
            { id::drift, 0.1f }, { id::volume, -1.0f }} },

        { "Lead", "Hoover", { { id::voiceMode, mono }, { id::glide, 0.12f },
            { id::unison, uni7 }, { id::unisonDetune, 0.7f }, { id::unisonWidth, 0.8f },
            { id::sawLevel, 0.6f }, { id::pulseLevel, 0.8f }, { id::pw, 0.7f }, { id::pwmSource, pwmLfo }, { id::lfoRate, 6.0f },
            { id::cutoff, 3500 }, { id::resonance, 0.15f },
            { id::ampSustain, 1.0f }, { id::ampRelease, 0.3f },
            { id::chorus, chorus12 }, { id::reverbMix, 0.25f }, { id::reverbSize, 0.7f }, { id::volume, -2.0f }, { id::drive, 0.3f }} },

        { "Lead", "Soft Lead", { { id::voiceMode, mono }, { id::glide, 0.05f },
            { id::sawLevel, 0.0f }, { id::pulseLevel, 0.8f }, { id::pw, 0.1f }, { id::subLevel, 0.2f },
            { id::cutoff, 900 }, { id::resonance, 0.05f }, { id::keyTrack, 1.0f },
            { id::ampAttack, 0.03f }, { id::ampSustain, 0.9f }, { id::ampRelease, 0.4f },
            { id::lfoRate, 5.2f }, { id::lfoPitch, 0.14f }, { id::lfoDelay, 0.6f },
            { id::chorus, chorus1 }, { id::delayMix, 0.25f }, { id::delayTime, d4 }, { id::delayFeedback, 0.3f },
            { id::reverbMix, 0.25f }, { id::volume, -3.0f }} },

        { "Lead", "Brass Lead", { { id::unison, uni3 }, { id::unisonDetune, 0.12f }, { id::unisonWidth, 0.5f },
            { id::cutoff, 500 }, { id::resonance, 0.12f }, { id::envAmount, 0.55f },
            { id::attack, 0.06f }, { id::decay, 0.7f }, { id::sustain, 0.5f },
            { id::ampAttack, 0.03f }, { id::ampSustain, 0.9f }, { id::ampRelease, 0.25f },
            { id::lfoRate, 5.5f }, { id::lfoPitch, 0.12f }, { id::lfoDelay, 0.5f },
            { id::chorus, chorus2 }, { id::reverbMix, 0.2f }, { id::velocity, 0.6f }, { id::volume, -2.0f }, { id::tube, 0.25f }} },

        { "Lead", "Trance Lead", { { id::unison, uni5 }, { id::unisonDetune, 0.4f }, { id::unisonWidth, 0.9f },
            { id::cutoff, 5000 }, { id::envAmount, 0.15f },
            { id::ampSustain, 0.9f }, { id::ampRelease, 0.4f },
            { id::chorus, chorusOff }, { id::delayMix, 0.35f }, { id::delayTime, d8d }, { id::delayFeedback, 0.5f },
            { id::reverbMix, 0.3f }, { id::reverbSize, 0.8f } } },

        { "Lead", "Tube Lead", { { id::voiceMode, mono }, { id::glide, 0.05f }, { id::subLevel, 0.2f },
            { id::cutoff, 1800 }, { id::resonance, 0.2f }, { id::envAmount, 0.25f }, { id::decay, 0.6f }, { id::sustain, 0.5f },
            { id::drive, 0.45f }, { id::tube, 0.35f },
            { id::ampSustain, 0.9f }, { id::ampRelease, 0.3f },
            { id::lfoRate, 5.3f }, { id::lfoPitch, 0.13f }, { id::lfoDelay, 0.5f },
            { id::chorus, chorusOff }, { id::delayMix, 0.25f }, { id::delayTime, d8d }, { id::reverbMix, 0.15f }, { id::volume, -2.0f }} },

        // ── Plucks ────────────────────────────────────────────────────────
        { "Pluck", "House Pluck", { { id::sawLevel, 0.6f }, { id::pulseLevel, 0.8f }, { id::pw, 0.35f },
            { id::hpf, 120 }, { id::cutoff, 400 }, { id::resonance, 0.3f }, { id::envAmount, 0.5f }, { id::keyTrack, 0.7f },
            { id::attack, 0.001f }, { id::decay, 0.28f }, { id::sustain, 0.0f }, { id::release, 0.25f },
            { id::vcaMode, vcaGate }, { id::chorus, chorus12 }, { id::reverbMix, 0.15f }, { id::volume, -1.0f }} },

        { "Pluck", "Glass Pluck", { { id::sawLevel, 0.3f }, { id::pulseLevel, 0.8f }, { id::pw, 0.25f },
            { id::cutoff, 800 }, { id::resonance, 0.4f }, { id::envAmount, 0.6f },
            { id::attack, 0.001f }, { id::decay, 0.35f }, { id::sustain, 0.0f },
            { id::ampAttack, 0.001f }, { id::ampDecay, 1.2f }, { id::ampSustain, 0.0f }, { id::ampRelease, 1.0f },
            { id::chorus, chorus2 }, { id::delayMix, 0.3f }, { id::delayTime, d8d }, { id::delayFeedback, 0.45f },
            { id::reverbMix, 0.3f }, { id::volume, -1.0f }} },

        { "Pluck", "Trance Pluck", { { id::unison, uni5 }, { id::unisonDetune, 0.3f }, { id::unisonWidth, 0.9f },
            { id::cutoff, 300 }, { id::resonance, 0.25f }, { id::envAmount, 0.65f },
            { id::decay, 0.2f }, { id::sustain, 0.0f },
            { id::ampDecay, 0.5f }, { id::ampSustain, 0.0f }, { id::ampRelease, 0.4f },
            { id::chorus, chorusOff }, { id::delayMix, 0.35f }, { id::delayTime, d8d }, { id::delayFeedback, 0.5f },
            { id::reverbMix, 0.25f }, { id::volume, -2.0f }} },

        { "Pluck", "Mallet", { { id::sawLevel, 0.0f }, { id::pulseLevel, 1.0f }, { id::pw, 0.55f },
            { id::cutoff, 600 }, { id::resonance, 0.5f }, { id::envAmount, 0.5f }, { id::keyTrack, 1.0f },
            { id::decay, 0.15f }, { id::sustain, 0.0f },
            { id::ampAttack, 0.001f }, { id::ampDecay, 0.6f }, { id::ampSustain, 0.0f }, { id::ampRelease, 0.5f },
            { id::chorus, chorus1 }, { id::reverbMix, 0.25f }, { id::volume, -4.0f }} },

        { "Pluck", "Dub Chord", { { id::pulseLevel, 0.4f }, { id::pw, 0.5f },
            { id::hpf, 250 }, { id::cutoff, 700 }, { id::resonance, 0.35f }, { id::envAmount, 0.4f },
            { id::decay, 0.3f }, { id::sustain, 0.05f },
            { id::ampDecay, 0.35f }, { id::ampSustain, 0.0f }, { id::ampRelease, 0.3f },
            { id::chorus, chorus2 }, { id::delayMix, 0.45f }, { id::delayTime, d4d }, { id::delayFeedback, 0.65f },
            { id::reverbMix, 0.3f }, { id::reverbSize, 0.8f }, { id::volume, 0.0f }} },

        { "Pluck", "Arp Pluck", { { id::subLevel, 0.3f },
            { id::cutoff, 500 }, { id::resonance, 0.3f }, { id::envAmount, 0.5f },
            { id::decay, 0.18f }, { id::sustain, 0.0f },
            { id::ampDecay, 0.25f }, { id::ampSustain, 0.0f }, { id::ampRelease, 0.15f },
            { id::chorus, chorus1 }, { id::delayMix, 0.2f }, { id::delayTime, d16 }, { id::delayFeedback, 0.3f }, { id::volume, -2.0f }} },

        { "Pluck", "Synth Harp", { { id::sawLevel, 0.3f }, { id::pulseLevel, 0.9f }, { id::pw, 0.3f },
            { id::cutoff, 1500 }, { id::resonance, 0.2f }, { id::envAmount, 0.35f },
            { id::decay, 0.5f }, { id::sustain, 0.1f },
            { id::ampDecay, 2.0f }, { id::ampSustain, 0.0f }, { id::ampRelease, 1.5f },
            { id::chorus, chorus1 }, { id::reverbMix, 0.35f }, { id::reverbSize, 0.85f }, { id::volume, -4.0f }} },

        // ── Bass ──────────────────────────────────────────────────────────
        { "Bass", "Saw Bass", { { id::voiceMode, mono }, { id::glide, 0.04f }, { id::subLevel, 0.8f },
            { id::cutoff, 220 }, { id::resonance, 0.35f }, { id::envAmount, 0.45f }, { id::keyTrack, 0.3f },
            { id::attack, 0.002f }, { id::decay, 0.35f }, { id::sustain, 0.25f }, { id::release, 0.08f },
            { id::vcaMode, vcaEnv1 }, { id::drift, 0.15f }, { id::velocity, 0.6f },
            { id::chorus, chorusOff }, { id::volume, -3.0f }, { id::drive, 0.35f }, { id::tube, 0.2f }} },

        { "Bass", "Sub Bass", { { id::voiceMode, mono },
            { id::sawLevel, 0.0f }, { id::pulseLevel, 0.6f }, { id::subLevel, 1.0f },
            { id::cutoff, 300 }, { id::resonance, 0.0f }, { id::keyTrack, 0.3f },
            { id::envAmount, 0.1f }, { id::decay, 0.2f }, { id::sustain, 0.5f },
            { id::ampAttack, 0.003f }, { id::ampSustain, 1.0f }, { id::ampRelease, 0.08f },
            { id::chorus, chorusOff }, { id::drift, 0.05f }, { id::volume, -3.0f } } },

        { "Bass", "Juno Bass", { { id::voiceMode, mono },
            { id::sawLevel, 0.0f }, { id::pulseLevel, 0.8f }, { id::pw, 0.4f }, { id::subLevel, 0.7f },
            { id::cutoff, 350 }, { id::resonance, 0.3f }, { id::envAmount, 0.4f },
            { id::decay, 0.25f }, { id::sustain, 0.2f },
            { id::ampSustain, 0.9f }, { id::ampRelease, 0.1f },
            { id::chorus, chorusOff }, { id::volume, -3.0f } } },

        { "Bass", "Acid Bass", { { id::voiceMode, mono }, { id::glide, 0.07f },
            { id::cutoff, 250 }, { id::resonance, 0.8f }, { id::envAmount, 0.55f }, { id::keyTrack, 0.4f },
            { id::decay, 0.22f }, { id::sustain, 0.05f },
            { id::ampSustain, 0.9f }, { id::ampRelease, 0.06f },
            { id::chorus, chorusOff }, { id::volume, -1.0f }, { id::drive, 0.5f }} },

        { "Bass", "Synthwave Bass", { { id::voiceMode, mono }, { id::subLevel, 0.3f },
            { id::cutoff, 400 }, { id::resonance, 0.2f }, { id::envAmount, 0.45f },
            { id::decay, 0.15f }, { id::sustain, 0.1f },
            { id::ampDecay, 0.3f }, { id::ampSustain, 0.3f }, { id::ampRelease, 0.08f },
            { id::chorus, chorusOff }, { id::volume, -1.0f } } },

        { "Bass", "Organ Bass", { { id::voiceMode, mono },
            { id::sawLevel, 0.0f }, { id::pulseLevel, 1.0f }, { id::pw, 0.65f }, { id::subLevel, 0.8f },
            { id::cutoff, 900 }, { id::resonance, 0.0f }, { id::envAmount, 0.3f },
            { id::attack, 0.001f }, { id::decay, 0.05f }, { id::sustain, 0.0f },
            { id::vcaMode, vcaGate }, { id::chorus, chorusOff }, { id::volume, -3.0f }, { id::tube, 0.3f }} },

        { "Bass", "Reese", { { id::voiceMode, mono }, { id::glide, 0.04f },
            { id::unison, uni3 }, { id::unisonDetune, 0.25f }, { id::unisonWidth, 0.2f },
            { id::subLevel, 0.4f }, { id::cutoff, 600 }, { id::resonance, 0.15f },
            { id::lfoFilter, 0.1f }, { id::lfoRate, 0.3f },
            { id::ampSustain, 1.0f }, { id::ampRelease, 0.15f },
            { id::chorus, chorusOff }, { id::volume, 0.0f }, { id::drive, 0.25f }, { id::tube, 0.2f }} },

        { "Bass", "Driven Bass", { { id::voiceMode, mono }, { id::subLevel, 0.5f },
            { id::cutoff, 300 }, { id::resonance, 0.45f }, { id::envAmount, 0.5f }, { id::decay, 0.25f }, { id::sustain, 0.15f },
            { id::drive, 0.7f }, { id::tube, 0.25f },
            { id::ampSustain, 0.9f }, { id::ampRelease, 0.08f },
            { id::chorus, chorusOff }, { id::volume, -2.0f } } },

        // ── Keys ──────────────────────────────────────────────────────────
        { "Keys", "Juno Organ", { { id::sawLevel, 0.3f }, { id::pulseLevel, 0.9f }, { id::pw, 0.2f }, { id::subLevel, 0.6f },
            { id::cutoff, 3000 }, { id::resonance, 0.0f },
            { id::vcaMode, vcaGate }, { id::chorus, chorus12 }, { id::reverbMix, 0.2f }, { id::volume, -9.0f }, { id::tube, 0.2f }, { id::phaser, phaserFast }, { id::phaserMix, 0.4f }} },

        { "Keys", "Poly Brass", { { id::cutoff, 600 }, { id::resonance, 0.12f }, { id::envAmount, 0.55f }, { id::keyTrack, 0.6f },
            { id::attack, 0.04f }, { id::decay, 0.6f }, { id::sustain, 0.55f }, { id::release, 0.25f },
            { id::ampAttack, 0.04f }, { id::ampDecay, 0.6f }, { id::ampSustain, 0.8f }, { id::ampRelease, 0.25f },
            { id::lfoRate, 5.5f }, { id::lfoDelay, 0.6f }, { id::lfoPitch, 0.1f },
            { id::velocity, 0.6f }, { id::chorus, chorus2 }, { id::reverbMix, 0.2f }, { id::tube, 0.25f }} },

        { "Keys", "Soft Keys", { { id::sawLevel, 0.2f }, { id::pulseLevel, 0.8f }, { id::pw, 0.1f },
            { id::cutoff, 700 }, { id::resonance, 0.1f }, { id::envAmount, 0.35f }, { id::keyTrack, 0.8f },
            { id::decay, 1.0f }, { id::sustain, 0.1f },
            { id::ampAttack, 0.002f }, { id::ampDecay, 2.5f }, { id::ampSustain, 0.2f }, { id::ampRelease, 0.6f },
            { id::velocity, 0.8f }, { id::chorus, chorus2 }, { id::reverbMix, 0.2f } } },

        { "Keys", "House Stab", { { id::unison, uni3 }, { id::unisonDetune, 0.2f }, { id::unisonWidth, 0.7f },
            { id::pulseLevel, 0.5f }, { id::pw, 0.3f },
            { id::hpf, 150 }, { id::cutoff, 900 }, { id::resonance, 0.2f }, { id::envAmount, 0.45f },
            { id::decay, 0.2f }, { id::sustain, 0.15f },
            { id::ampDecay, 0.4f }, { id::ampSustain, 0.3f }, { id::ampRelease, 0.25f },
            { id::chorus, chorusOff }, { id::reverbMix, 0.25f }, { id::reverbSize, 0.6f }, { id::volume, -2.0f }} },

        { "Keys", "Clav", { { id::sawLevel, 0.0f }, { id::pulseLevel, 1.0f }, { id::pw, 0.8f },
            { id::hpf, 300 }, { id::cutoff, 1500 }, { id::resonance, 0.3f }, { id::envAmount, 0.4f },
            { id::decay, 0.12f }, { id::sustain, 0.1f },
            { id::ampAttack, 0.001f }, { id::ampDecay, 0.35f }, { id::ampSustain, 0.3f }, { id::ampRelease, 0.1f },
            { id::velocity, 0.8f }, { id::chorus, chorusOff } } },

        { "Keys", "Bell Keys", { { id::range, range4 }, { id::sawLevel, 0.2f }, { id::pulseLevel, 0.7f }, { id::pw, 0.6f },
            { id::cutoff, 3000 }, { id::resonance, 0.6f }, { id::envAmount, 0.3f },
            { id::decay, 0.4f }, { id::sustain, 0.0f },
            { id::ampAttack, 0.001f }, { id::ampDecay, 3.0f }, { id::ampSustain, 0.0f }, { id::ampRelease, 2.0f },
            { id::chorus, chorus2 }, { id::delayMix, 0.2f }, { id::delayTime, d4d }, { id::reverbMix, 0.35f } } },

        // ── FX ────────────────────────────────────────────────────────────
        { "FX", "Noise Sweep", { { id::sawLevel, 0.0f }, { id::noiseLevel, 1.0f },
            { id::cutoff, 400 }, { id::resonance, 0.7f }, { id::lfoFilter, 0.6f }, { id::lfoRate, 0.15f },
            { id::ampAttack, 1.5f }, { id::ampSustain, 1.0f }, { id::ampRelease, 2.0f },
            { id::chorus, chorus1 }, { id::delayMix, 0.2f }, { id::reverbMix, 0.5f }, { id::reverbSize, 0.95f }, { id::volume, 6.0f }} },

        { "FX", "Laser", { { id::voiceMode, mono }, { id::pulseLevel, 0.5f },
            { id::lfoPitch, 1.0f }, { id::lfoRate, 14.0f },
            { id::cutoff, 3000 }, { id::resonance, 0.6f }, { id::envAmount, 0.6f }, { id::decay, 0.3f }, { id::sustain, 0.0f },
            { id::ampAttack, 0.001f }, { id::ampDecay, 0.4f }, { id::ampSustain, 0.0f }, { id::ampRelease, 0.3f },
            { id::delayMix, 0.4f }, { id::delayTime, d8 }, { id::delayFeedback, 0.6f }, { id::reverbMix, 0.25f }, { id::volume, 0.0f }} },

        { "FX", "Wind", { { id::sawLevel, 0.0f }, { id::noiseLevel, 1.0f },
            { id::hpf, 200 }, { id::cutoff, 900 }, { id::resonance, 0.85f }, { id::lfoFilter, 0.3f }, { id::lfoRate, 0.25f },
            { id::ampAttack, 2.0f }, { id::ampSustain, 1.0f }, { id::ampRelease, 3.0f },
            { id::chorus, chorus2 }, { id::reverbMix, 0.5f }, { id::volume, 6.0f }} },

        { "FX", "Siren", { { id::voiceMode, mono }, { id::sawLevel, 0.0f }, { id::pulseLevel, 1.0f }, { id::pw, 0.2f },
            { id::lfoPitch, 1.0f }, { id::lfoRate, 0.4f }, { id::cutoff, 2500 }, { id::resonance, 0.3f },
            { id::ampAttack, 0.2f }, { id::ampSustain, 1.0f }, { id::ampRelease, 0.8f },
            { id::chorus, chorus1 }, { id::delayMix, 0.35f }, { id::delayTime, d4 }, { id::delayFeedback, 0.5f },
            { id::reverbMix, 0.3f } } },
    };

    void set (juce::RangedAudioParameter& p, float normalised)
    {
        p.beginChangeGesture();
        p.setValueNotifyingHost (normalised);
        p.endChangeGesture();
    }
}

int count() { return static_cast<int> (std::size (factory)); }

juce::String name (int index)
{
    return juce::isPositiveAndBelow (index, count()) ? factory[index].name : "";
}

juce::String category (int index)
{
    return juce::isPositiveAndBelow (index, count()) ? factory[index].category : "";
}

juce::String fullName (int index)
{
    if (! juce::isPositiveAndBelow (index, count()))
        return {};

    return index == 0 ? name (0) : category (index) + " / " + name (index);
}

void apply (juce::AudioProcessorValueTreeState& state, int index)
{
    if (! juce::isPositiveAndBelow (index, count()))
        return;

    for (auto* p : state.processor.getParameters())
        if (auto* ranged = dynamic_cast<juce::RangedAudioParameter*> (p))
            set (*ranged, ranged->getDefaultValue());

    for (const auto& v : factory[index].values)
    {
        auto* p = state.getParameter (v.id);
        jassert (p != nullptr);
        if (p != nullptr)
            set (*p, p->convertTo0to1 (v.value));
    }
}
}
