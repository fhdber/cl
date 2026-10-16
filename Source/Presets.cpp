#include "Presets.h"
#include "Parameters.h"

namespace presets
{
namespace
{
    namespace id = params::id;

    struct Value { const char* id; float value; };

    struct Preset
    {
        const char* name;
        std::initializer_list<Value> values;
    };

    // Werte in Parametereinheiten: % als 0..1, Zeiten in s, Frequenzen in Hz,
    // Auswahl-Parameter als Index.
    const Preset factory[] =
    {
        { "Init", {} },

        { "Juno Pad", { { id::pulseLevel, 0.7f }, { id::pw, 0.6f }, { id::pwmSource, 0.0f },
                        { id::lfoRate, 0.5f }, { id::lfoFilter, 0.08f },
                        { id::cutoff, 2500.0f }, { id::resonance, 0.15f }, { id::envAmount, 0.1f },
                        { id::attack, 0.9f }, { id::decay, 2.0f }, { id::sustain, 0.85f }, { id::release, 1.6f },
                        { id::drift, 0.3f }, { id::velocity, 0.3f }, { id::chorus, 1.0f } } },

        { "Saw Bass", { { id::voiceMode, 1.0f }, { id::glide, 0.04f }, { id::subLevel, 0.8f },
                        { id::cutoff, 220.0f }, { id::resonance, 0.35f }, { id::envAmount, 0.45f },
                        { id::keyTrack, 0.3f },
                        { id::attack, 0.002f }, { id::decay, 0.35f }, { id::sustain, 0.25f }, { id::release, 0.08f },
                        { id::drift, 0.15f }, { id::velocity, 0.6f }, { id::chorus, 0.0f }, { id::volume, 0.0f } } },

        { "Brass Stab", { { id::cutoff, 600.0f }, { id::resonance, 0.12f }, { id::envAmount, 0.55f },
                          { id::keyTrack, 0.6f },
                          { id::attack, 0.04f }, { id::decay, 0.6f }, { id::sustain, 0.55f }, { id::release, 0.25f },
                          { id::lfoRate, 5.5f }, { id::lfoDelay, 0.6f }, { id::lfoPitch, 0.15f },
                          { id::velocity, 0.6f }, { id::chorus, 2.0f } } },

        { "House Pluck", { { id::sawLevel, 0.6f }, { id::pulseLevel, 0.8f }, { id::pw, 0.35f },
                           { id::hpf, 120.0f }, { id::cutoff, 400.0f }, { id::resonance, 0.3f },
                           { id::envAmount, 0.5f }, { id::keyTrack, 0.7f },
                           { id::attack, 0.001f }, { id::decay, 0.28f }, { id::sustain, 0.0f }, { id::release, 0.25f },
                           { id::vcaMode, 1.0f }, { id::chorus, 3.0f } } },
    };

    void set (juce::RangedAudioParameter& p, float normalised)
    {
        p.beginChangeGesture();
        p.setValueNotifyingHost (normalised);
        p.endChangeGesture();
    }
}

int count() { return static_cast<int> (std::size (factory)); }

juce::String name (int index)
{
    return juce::isPositiveAndBelow (index, count()) ? factory[index].name : "";
}

void apply (juce::AudioProcessorValueTreeState& state, int index)
{
    if (! juce::isPositiveAndBelow (index, count()))
        return;

    for (auto* p : state.processor.getParameters())
        if (auto* ranged = dynamic_cast<juce::RangedAudioParameter*> (p))
            set (*ranged, ranged->getDefaultValue());

    for (const auto& v : factory[index].values)
        if (auto* p = state.getParameter (v.id))
            set (*p, p->convertTo0to1 (v.value));
}
}
