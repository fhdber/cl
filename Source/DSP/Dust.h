#pragma once

#include "Oscillator.h"

#include <juce_audio_basics/juce_audio_basics.h>
#include <cmath>
#include <vector>

namespace dsp86
{
// CONTRABEATZ-Signatur: klingt, als wäre der Synth in einen 90s-Sampler
// resampled und auf Tape gebounct. Ein Regler steuert alles gleichzeitig:
// Tape-Wow/Flutter, Samplerate-/Bit-Reduktion (mit Aliasing), warmer Tiefpass,
// signalabhängiges Rauschen und Knistern.
class Dust
{
public:
    void prepare (double newSampleRate)
    {
        sampleRate = static_cast<float> (newSampleRate);

        const auto maxDelay = static_cast<int> (std::ceil (0.006 * newSampleRate)) + 4;
        int size = 1;
        while (size < maxDelay)
            size <<= 1;
        bufferL.assign (static_cast<size_t> (size), 0.0f);
        bufferR.assign (static_cast<size_t> (size), 0.0f);
        mask = size - 1;

        amount.reset (newSampleRate, 0.05);
        envRelease = std::exp (-1.0f / (0.3f * sampleRate));
        clickDecay = std::exp (-1.0f / (0.0004f * sampleRate));
        reset();
    }

    void reset() noexcept
    {
        std::fill (bufferL.begin(), bufferL.end(), 0.0f);
        std::fill (bufferR.begin(), bufferR.end(), 0.0f);
        writePos = 0;
        wowPhase = flutterPhase = holdPhase = 0.0f;
        holdL = holdR = 0.0f;
        lp1L = lp2L = lp1R = lp2R = 0.0f;
        envelope = click = 0.0f;
        noise = Noise (0x5eedu);
        amount.setCurrentAndTargetValue (amount.getTargetValue());
    }

    void setAmount (float a) noexcept { amount.setTargetValue (a); }

    void process (float* left, float* right, int numSamples) noexcept
    {
        if (amount.getTargetValue() < 1.0e-4f && ! amount.isSmoothing())
            return;

        const auto twoPi = juce::MathConstants<float>::twoPi;
        const auto msToSamples = sampleRate * 0.001f;

        for (int i = 0; i < numSamples; ++i)
        {
            const auto a = amount.getNextValue();

            // 1. Tape: Wow (0,55 Hz) und Flutter (6,5 Hz) über eine kurze modulierte Verzögerung
            bufferL[static_cast<size_t> (writePos)] = left[i];
            bufferR[static_cast<size_t> (writePos)] = right[i];

            wowPhase += 0.55f / sampleRate;
            flutterPhase += 6.5f / sampleRate;
            if (wowPhase >= 1.0f)     wowPhase -= 1.0f;
            if (flutterPhase >= 1.0f) flutterPhase -= 1.0f;

            const auto delayMs = a * (2.0f + 0.35f * std::sin (twoPi * wowPhase) + 0.03f * std::sin (twoPi * flutterPhase));
            const auto d = std::max (1.0f, delayMs * msToSamples);
            auto l = read (bufferL, d);
            auto r = read (bufferR, d);
            writePos = (writePos + 1) & mask;

            // 2. Sampler: Sample & Hold ohne Anti-Alias-Filter, dann Quantisierung
            const auto targetRate = 44100.0f - 24000.0f * a;
            holdPhase += targetRate / sampleRate;
            if (holdPhase >= 1.0f)
            {
                holdPhase -= std::floor (holdPhase);
                const auto step = std::exp2 (-(15.0f - 6.0f * a));
                holdL = std::round (l / step) * step;
                holdR = std::round (r / step) * step;
            }
            l = holdL;
            r = holdR;

            // 3. Warmer Ausgangstiefpass, 12 dB, 20 kHz → 7 kHz
            const auto fc = std::min (20000.0f * std::exp2 (-1.515f * a), 0.45f * sampleRate);
            const auto t = std::tan (juce::MathConstants<float>::pi * fc / sampleRate);
            const auto g = t / (1.0f + t);
            lp1L += (l - lp1L) * g;  lp2L += (lp1L - lp2L) * g;
            lp1R += (r - lp1R) * g;  lp2R += (lp1R - lp2R) * g;
            l = lp2L;
            r = lp2R;

            // 4. Rauschen und Knistern, folgen dem Signal (bei Stille still)
            const auto level = std::max (std::abs (l), std::abs (r));
            envelope = level > envelope ? level : envelope * envRelease;
            const auto gate = std::min (1.0f, envelope * 8.0f);

            if (noise.next() > 1.0f - 2.0f * (a * 5.0f / sampleRate))
                click = (0.5f + 0.5f * std::abs (noise.next())) * 0.12f;
            click *= clickDecay;

            const auto hiss = 0.0025f * noise.next();
            const auto grain = a * gate * (hiss + click * (noise.next() > 0.0f ? 1.0f : -1.0f));
            left[i]  = l + grain;
            right[i] = r + grain * 0.8f;
        }
    }

private:
    float read (const std::vector<float>& buffer, float delaySamples) const noexcept
    {
        const auto pos  = static_cast<float> (writePos) - delaySamples;
        const auto base = static_cast<int> (std::floor (pos));
        const auto frac = pos - static_cast<float> (base);
        const auto x0 = buffer[static_cast<size_t> (base & mask)];
        const auto x1 = buffer[static_cast<size_t> ((base + 1) & mask)];
        return x0 + frac * (x1 - x0);
    }

    float sampleRate = 44100.0f;
    std::vector<float> bufferL, bufferR;
    int mask = 0, writePos = 0;

    float wowPhase = 0.0f, flutterPhase = 0.0f, holdPhase = 0.0f;
    float holdL = 0.0f, holdR = 0.0f;
    float lp1L = 0.0f, lp2L = 0.0f, lp1R = 0.0f, lp2R = 0.0f;
    float envelope = 0.0f, envRelease = 0.999f, click = 0.0f, clickDecay = 0.9f;

    Noise noise { 0x5eedu };
    juce::SmoothedValue<float> amount;
};
}
