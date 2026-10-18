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
    juce::ParameterID pid4 (const char* name) { return { name, version4 }; }
    juce::ParameterID pid5 (const char* name) { return { name, version5 }; }

    std::unique_ptr<Float> stepped (const juce::ParameterID& id, const char* name, float min, float max, float def, const char* unit)
    {
        return std::make_unique<Float> (id, name, juce::NormalisableRange<float> { min, max, 1.0f }, def,
                                        Attr().withStringFromValueFunction ([unit] (float v, int)
                                                                            { return (v > 0.0f ? "+" : "") + juce::String (juce::roundToInt (v)) + unit; }));
    }

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
                         percent (pid (id::drift), "Drift", 0.2f),
                         percent (pid4 (id::dust), "Dust", 0.0f));

    auto global = std::make_unique<juce::AudioProcessorParameterGroup> ("global", "VOICE", " | ");
    global->addChild (std::make_unique<Choice> (pid (id::voiceMode), "Voice Mode", juce::StringArray { "Poly", "Mono" }, 0),
                      seconds (pid (id::glide), "Glide", 0.0f, 2.0f, 0.0f, 0.25f),
                      percent (pid (id::velocity), "Velocity", 0.5f),
                      std::make_unique<Float> (pid (id::volume), "Volume", juce::NormalisableRange<float> { -48.0f, 6.0f, 0.1f }, -6.0f,
                                               Attr().withLabel ("dB")));

    auto oscB = std::make_unique<juce::AudioProcessorParameterGroup> ("oscB", "OSC B", " | ");
    oscB->addChild (std::make_unique<Choice> (pid5 (id::oscBWave), "B Wave", juce::StringArray { "Saw", "Square", "Pulse", "Noise" }, 0),
                    stepped (pid5 (id::oscBOctave), "B Octave", -2.0f, 2.0f, 0.0f, " oct"),
                    stepped (pid5 (id::oscBSemi), "B Semi", -12.0f, 12.0f, 0.0f, " st"),
                    stepped (pid5 (id::oscBFine), "B Fine", -50.0f, 50.0f, 7.0f, " ct"),
                    percent (pid5 (id::blend), "Blend A-B", 0.0f));

    auto sub808 = std::make_unique<juce::AudioProcessorParameterGroup> ("sub808", "808", " | ");
    sub808->addChild (percent (pid5 (id::sub808Level), "808 Level", 0.0f),
                      seconds (pid5 (id::subDecay), "808 Decay", 0.05f, 4.0f, 1.2f, 0.8f),
                      percent (pid5 (id::subDrop), "808 Drop", 0.25f),
                      percent (pid5 (id::subDrive), "808 Drive", 0.3f),
                      std::make_unique<Choice> (pid5 (id::subOctave), "808 Octave", juce::StringArray { "0", "-1" }, 1));

    auto dustDetail = std::make_unique<juce::AudioProcessorParameterGroup> ("dustDetail", "DUST", " | ");
    dustDetail->addChild (percent (pid5 (id::dustTape), "Dust Tape", 0.5f),
                          percent (pid5 (id::dustCrush), "Dust Crush", 0.5f),
                          percent (pid5 (id::dustNoise), "Dust Noise", 0.5f),
                          percent (pid5 (id::dustTone), "Dust Tone", 0.5f));

    auto lead = std::make_unique<juce::AudioProcessorParameterGroup> ("lead", "LEAD", " | ");
    lead->addChild (percent (pid5 (id::dist), "Distortion", 0.0f),
                    std::make_unique<juce::AudioParameterBool> (pid5 (id::throwFx), "Throw", false));

    layout.add (std::move (dco), std::move (unison), std::move (vcf), std::move (env1), std::move (env2),
                std::move (lfo), std::move (fx), std::move (character), std::move (global));
    layout.add (std::move (oscB), std::move (sub808), std::move (dustDetail), std::move (lead));
    return layout;
}
}
