#pragma once

#include <juce_audio_basics/juce_audio_basics.h>
#include <cmath>
#include <vector>

namespace dsp86
{
// Juno-Chorus: zwei gegenphasig modulierte Delays aus einem Mono-Signal.
class Chorus
{
public:
    enum class Mode { off, one, two, both };

    void prepare (double newSampleRate)
    {
        sampleRate = newSampleRate;

        const auto maxDelaySamples = static_cast<int> (std::ceil (0.012 * sampleRate)) + 4;
        int size = 1;
        while (size < maxDelaySamples)
            size <<= 1;

        buffer.assign (static_cast<size_t> (size), 0.0f);
        mask = size - 1;

        for (auto* s : { &centreMs, &depthMs, &wet })
            s->reset (sampleRate, 0.05);

        const auto lpG = std::tan (juce::MathConstants<double>::pi * 8000.0 / sampleRate);
        lowpassG = static_cast<float> (lpG / (1.0 + lpG));

        reset();
    }

    void reset() noexcept
    {
        std::fill (buffer.begin(), buffer.end(), 0.0f);
        writePos = 0;
        lfoPhase = 0.0f;
        lpL = lpR = 0.0f;
        centreMs.setCurrentAndTargetValue (centreMs.getTargetValue());
        depthMs.setCurrentAndTargetValue (depthMs.getTargetValue());
        wet.setCurrentAndTargetValue (wet.getTargetValue());
    }

    void setMode (Mode mode) noexcept
    {
        switch (mode)
        {
            case Mode::off:  wet.setTargetValue (0.0f); return;
            case Mode::one:  rateHz = 0.513f; centreMs.setTargetValue (3.505f); depthMs.setTargetValue (1.845f); break;
            case Mode::two:  rateHz = 0.863f; centreMs.setTargetValue (3.505f); depthMs.setTargetValue (1.845f); break;
            case Mode::both: rateHz = 9.75f;  centreMs.setTargetValue (3.5f);   depthMs.setTargetValue (0.2f);   break;
        }

        wet.setTargetValue (1.0f);
    }

    void process (const float* in, float* left, float* right, int numSamples) noexcept
    {
        const auto lfoInc = rateHz / static_cast<float> (sampleRate);
        const auto msToSamples = static_cast<float> (sampleRate) * 0.001f;

        for (int i = 0; i < numSamples; ++i)
        {
            const auto dry = in[i];
            buffer[static_cast<size_t> (writePos)] = dry;

            lfoPhase += lfoInc;
            if (lfoPhase >= 1.0f)
                lfoPhase -= 1.0f;

            const auto tri    = 4.0f * std::abs (lfoPhase - 0.5f) - 1.0f;
            const auto centre = centreMs.getNextValue() * msToSamples;
            const auto depth  = depthMs.getNextValue() * msToSamples;
            const auto w      = wet.getNextValue();

            lpL += (read (centre + depth * tri) - lpL) * lowpassG;
            lpR += (read (centre - depth * tri) - lpR) * lowpassG;

            const auto norm = 1.0f / (1.0f + 0.4f * w);
            left[i]  = (dry + w * lpL) * norm;
            right[i] = (dry + w * lpR) * norm;

            writePos = (writePos + 1) & mask;
        }
    }

private:
    // Hermite-Interpolation, delaySamples >= 1
    float read (float delaySamples) const noexcept
    {
        const auto pos  = static_cast<float> (writePos) - delaySamples;
        const auto base = static_cast<int> (std::floor (pos));
        const auto frac = pos - static_cast<float> (base);

        const auto xm1 = buffer[static_cast<size_t> ((base - 1) & mask)];
        const auto x0  = buffer[static_cast<size_t> (base & mask)];
        const auto x1  = buffer[static_cast<size_t> ((base + 1) & mask)];
        const auto x2  = buffer[static_cast<size_t> ((base + 2) & mask)];

        const auto c1 = 0.5f * (x1 - xm1);
        const auto c2 = xm1 - 2.5f * x0 + 2.0f * x1 - 0.5f * x2;
        const auto c3 = 0.5f * (x2 - xm1) + 1.5f * (x0 - x1);
        return ((c3 * frac + c2) * frac + c1) * frac + x0;
    }

    double sampleRate = 44100.0;
    std::vector<float> buffer;
    int mask = 0, writePos = 0;

    float rateHz = 0.513f, lfoPhase = 0.0f;
    float lowpassG = 0.5f, lpL = 0.0f, lpR = 0.0f;

    juce::SmoothedValue<float> centreMs { 3.505f }, depthMs { 1.845f }, wet { 0.0f };
};
}
