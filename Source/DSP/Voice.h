#pragma once

#include "Envelope.h"
#include "LadderFilter.h"
#include "Oscillator.h"

#include <array>
#include <cmath>
#include <cstdint>

namespace dsp86
{
enum class PwmSource { lfo, manual, env };
enum class VcaMode   { env1, gate, env2 };

inline constexpr int maxUnison = 7;

// Pro Sample geglättete Werte, die die Engine für einen Teilblock vorberechnet.
struct VoiceMods
{
    const float* pitchSemis;   // Bend + LFO-Vibrato
    const float* lfo;          // −1..1, inkl. LFO-Delay
    const float* pw;
    const float* saw;
    const float* pulse;
    const float* sub;
    const float* noise;
    const float* cutoffHz;
    const float* resonance;
    const float* envOctaves;
    const float* lfoOctaves;
    const float* keyTrack;
    const float* drive;
    const float* blend;        // 0 = nur Layer A, 1 = nur Layer B

    float drift;
    float octaveShift;
    float glideCoef;
    PwmSource pwmSource;
    VcaMode vcaMode;
    AdsrCoefs gate;

    // Unison: Index 0 ist die unverstimmte Mitte (trägt den Sub).
    int unison;
    bool stereo;
    std::array<float, maxUnison> ratio;
    std::array<float, maxUnison> gainL;
    std::array<float, maxUnison> gainR;

    // Layer B
    bool layerB;
    int bWave;                 // 0 Saw, 1 Square, 2 Pulse, 3 Noise
    float bRatio;

    // 808-Layer (läuft am Filter vorbei)
    float subLevel, subOctave, subDropSemis, subDrive;
    float subDecayCoef, subReleaseCoef, subDropCoef;
};

class Voice
{
public:
    void prepare (double newSampleRate, uint32_t seed) noexcept
    {
        sampleRate = static_cast<float> (newSampleRate);
        piOverSr   = 3.14159265f / sampleRate;
        maxCutoff  = 0.45f * sampleRate;
        fadeStep   = 1.0f / (0.003f * sampleRate);
        driftCoef  = 1.0f - std::exp (-6.2831853f * 0.3f / sampleRate);
        driftHold  = static_cast<int> (sampleRate / 3.0f);
        noise      = Noise (seed);

        // Voice-Card: feste Abweichungen dieser Stimme (wie Bauteiltoleranzen)
        cardPitch  = noise.next();
        cardCutoff = noise.next();
        cardEnv    = noise.next();
        cardLevel  = noise.next();
        kill();
    }

    // Hüllkurven dieser Stimme, Tempo um die Voice-Card versetzt (bis ±15 % bei Drift 100 %).
    void updateEnvelopes (const AdsrTimes& env1, const AdsrTimes& env2, float drift, double rate) noexcept
    {
        const auto scale = 1.0f + 0.15f * drift * cardEnv;
        envCoefs = AdsrCoefs::make (env1.attack * scale, env1.decay * scale, env1.sustain, env1.release * scale, rate);
        ampCoefs = AdsrCoefs::make (env2.attack * scale, env2.decay * scale, env2.sustain, env2.release * scale, rate);
    }

    void kill() noexcept
    {
        env.reset();
        ampEnv.reset();
        gateEnv.reset();
        filterL.reset();
        filterR.reset();
        note = -1;
        held = false;
        fading = false;
        subEnv = 0.0f;
        pendingNote = -1;
        fadeGain = 1.0f;
    }

    bool isActive() const noexcept     { return note >= 0; }
    bool isHeld() const noexcept       { return held; }
    int  getNote() const noexcept      { return pendingNote >= 0 ? pendingNote : note; }
    uint64_t getAge() const noexcept   { return age; }

    // Startet einen Ton. Klingt die Stimme gerade einen anderen Ton,
    // wird erst 3 ms ausgeblendet, um Klicks zu vermeiden.
    void start (int midiNote, float velocity, float velocitySens, uint64_t order, bool fadeFirst) noexcept
    {
        age = order;
        held = true;

        if (fadeFirst && isActive())
        {
            fading = true;
            pendingNote = midiNote;
            pendingVelocity = velocity;
            pendingSens = velocitySens;
            return;
        }

        fading = false;
        pendingNote = -1;
        begin (midiNote, velocity, velocitySens, ! isActive());
    }

