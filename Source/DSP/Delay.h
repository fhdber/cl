#pragma once

#include "LadderFilter.h"

#include <juce_audio_basics/juce_audio_basics.h>
#include <cmath>
#include <vector>

namespace dsp86
{
// Ping-Pong-Delay als Send: Dry bleibt unverändert, Echos werden addiert.
// Feedback läuft durch Bandpass (120 Hz – 4,5 kHz) und Soft-Clip.
class PingPongDelay
{
public:
    void prepare (double newSampleRate)
    {
        sampleRate = newSampleRate;

        const auto maxSamples = static_cast<int> (std::ceil (4.0 * sampleRate)) + 4;
        int size = 1;
        while (size < maxSamples)
            size <<= 1;

        left.assign (static_cast<size_t> (size), 0.0f);
        right.assign (static_cast<size_t> (size), 0.0f);
        mask = size - 1;

        delaySamples.reset (sampleRate, 0.2);
        feedback.reset (sampleRate, 0.02);
        level.reset (sampleRate, 0.02);

        const auto g = [this] (double hz) { return static_cast<float> (std::tan (juce::MathConstants<double>::pi * hz / sampleRate)); };
        lowpassG  = g (4500.0);
        highpassG = g (120.0);

        reset();
    }

    void reset() noexcept
    {
        std::fill (left.begin(), left.end(), 0.0f);
        std::fill (right.begin(), right.end(), 0.0f);
        writePos = 0;
        lowpassState = 0.0f;
        highpass.reset();
        delaySamples.setCurrentAndTargetValue (delaySamples.getTargetValue());
        feedback.setCurrentAndTargetValue (feedback.getTargetValue());
        level.setCurrentAndTargetValue (level.getTargetValue());
    }

    void setParameters (float seconds, float feedbackAmount, float wetLevel) noexcept
    {
        delaySamples.setTargetValue (std::clamp (seconds, 0.005f, 3.9f) * static_cast<float> (sampleRate));
        feedback.setTargetValue (feedbackAmount);
        level.setTargetValue (wetLevel);
    }

    void process (float* l, float* r, int numSamples) noexcept
    {
        if (level.getCurrentValue() < 1.0e-6f && ! level.isSmoothing() && level.getTargetValue() < 1.0e-6f)
        {
            // Stumm: Puffer trotzdem weiterschreiben, damit beim Aufdrehen nichts Altes erklingt.
            for (int i = 0; i < numSamples; ++i)
            {
                left[static_cast<size_t> (writePos)] = 0.0f;
                right[static_cast<size_t> (writePos)] = 0.0f;
                writePos = (writePos + 1) & mask;
            }
            delaySamples.skip (numSamples);
            feedback.skip (numSamples);
            return;
        }

        for (int i = 0; i < numSamples; ++i)
        {
            const auto d  = delaySamples.getNextValue();
            const auto fb = feedback.getNextValue();
            const auto w  = level.getNextValue();

            const auto echoL = read (left, d);
            const auto echoR = read (right, d);

            auto in = 0.5f * (l[i] + r[i]) + fb * echoR;
            lowpassState += (in - lowpassState) * (lowpassG / (1.0f + lowpassG));
            in = softClip (highpass.process (lowpassState, highpassG));

            left[static_cast<size_t> (writePos)]  = in;
            right[static_cast<size_t> (writePos)] = fb * echoL;
            writePos = (writePos + 1) & mask;

            l[i] += w * echoL;
            r[i] += w * echoR;
        }
    }

private:
    float read (const std::vector<float>& buffer, float delay) const noexcept
    {
        const auto pos  = static_cast<float> (writePos) - delay;
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
    std::vector<float> left, right;
    int mask = 0, writePos = 0;

    float lowpassG = 0.3f, highpassG = 0.01f, lowpassState = 0.0f;
    OnePoleHighpass highpass;

    juce::SmoothedValue<float> delaySamples { 1000.0f }, feedback, level;
};
}
