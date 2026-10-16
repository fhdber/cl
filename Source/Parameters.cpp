#include "Parameters.h"

namespace params
{
namespace
{
    using Float  = juce::AudioParameterFloat;
    using Choice = juce::AudioParameterChoice;
    using Attr   = juce::AudioParameterFloatAttributes;

    juce::ParameterID pid (const char* name) { return { name, version }; }

    juce::String formatPercent (float v, int)   { return juce::String (juce::roundToInt (v * 100.0f)) + " %"; }
    float parsePercent (const juce::String& t)  { return t.getFloatValue() / 100.0f; }

    juce::String formatHz (float v, int)
    {
        return v >= 1000.0f ? juce::String (v / 1000.0f, 2) + " kHz"
                            : juce::String (v, v < 10.0f ? 2 : 0) + " Hz";
    }

    juce::String formatSeconds (float v, int)
    {
        return v < 1.0f ? juce::String (juce::roundToInt (v * 1000.0f)) + " ms"
                        : juce::String (v, 2) + " s";
    }

    float parseSeconds (const juce::String& t)
    {
        const auto value = t.getFloatValue();
        return t.containsIgnoreCase ("ms") ? value / 1000.0f : value;
    }

    juce::NormalisableRange<float> skewed (float min, float max, float centre)
    {
        juce::NormalisableRange<float> r { min, max };
        r.setSkewForCentre (centre);
        return r;
    }

    std::unique_ptr<Float> percent (const char* id, const char* name, float def, float min = 0.0f)
    {
        return std::make_unique<Float> (pid (id), name, juce::NormalisableRange<float> { min, 1.0f }, def,
                                        Attr().withStringFromValueFunction (formatPercent)
                                              .withValueFromStringFunction (parsePercent));
    }

    std::unique_ptr<Float> frequency (const char* id, const char* name, float min, float max, float def, float centre)
    {
        return std::make_unique<Float> (pid (id), name, skewed (min, max, centre), def,
                                        Attr().withStringFromValueFunction (formatHz));
    }

    std::unique_ptr<Float> seconds (const char* id, const char* name, float min, float max, float def, float centre)
    {
        return std::make_unique<Float> (pid (id), name, skewed (min, max, centre), def,
                                        Attr().withStringFromValueFunction (formatSeconds)
                                              .withValueFromStringFunction (parseSeconds));
    }
}

juce::AudioProcessorValueTreeState::ParameterLayout createLayout()
{
    juce::AudioProcessorValueTreeState::ParameterLayout layout;

    auto dco = std::make_unique<juce::AudioProcessorParameterGroup> ("dco", "DCO", " | ");
    dco->addChild (std::make_unique<Choice> (pid (id::range), "Range", juce::StringArray { "16'", "8'", "4'" }, 1),
                   percent (id::pw, "Pulse Width", 0.0f),
                   std::make_unique<Choice> (pid (id::pwmSource), "PWM Source", juce::StringArray { "LFO", "Manual", "Env" }, 1),
                   percent (id::sawLevel, "Saw", 1.0f),
                   percent (id::pulseLevel, "Pulse", 0.0f),
                   percent (id::subLevel, "Sub", 0.0f),
                   percent (id::noiseLevel, "Noise", 0.0f),
                   percent (id::lfoPitch, "LFO > Pitch", 0.0f));

    auto vcf = std::make_unique<juce::AudioProcessorParameterGroup> ("vcf", "VCF", " | ");
    vcf->addChild (frequency (id::hpf, "HPF", 20.0f, 2000.0f, 20.0f, 200.0f),
                   frequency (id::cutoff, "Cutoff", 20.0f, 20000.0f, 8000.0f, 630.0f),
                   percent (id::resonance, "Resonance", 0.1f),
                   percent (id::envAmount, "Env > Filter", 0.0f, -1.0f),
                   percent (id::lfoFilter, "LFO > Filter", 0.0f),
                   percent (id::keyTrack, "Key Track", 0.5f));

    auto env = std::make_unique<juce::AudioProcessorParameterGroup> ("env", "ENV", " | ");
    env->addChild (seconds (id::attack, "Attack", 0.001f, 5.0f, 0.005f, 0.3f),
                   seconds (id::decay, "Decay", 0.001f, 10.0f, 0.4f, 0.6f),
                   percent (id::sustain, "Sustain", 0.8f),
                   seconds (id::release, "Release", 0.001f, 10.0f, 0.3f, 0.6f),
                   std::make_unique<Choice> (pid (id::vcaMode), "VCA Mode", juce::StringArray { "Env", "Gate" }, 0));

    auto lfo = std::make_unique<juce::AudioProcessorParameterGroup> ("lfo", "LFO", " | ");
    lfo->addChild (frequency (id::lfoRate, "LFO Rate", 0.1f, 30.0f, 3.0f, 3.0f),
                   seconds (id::lfoDelay, "LFO Delay", 0.0f, 5.0f, 0.0f, 0.8f));

    auto global = std::make_unique<juce::AudioProcessorParameterGroup> ("global", "Global", " | ");
    global->addChild (std::make_unique<Choice> (pid (id::chorus), "Chorus", juce::StringArray { "Off", "I", "II", "I+II" }, 1),
                      std::make_unique<Choice> (pid (id::voiceMode), "Voice Mode", juce::StringArray { "Poly", "Mono" }, 0),
                      seconds (id::glide, "Glide", 0.0f, 2.0f, 0.0f, 0.25f),
                      percent (id::drift, "Drift", 0.2f),
                      percent (id::velocity, "Velocity", 0.5f),
                      std::make_unique<Float> (pid (id::volume), "Volume", juce::NormalisableRange<float> { -48.0f, 6.0f, 0.1f }, -6.0f,
                                               Attr().withLabel ("dB")));

    layout.add (std::move (dco), std::move (vcf), std::move (env), std::move (lfo), std::move (global));
    return layout;
}
}
