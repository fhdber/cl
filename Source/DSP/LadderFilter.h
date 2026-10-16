#pragma once

#include <algorithm>
#include <cmath>

namespace dsp86
{
// Weiche Sättigung, tanh-ähnlich, ohne teure Exponentialfunktion.
inline float softClip (float x) noexcept
{
    x = std::clamp (x, -3.0f, 3.0f);
    const auto x2 = x * x;
    return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

// 24-dB-Tiefpass, vier TPT-Einpolstufen mit Zero-Delay-Feedback.
// Sättigung am Eingang der Kaskade begrenzt die Resonanz musikalisch.
class LadderFilter
{
public:
    void reset() noexcept { s[0] = s[1] = s[2] = s[3] = 0.0f; }

    // g = tan(pi * fc / fs), resonance 0..1
    float process (float x, float g, float resonance) noexcept
    {
        const auto k    = resonance * 4.1f;
        const auto G    = g / (1.0f + g);
        const auto beta = 1.0f / (1.0f + g);
        const auto G2   = G * G;

        const auto feedbackEstimate = (G2 * G * s[0] + G2 * s[1] + G * s[2] + s[3]) * beta;

        auto u = (x - k * feedbackEstimate) / (1.0f + k * G2 * G2);
        u = softClip (u);

        for (auto& state : s)
        {
            const auto v = (u - state) * G;
            const auto y = v + state;
            state = y + v;
            u = y;
        }

        return u * (1.0f + 0.5f * k);
    }

private:
    float s[4] {};
};

// Einpoliger TPT-Hochpass für den globalen HPF.
class OnePoleHighpass
{
public:
    void reset() noexcept { s = 0.0f; }

    float process (float x, float g) noexcept
    {
        const auto v  = (x - s) * (g / (1.0f + g));
        const auto lp = v + s;
        s = lp + v;
        return x - lp;
    }

private:
    float s = 0.0f;
};
}
