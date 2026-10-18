#pragma once

#include "LadderFilter.h"

#include <juce_audio_basics/juce_audio_basics.h>
#include <array>
#include <cmath>

namespace dsp86
{
// Röhren-Kennlinie: Arbeitspunkt verschoben (Bias) → asymmetrische Sättigung,
// also geradzahlige Obertöne. Bei kleinen Pegeln Verstärkung 1, DC-Blocker danach.
class Tube
{
public:
    void prepare (double sampleRate)
    {
        dcCoef = static_cast<float> (std::tan (juce::MathConstants<double>::pi * 8.0 / sampleRate));
        amount.reset (sampleRate, 0.02);
        reset();
    }

    void reset() noexcept
    {
        dcL.reset();
        dcR.reset();
        amount.setCurrentAndTargetValue (amount.getTargetValue());
    }

    void setAmount (float a) noexcept { amount.setTargetValue (a); }

    void process (float* left, float* right, int numSamples) noexcept
    {
        if (amount.getTargetValue() < 1.0e-4f && ! amount.isSmoothing())
            return;

        for (int i = 0; i < numSamples; ++i)
        {
            const auto a = amount.getNextValue();
            left[i]  = dcL.process (shape (left[i], a), dcCoef);
            right[i] = dcR.process (shape (right[i], a), dcCoef);
        }
    }

private:
    static float shape (float x, float a) noexcept
    {
        const auto drive = 1.0f + 8.0f * a;
        const auto bias  = 0.6f * a;
        // Steigung von softClip im Arbeitspunkt, damit kleine Signale unverändert bleiben
        // softClip'(b) = (729 − 162 b² + 9 b⁴) / (27 + 9 b²)²
        const auto b2 = bias * bias;
        const auto den = 27.0f + 9.0f * b2;
        const auto slope = (729.0f - 162.0f * b2 + 9.0f * b2 * b2) / (den * den);
        const auto y = (softClip (drive * x + bias) - softClip (bias)) / (drive * slope);
        return x + a * (y - x);
    }

    float dcCoef = 0.001f;
    OnePoleHighpass dcL, dcR;
    juce::SmoothedValue<float> amount;
};

// Lead-Distortion, bass-erhaltend: Frequenzweiche bei 250 Hz, nur der Bereich
// darüber wird verzerrt. Läuft auf 2× Rate.
class LeadDistortion
{
public:
    void prepare (double sampleRate)
    {
        const auto t = static_cast<float> (std::tan (juce::MathConstants<double>::pi * 250.0 / sampleRate));
        splitG = t / (1.0f + t);
        amount.reset (sampleRate, 0.02);
        reset();
    }

    void reset() noexcept
    {
        left = right = {};
        amount.setCurrentAndTargetValue (amount.getTargetValue());
    }

    void setAmount (float a) noexcept { amount.setTargetValue (a); }

    void process (float* l, float* r, int numSamples) noexcept
    {
        if (amount.getTargetValue() < 1.0e-4f && ! amount.isSmoothing())
            return;

        for (int i = 0; i < numSamples; ++i)
        {
            const auto a = amount.getNextValue();
            l[i] = shape (l[i], left, a);
            r[i] = shape (r[i], right, a);
        }
    }

private:
    struct Split { float s1 = 0.0f, s2 = 0.0f; };

    // Hochpass 12 dB/Okt. (zwei TPT-Stufen), Bass = Rest: Summe bleibt exakt das Eingangssignal
    float highPass (float x, float& s) const noexcept
    {
        const auto v = (x - s) * splitG;
        const auto lp = v + s;
        s = lp + v;
        return x - lp;
    }

    float shape (float x, Split& st, float a) const noexcept
    {
        const auto high = highPass (highPass (x, st.s1), st.s2);
        // bis +36 dB in den Clipper, Pegelausgleich für typische Synth-Pegel (−20 dBFS)
        const auto g = 1.0f + 63.0f * a;
        const auto dist = softClip (high * g) / std::sqrt (g);
        return x + a * (dist - high);
    }

    float splitG = 0.01f;
    Split left, right;
    juce::SmoothedValue<float> amount;
};

// 6-stufiger Phaser pro Kanal, L/R um 90° versetzt.
class Phaser
{
public:
    enum class Mode { off, slow, fast };

    void prepare (double newSampleRate)
    {
        sampleRate = static_cast<float> (newSampleRate);
        mix.reset (newSampleRate, 0.05);
        reset();
    }

    void reset() noexcept
    {
        stateL.fill (0.0f);
        stateR.fill (0.0f);
        feedbackL = feedbackR = 0.0f;
        lfoPhase = 0.0f;
        mix.setCurrentAndTargetValue (mix.getTargetValue());
    }

    void setParameters (Mode mode, float depth) noexcept
    {
        if (mode != Mode::off)
            rateHz = mode == Mode::slow ? 0.15f : 0.9f;
        mix.setTargetValue (mode == Mode::off ? 0.0f : depth);
    }

    void process (float* left, float* right, int numSamples) noexcept
    {
        if (mix.getTargetValue() < 1.0e-4f && ! mix.isSmoothing())
            return;

        const auto lfoInc = rateHz / sampleRate;
        const auto twoPi = juce::MathConstants<float>::twoPi;

        for (int i = 0; i < numSamples; ++i)
        {
            lfoPhase += lfoInc;
            if (lfoPhase >= 1.0f)
                lfoPhase -= 1.0f;

            const auto m = mix.getNextValue();
            left[i]  = processChannel (left[i],  stateL, feedbackL, std::sin (twoPi * lfoPhase), m);
            right[i] = processChannel (right[i], stateR, feedbackR, std::cos (twoPi * lfoPhase), m);
        }
    }

private:
    float processChannel (float x, std::array<float, 6>& state, float& feedback, float lfo, float m) noexcept
    {
        // Sweep 200 Hz – 3 kHz logarithmisch
        const auto fc = 200.0f * std::exp2 (1.953f * (lfo + 1.0f));
        const auto t  = std::tan (juce::MathConstants<float>::pi * std::min (fc, 0.45f * sampleRate) / sampleRate);
        const auto a  = (t - 1.0f) / (t + 1.0f);

        auto y = x + 0.5f * feedback;
        for (auto& s : state)
        {
            const auto out = a * y + s;
            s = y - a * out;
            y = out;
        }
        feedback = softClip (y);

        return (x + m * y) / (1.0f + m);
    }

    float sampleRate = 44100.0f, rateHz = 0.15f, lfoPhase = 0.0f;
    std::array<float, 6> stateL {}, stateR {};
    float feedbackL = 0.0f, feedbackR = 0.0f;
    juce::SmoothedValue<float> mix;
};
}
