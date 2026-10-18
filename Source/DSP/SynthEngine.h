#pragma once

#include "Character.h"
#include "Chorus.h"
#include "Delay.h"
#include "Dust.h"
#include "Voice.h"

#include <juce_dsp/juce_dsp.h>
#include <array>

namespace dsp86
{
enum class VoiceMode { poly, mono };

// Zielwerte aus den Parametern, einmal pro Block gelesen.
struct Settings
{
    int   octave = 0;
    float pw = 0.0f;
    PwmSource pwmSource = PwmSource::manual;
    float saw = 1.0f, pulse = 0.0f, sub = 0.0f, noise = 0.0f;
    float lfoPitch = 0.0f;

    int   unison = 1;
    float unisonDetune = 0.3f, unisonWidth = 0.7f;

    float hpfHz = 20.0f, cutoffHz = 8000.0f, resonance = 0.1f;
    float envAmount = 0.0f, lfoFilter = 0.0f, keyTrack = 0.5f;

    float attack = 0.005f, decay = 0.4f, sustain = 0.8f, release = 0.3f;
    float ampAttack = 0.005f, ampDecay = 0.4f, ampSustain = 0.8f, ampRelease = 0.3f;
    VcaMode vcaMode = VcaMode::env2;

    float lfoRate = 3.0f, lfoDelay = 0.0f;

    Chorus::Mode chorus = Chorus::Mode::one;
    float delayBeats = 0.75f, delayFeedback = 0.35f, delayMix = 0.0f;
    float reverbSize = 0.6f, reverbMix = 0.0f;
    int   phaser = 0;
    float phaserMix = 0.6f;
    float drive = 0.0f, tube = 0.0f, dust = 0.0f;
    float dustTape = 0.5f, dustCrush = 0.5f, dustNoise = 0.5f, dustTone = 0.5f;
    float dist = 0.0f;
    bool  throwOn = false;

    int   bWave = 0;
    float bOctave = 0.0f, bSemi = 0.0f, bFine = 7.0f, blend = 0.0f;
    float subLevel = 0.0f, subDecay = 1.2f, subDrop = 0.25f, subDrive = 0.3f;
    int   subOctave = -1;
    double bpm = 120.0;

    VoiceMode voiceMode = VoiceMode::poly;
    float glide = 0.0f, drift = 0.2f, velocity = 0.5f, volumeDb = -6.0f;
};

class SynthEngine
{
public:
    static constexpr int numVoices = 8;

    void prepare (double sampleRate, int maxBlockSize, const Settings& initial);
    void reset();
    int getLatencySamples() const noexcept { return latencySamples; }

    // out: 1 oder 2 Kanäle. Echtzeitsicher, keine Allokation.
    void process (juce::AudioBuffer<float>& out, const juce::MidiBuffer& midi, const Settings& settings) noexcept;

private:
    static constexpr int modChunk = 64;
    static constexpr int factor = 2;

    void applySettings (const Settings& s) noexcept;
    void updateUnison (float detune, float width) noexcept;
    void handleMidi (const juce::uint8* data, int numBytes) noexcept;
    void noteOn (int note, float velocity) noexcept;
    void noteOff (int note) noexcept;
    void releaseNote (int note) noexcept;
    void allNotesOff() noexcept;
    void renderOversampled (float* osL, float* osR, float* osSub, int start, int end) noexcept;
    void processReverb (float* left, float* right, int numSamples) noexcept;
    int  heldKeyCount() const noexcept;

    double baseRate = 44100.0, osRate = 88200.0;
    int maxBlock = 512, latencySamples = 0;

    std::unique_ptr<juce::dsp::Oversampling<float>> oversampling;
    juce::AudioBuffer<float> zeroBuffer, stereoBuffer, reverbBuffer;

    std::array<Voice, numVoices> voices;
    Chorus chorus;
    PingPongDelay delay;
    Phaser phaser;
    Tube tube;
    Dust dust;
    LeadDistortion leadDist;
    juce::Reverb reverb;
    juce::Reverb::Parameters reverbParams;
    OnePoleHighpass hpfL, hpfR, reverbHpfL, reverbHpfR;
    float reverbHpfG = 0.01f;
    bool reverbActive = false;

    // Smoothing auf 2× Rate
    juce::SmoothedValue<float, juce::ValueSmoothingTypes::Multiplicative> cutoff { 8000.0f };
    juce::SmoothedValue<float> resonance, envAmount, lfoFilter, keyTrack, pw,
                               saw, pulse, sub, noise, lfoPitch, drift, bend, modWheel,
                               unisonDetune, unisonWidth, drive, blend, subLevel;
    // Smoothing auf Basisrate
    juce::SmoothedValue<float, juce::ValueSmoothingTypes::Multiplicative> hpfHz { 20.0f };
    juce::SmoothedValue<float> volume, reverbMix;

    std::array<float, modChunk> pitchBuf {}, lfoBuf {}, pwBuf {}, sawBuf {}, pulseBuf {}, subBuf {},
                                noiseBuf {}, cutoffBuf {}, resoBuf {}, envBuf {}, lfoFiltBuf {}, keyBuf {},
                                driveBuf {}, blendBuf {};

    Settings current;
    VoiceMods mods {};

    float lfoPhase = 0.0f, lfoInc = 0.0f;
    float lfoDelayGain = 1.0f, lfoDelayStep = 1.0f;

    uint64_t noteCounter = 0;
    std::array<bool, 128> keyDown {}, sustained {};
    bool sustainPedal = false;
    std::array<int, 16> monoStack {};
    int monoCount = 0;
};
}
