#pragma once

#include <cmath>

namespace dsp86
{
struct AdsrTimes
{
    float attack, decay, sustain, release;
};

struct AdsrCoefs
{
    float attack = 1.0f, decay = 0.0f, sustain = 1.0f, release = 0.0f;

    // Attack: Zeit bis 1,0 (Ziel 1,3 wie bei RC-Hüllkurven).
    // Decay/Release: Zeit bis −60 dB Abstand zum Ziel.
    static AdsrCoefs make (float attackS, float decayS, float sustainLevel, float releaseS, double sampleRate) noexcept
    {
        const auto sr = static_cast<float> (sampleRate);
        constexpr auto attackLog = 1.46633707f; // ln (1.3 / 0.3)
        constexpr auto decayLog  = 6.90775528f; // ln (1000)

        AdsrCoefs c;
        c.attack  = 1.0f - std::exp (-attackLog / (attackS * sr));
        c.decay   = std::exp (-decayLog / (decayS * sr));
        c.sustain = sustainLevel;
        c.release = std::exp (-decayLog / (releaseS * sr));
        return c;
    }
};

class Envelope
{
public:
    void gateOn() noexcept  { stage = Stage::attack; }
    void gateOff() noexcept { if (stage != Stage::idle) stage = Stage::release; }
    void reset() noexcept   { value = 0.0f; stage = Stage::idle; }

    bool isActive() const noexcept { return stage != Stage::idle; }
    float getValue() const noexcept { return value; }

    float next (const AdsrCoefs& c) noexcept
    {
        switch (stage)
        {
            case Stage::attack:
                value += (1.3f - value) * c.attack;
                if (value >= 1.0f)
                {
                    value = 1.0f;
                    stage = Stage::decay;
                }
                break;

            case Stage::decay:
                value = c.sustain + (value - c.sustain) * c.decay;
                break;

            case Stage::release:
                value *= c.release;
                if (value < 1.0e-5f)
                    reset();
                break;

            case Stage::idle:
                break;
        }

        return value;
    }

private:
    enum class Stage { idle, attack, decay, release };

    float value = 0.0f;
    Stage stage = Stage::idle;
};
}