    // Mono-Legato: Tonhöhe ändern, Hüllkurven laufen weiter.
    void legatoTo (int midiNote, uint64_t order) noexcept
    {
        age = order;
        if (pendingNote >= 0)
            pendingNote = midiNote;
        else
            targetNote = static_cast<float> (midiNote);
        note = midiNote;
    }

    void release() noexcept
    {
        held = false;
        if (pendingNote >= 0)
        {
            fading = true;
            pendingNote = -1;
            return;
        }
        env.gateOff();
        ampEnv.gateOff();
        gateEnv.gateOff();
        subReleasing = true;
    }

    void render (float* outL, float* outR, float* outSub, int numSamples, const VoiceMods& m) noexcept
    {
        if (! isActive())
            return;

        for (int i = 0; i < numSamples; ++i)
        {
            if (--driftCounter <= 0)
            {
                driftCounter = driftHold;
                driftTarget = noise.next();
            }
            driftWalk += (driftTarget - driftWalk) * driftCoef;

            currentNote = targetNote + (currentNote - targetNote) * m.glideCoef;

            const auto semis = currentNote + m.octaveShift + m.pitchSemis[i]
                             + m.drift * (cardPitch * 0.06f + driftStatic * 0.02f + driftWalk * 0.03f);
            const auto baseInc = 440.0f * std::exp2 ((semis - 69.0f) * (1.0f / 12.0f)) / sampleRate;

            const auto e  = env.next (envCoefs);
            const auto a  = ampEnv.next (ampCoefs);
            const auto gt = gateEnv.next (m.gate);

            auto pwAmount = m.pw[i];
            if (m.pwmSource == PwmSource::lfo)      pwAmount *= 0.5f + 0.5f * m.lfo[i];
            else if (m.pwmSource == PwmSource::env) pwAmount *= e;
            const auto duty = 0.5f - 0.45f * pwAmount;

            const auto sawLevel = m.saw[i], pulseLevel = m.pulse[i];
            const auto common = 0.5f * (noise.next() * m.noise[i]);
            auto mixL = common, mixR = common;

            for (int u = 0; u < m.unison; ++u)
            {
                const auto uz  = static_cast<size_t> (u);
                const auto osc = dcos[uz].next (std::min (baseInc * m.ratio[uz], 0.45f), duty);
                auto s = osc.saw * sawLevel + osc.pulse * pulseLevel;
                if (u == 0)
                    s += osc.sub * m.sub[i];
                s *= 0.5f;

                mixL += s * m.gainL[uz];
                mixR += s * m.gainR[uz];
            }

            // Layer B: zweiter Oszillator, Equal-Power-Crossfade vor dem Filter
            if (m.layerB)
            {
                const auto oscB = dcoB.next (std::min (baseInc * m.bRatio, 0.45f), m.bWave == 2 ? 0.15f : 0.5f);
                const auto b = 0.5f * (m.bWave == 0 ? oscB.saw : m.bWave == 3 ? noise.next() : oscB.pulse);
                const auto angle = m.blend[i] * 1.5707963f;
                const auto gA = std::cos (angle), gB = std::sin (angle);
                mixL = mixL * gA + b * gB;
                mixR = mixR * gA + b * gB;
            }

            // Drive: Mixer übersteuern (bis +16 dB), pegelkompensiert
            if (const auto d = m.drive[i]; d > 1.0e-4f)
            {
                const auto comp = 1.0f / (1.0f + 1.6f * d);
                mixL = softClip (mixL * (1.0f + 5.3f * d)) * comp;
                if (m.stereo)
                    mixR = softClip (mixR * (1.0f + 5.3f * d)) * comp;
            }

            const auto octaves = m.envOctaves[i] * e + m.lfoOctaves[i]
                               + m.keyTrack[i] * (currentNote - 60.0f) * (1.0f / 12.0f)
                               + velocityOctaves + m.drift * (cardCutoff * 0.2f + driftCutoff * 0.05f);
            const auto fc = std::clamp (m.cutoffHz[i] * std::exp2 (octaves), 15.0f, maxCutoff);
            const auto g  = std::tan (fc * piOverSr);

            const auto yL = filterL.process (mixL, g, m.resonance[i]);
            const auto yR = m.stereo ? filterR.process (mixR, g, m.resonance[i]) : yL;

            const auto amp  = m.vcaMode == VcaMode::gate ? gt : (m.vcaMode == VcaMode::env1 ? e : a);
            const auto gain = amp * velocityGain * fadeGain * (0.4f + 0.04f * m.drift * cardLevel);
            outL[i] += yL * gain;
            outR[i] += yR * gain;

            // 808: Sinus mit eigener Hüllkurve und Pitch-Drop, am Filter vorbei
            if (m.subLevel > 0.0f && subEnv > 1.0e-4f)
            {
                const auto subSemis = currentNote + m.subOctave + m.pitchSemis[i] + m.subDropSemis * subDrop;
                subPhase += std::min (440.0f * std::exp2 ((subSemis - 69.0f) * (1.0f / 12.0f)) / sampleRate, 0.45f);
                if (subPhase >= 1.0f)
                    subPhase -= 1.0f;

                auto y = std::sin (6.2831853f * subPhase) * subEnv;
                if (m.subDrive > 1.0e-3f)
                {
                    const auto sg = 1.0f + 6.0f * m.subDrive;
                    y = softClip (y * sg) / softClip (sg);
                }
                outSub[i] += y * m.subLevel * velocityGain * fadeGain * 0.5f;

                subEnv  *= subReleasing ? m.subReleaseCoef : m.subDecayCoef;
                subDrop *= m.subDropCoef;
            }

            if (fading)
            {
                fadeGain -= fadeStep;
                if (fadeGain <= 0.0f)
                {
                    fadeGain = 1.0f;
                    fading = false;

                    if (pendingNote >= 0)
                    {
                        const auto next = pendingNote;
                        pendingNote = -1;
                        begin (next, pendingVelocity, pendingSens, true);
                    }
                    else
                    {
                        kill();
                        return;
                    }
                }
            }

            const auto ampActive = m.vcaMode == VcaMode::gate ? gateEnv.isActive()
                                 : (m.vcaMode == VcaMode::env1 ? env.isActive() : ampEnv.isActive());
            const auto subActive = m.subLevel > 0.0f && subEnv > 1.0e-4f;
            if (! ampActive && ! subActive && ! fading)
            {
                kill();
                return;
            }
        }
    }

private:
    void begin (int midiNote, float velocity, float velocitySens, bool fromSilence) noexcept
    {
        note = midiNote;
        targetNote = static_cast<float> (midiNote);
        currentNote = targetNote;

        velocityGain    = 1.0f - velocitySens * (1.0f - velocity);
        velocityOctaves = velocitySens * (velocity - 1.0f) * 3.0f;

        driftStatic = noise.next();
        driftCutoff = noise.next();

        if (fromSilence)
        {
            env.reset();
            ampEnv.reset();
            gateEnv.reset();
            filterL.reset();
            filterR.reset();
            for (auto& d : dcos)
                d.reset (0.5f + 0.5f * noise.next());
            dcoB.reset (0.5f + 0.5f * noise.next());
            subPhase = 0.0f;
        }

        subEnv = 1.0f;
        subDrop = 1.0f;
        subReleasing = false;

        env.gateOn();
        ampEnv.gateOn();
        gateEnv.gateOn();
    }

    float sampleRate = 44100.0f, piOverSr = 0.0f, maxCutoff = 20000.0f;

    std::array<Dco, maxUnison> dcos;
    Dco dcoB;
    float subPhase = 0.0f, subEnv = 0.0f, subDrop = 0.0f;
    bool subReleasing = false;
    Noise noise;
    LadderFilter filterL, filterR;
    Envelope env, ampEnv, gateEnv;

    int note = -1, pendingNote = -1;
    bool held = false, fading = false;
    float pendingVelocity = 1.0f, pendingSens = 0.0f;
    float fadeGain = 1.0f, fadeStep = 0.01f;
    uint64_t age = 0;

    float targetNote = 60.0f, currentNote = 60.0f;
    float velocityGain = 1.0f, velocityOctaves = 0.0f;

    float driftStatic = 0.0f, driftCutoff = 0.0f;
    float cardPitch = 0.0f, cardCutoff = 0.0f, cardEnv = 0.0f, cardLevel = 0.0f;
    AdsrCoefs envCoefs, ampCoefs;
    float driftWalk = 0.0f, driftTarget = 0.0f, driftCoef = 0.0f;
    int driftCounter = 0, driftHold = 1;
};
}
