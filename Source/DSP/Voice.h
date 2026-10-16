#pragma once

#include "Envelope.h"
#include "LadderFilter.h"
#include "Oscillator.h"

#include <cmath>
#include <cstdint>

namespace dsp86
{
enum class PwmSource { lfo, manual, env };
enum class VcaMode   { env, gate };

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

    float drift;
    float octaveShift;
    float glideCoef;
    PwmSource pwmSource;
    VcaMode vcaMode;
    AdsrCoefs env;
    AdsrCoefs gate;
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
        kill();
    }

    void kill() noexcept
    {
        env.reset();
        gateEnv.reset();
        filter.reset();
        note = -1;
        held = false;
        fading = false;
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

    // Mono-Legato: Tonhöhe ändern, Hüllkurve läuft weiter.
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
        gateEnv.gateOff();
    }

    void render (float* out, int numSamples, const VoiceMods& m) noexcept
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
                             + m.drift * (driftStatic * 0.08f + driftWalk * 0.03f);
            const auto freq = 440.0f * std::exp2 ((semis - 69.0f) * (1.0f / 12.0f));
            const auto inc  = std::min (freq / sampleRate, 0.45f);

            const auto e = env.next (m.env);
            const auto g = gateEnv.next (m.gate);

            auto pwAmount = m.pw[i];
            if (m.pwmSource == PwmSource::lfo)      pwAmount *= 0.5f + 0.5f * m.lfo[i];
            else if (m.pwmSource == PwmSource::env) pwAmount *= e;

            const auto osc = dco.next (inc, 0.5f - 0.45f * pwAmount);
            const auto mix = 0.5f * (osc.saw * m.saw[i] + osc.pulse * m.pulse[i]
                                     + osc.sub * m.sub[i] + noise.next() * m.noise[i]);

            const auto octaves = m.envOctaves[i] * e + m.lfoOctaves[i]
                               + m.keyTrack[i] * (currentNote - 60.0f) * (1.0f / 12.0f)
                               + velocityOctaves + m.drift * driftCutoff * 0.15f;
            const auto fc = std::clamp (m.cutoffHz[i] * std::exp2 (octaves), 15.0f, maxCutoff);
            const auto y  = filter.process (mix, std::tan (fc * piOverSr), m.resonance[i]);

            const auto amp = m.vcaMode == VcaMode::gate ? g : e;
            out[i] += y * amp * velocityGain * fadeGain * 0.4f;

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

            const auto ampActive = m.vcaMode == VcaMode::gate ? gateEnv.isActive() : env.isActive();
            if (! ampActive && ! fading)
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
            gateEnv.reset();
            filter.reset();
            dco.reset (0.5f + 0.5f * noise.next());
        }

        env.gateOn();
        gateEnv.gateOn();
    }

    float sampleRate = 44100.0f, piOverSr = 0.0f, maxCutoff = 20000.0f;

    Dco dco;
    Noise noise;
    LadderFilter filter;
    Envelope env, gateEnv;

    int note = -1, pendingNote = -1;
    bool held = false, fading = false;
    float pendingVelocity = 1.0f, pendingSens = 0.0f;
    float fadeGain = 1.0f, fadeStep = 0.01f;
    uint64_t age = 0;

    float targetNote = 60.0f, currentNote = 60.0f;
    float velocityGain = 1.0f, velocityOctaves = 0.0f;

    float driftStatic = 0.0f, driftCutoff = 0.0f;
    float driftWalk = 0.0f, driftTarget = 0.0f, driftCoef = 0.0f;
    int driftCounter = 0, driftHold = 1;
};
}
