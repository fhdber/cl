#pragma once

#include <cstdint>

namespace dsp86
{
// Bandbegrenzte Korrektur für harte Sprünge (PolyBLEP). Läuft auf 2× Rate,
// damit bleiben Aliasing-Reste weit unter der Hörschwelle.
inline float polyBlep (float t, float dt) noexcept
{
    if (t < dt)
    {
        t /= dt;
        return t + t - t * t - 1.0f;
    }

    if (t > 1.0f - dt)
    {
        t = (t - 1.0f) / dt;
        return t * t + t + t + 1.0f;
    }

    return 0.0f;
}

inline float wrap01 (float x) noexcept { return x >= 1.0f ? x - 1.0f : x; }

// Juno-artiger DCO: Saw, Pulse und Sub teilen sich eine Phase, der Sub ist
// phasenstarr eine Oktave tiefer.
class Dco
{
public:
    struct Output { float saw, pulse, sub; };

    void reset (float startPhase) noexcept
    {
        phase = startPhase;
        subHigh = false;
    }

    Output next (float inc, float duty) noexcept
    {
        phase += inc;

        if (phase >= 1.0f)
        {
            phase -= 1.0f;
            subHigh = ! subHigh;
        }

        const auto t = phase;

        const auto saw = 2.0f * t - 1.0f - polyBlep (t, inc);

        auto pulse = t < duty ? 1.0f : -1.0f;
        pulse += polyBlep (t, inc) - polyBlep (wrap01 (t + 1.0f - duty), inc);
        pulse -= 2.0f * duty - 1.0f;

        const auto subInc   = inc * 0.5f;
        const auto subPhase = (t + (subHigh ? 1.0f : 0.0f)) * 0.5f;
        auto sub = subPhase < 0.5f ? 1.0f : -1.0f;
        sub += polyBlep (subPhase, subInc) - polyBlep (wrap01 (subPhase + 0.5f), subInc);

        return { saw, pulse, sub };
    }

private:
    float phase = 0.0f;
    bool subHigh = false;
};

class Noise
{
public:
    explicit Noise (uint32_t seed = 0x9e3779b9u) noexcept : state (seed | 1u) {}

    float next() noexcept
    {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return static_cast<float> (static_cast<int32_t> (state)) * (1.0f / 2147483648.0f);
    }

private:
    uint32_t state;
};
}
