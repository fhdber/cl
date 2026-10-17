#include "Parameters.h"

namespace params
{
namespace
{
    using Float  = juce::AudioParameterFloat;
    using Choice = juce::AudioParameterChoice;
    using Attr   = juce::AudioParameterFloatAttributes;

    juce::ParameterID pid (const char* name)  { return { name, version }; }
    juce::ParameterID pid2 (const char* name) { return { name, version2 }; }
    juce::ParameterID pid3 (const char* name) { return { name, version3 }; }

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

    std::unique_ptr<Float> percent (const juce::ParameterID& id, const char* name, float def, float min = 0.0f, float max = 1.0f)
    {
        return std::make_unique<Float> (id, name, juce::NormalisableRange<float> { min, max }, def,
                                        Attr().withStringFromValueFunction (formatPercent)
                                              .withValueFromStringFunction (parsePercent));
    }

    std::unique_ptr<Float> frequency (const char* id, const char* name, float min, float max, float def, float centre)
    {
        return std::make_unique<Float> (pid (id), name, skewed (min, max, centre), def,
                                        Attr().withStringFromValueFunction (formatHz));
    }

    std::unique_ptr<Float> seconds (const juce::ParameterID& id, const char* name, float min, float max, float def, float centre)
    {
        return std::make_unique<Float> (id, name, skewed (min, max, centre), def,
                                        Attr().withStringFromValueFunction (formatSeconds)
                                              .withValueFromStringFunction (parseSeconds));
    }
}

juce::AudioProcessorValueTreeState::ParameterLayout createLayout()
{
    juce::AudioProcessorValueTreeState::ParameterLayout layout;

    auto dco = std::make_unique<juce::AudioProcessorParameterGroup> ("dco", "DCO", " | ");
    dco->addChild (std::make_unique<Choice> (pid (id::range), "Range", juce::StringArray { "16'", "8'", "4'" }, 1),
                   percent (pid (id::pw), "Pulse Width", 0.0f),
                   std::make_unique<Choice> (pid (id::pwmSource), "PWM Source", juce::StringArray { "LFO", "Manual", "Env" }, 1),
                   percent (pid (id::sawLevel), "Saw", 1.0f),
                   percent (pid (id::pulseLevel), "Pulse", 0.0f),
                   percent (pid (id::subLevel), "Sub", 0.0f),
                   percent (pid (id::noiseLevel), "Noise", 0.0f),
                   percent (pid (id::lfoPitch), "LFO > Pitch", 0.0f));

    auto unison = std::make_unique<juce::AudioProcessorParameterGroup> ("unison", "UNISON", " | ");
    unison->addChild (std::make_unique<Choice> (pid2 (id::unison), "Unison", juce::StringArray { "Off", "3", "5", "7" }, 0),
                      percent (pid2 (id::unisonDetune), "Detune", 0.3f),
                      percent (pid2 (id::unisonWidth), "Width", 0.7f));

    auto vcf = std::make_unique<juce::AudioProcessorParameterGroup> ("vcf", "VCF", " | ");
    vcf->addChild (frequency (id::hpf, "HPF", 20.0f, 2000.0f, 20.0f, 200.0f),
                   frequency (id::cutoff, "Cutoff", 20.0f, 20000.0f, 8000.0f, 630.0f),
                   percent (pid (id::resonance), "Resonance", 0.1f),
                   percent (pid (id::envAmount), "Env 1 > Filter", 0.0f, -1.0f),
                   percent (pid (id::lfoFilter), "LFO > Filter", 0.0f),
                   percent (pid (id::keyTrack), "Key Track", 0.5f));

    auto env1 = std::make_unique<juce::AudioProcessorParameterGroup> ("env", "ENV 1 (Filter)", " | ");
    env1->addChild (seconds (pid (id::attack), "Env 1 Attack", 0.001f, 5.0f, 0.005f, 0.3f),
                    seconds (pid (id::decay), "Env 1 Decay", 0.001f, 10.0f, 0.4f, 0.6f),
                    percent (pid (id::sustain), "Env 1 Sustain", 0.8f),
                    seconds (pid (id::release), "Env 1 Release", 0.001f, 10.0f, 0.3f, 0.6f));

    // Reihenfolge der VCA-Auswahl bleibt v1-kompatibel: Env 2 kommt hinten dazu.
    auto env2 = std::make_unique<juce::AudioProcessorParameterGroup> ("env2", "ENV 2 (Amp)", " | ");
    env2->addChild (std::make_unique<Choice> (pid (id::vcaMode), "VCA Mode", juce::StringArray { "Env 1", "Gate", "Env 2" }, 2),
                    seconds (pid2 (id::ampAttack), "Env 2 Attack", 0.001f, 5.0f, 0.005f, 0.3f),
                    seconds (pid2 (id::ampDecay), "Env 2 Decay", 0.001f, 10.0f, 0.4f, 0.6f),
                    percent (pid2 (id::ampSustain), "Env 2 Sustain", 0.8f),
                    seconds (pid2 (id::ampRelease), "Env 2 Release", 0.001f, 10.0f, 0.3f, 0.6f));

    auto lfo = std::make_unique<juce::AudioProcessorParameterGroup> ("lfo", "LFO", " | ");
    lfo->addChild (frequency (id::lfoRate, "LFO Rate", 0.1f, 30.0f, 3.0f, 3.0f),
                   seconds (pid (id::lfoDelay), "LFO Delay", 0.0f, 5.0f, 0.0f, 0.8f));

    auto fx = std::make_unique<juce::AudioProcessorParameterGroup> ("fx", "FX", " | ");
    fx->addChild (std::make_unique<Choice> (pid (id::chorus), "Chorus", juce::StringArray { "Off", "I", "II", "I+II" }, 1),
                  std::make_unique<Choice> (pid2 (id::delayTime), "Delay Time",
                                            juce::StringArray { "1/16", "1/8T", "1/8", "1/8.", "1/4T", "1/4", "1/4.", "1/2" }, 3),
                  percent (pid2 (id::delayFeedback), "Delay Feedback", 0.35f, 0.0f, 0.9f),
                  percent (pid2 (id::delayMix), "Delay Level", 0.0f),
                  percent (pid2 (id::reverbSize), "Reverb Size", 0.6f),
                  percent (pid2 (id::reverbMix), "Reverb Level", 0.0f),
                  std::make_unique<Choice> (pid3 (id::phaser), "Phaser", juce::StringArray { "Off", "Slow", "Fast" }, 0),
                  percent (pid3 (id::phaserMix), "Phaser Depth", 0.6f));

    auto character = std::make_unique<juce::AudioProcessorParameterGroup> ("character", "CHARACTER", " | ");
    character->addChild (percent (pid3 (id::drive), "Drive", 0.0f),
                         percent (pid3 (id::tube), "Tube", 0.0f),
                         percent (pid (id::drift), "Drift", 0.2f));

    auto global = std::make_unique<juce::AudioProcessorParameterGroup> ("global", "VOICE", " | ");
    global->addChild (std::make_unique<Choice> (pid (id::voiceMode), "Voice Mode", juce::StringArray { "Poly", "Mono" }, 0),
                      seconds (pid (id::glide), "Glide", 0.0f, 2.0f, 0.0f, 0.25f),
                      percent (pid (id::velocity), "Velocity", 0.5f),
                      std::make_unique<Float> (pid (id::volume), "Volume", juce::NormalisableRange<float> { -48.0f, 6.0f, 0.1f }, -6.0f,
                                               Attr().withLabel ("dB")));

    layout.add (std::move (dco), std::move (unison), std::move (vcf), std::move (env1), std::move (env2),
                std::move (lfo), std::move (fx), std::move (character), std::move (global));
    return layout;
}
}
