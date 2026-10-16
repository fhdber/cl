#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "Parameters.h"
#include "Presets.h"

namespace
{
    const juce::Identifier programAttribute { "program" };
}

Contra86Processor::Contra86Processor()
    : AudioProcessor (BusesProperties().withOutput ("Output", juce::AudioChannelSet::stereo(), true)),
      state (*this, nullptr, "CONTRA86", params::createLayout())
{
    auto get = [this] (const char* id) { return state.getRawParameterValue (id); };

    namespace id = params::id;
    raw = { get (id::range), get (id::pw), get (id::pwmSource),
            get (id::sawLevel), get (id::pulseLevel), get (id::subLevel), get (id::noiseLevel),
            get (id::lfoPitch), get (id::hpf), get (id::cutoff), get (id::resonance),
            get (id::envAmount), get (id::lfoFilter), get (id::keyTrack),
            get (id::attack), get (id::decay), get (id::sustain), get (id::release),
            get (id::vcaMode), get (id::lfoRate), get (id::lfoDelay), get (id::chorus),
            get (id::voiceMode), get (id::glide), get (id::drift), get (id::velocity),
            get (id::volume),
            get (id::unison), get (id::unisonDetune), get (id::unisonWidth),
            get (id::ampAttack), get (id::ampDecay), get (id::ampSustain), get (id::ampRelease),
            get (id::delayTime), get (id::delayFeedback), get (id::delayMix),
            get (id::reverbSize), get (id::reverbMix) };
}

bool Contra86Processor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    const auto out = layouts.getMainOutputChannelSet();
    return layouts.getMainInputChannelSet().isDisabled()
        && (out == juce::AudioChannelSet::mono() || out == juce::AudioChannelSet::stereo());
}

void Contra86Processor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    engine.prepare (sampleRate, samplesPerBlock, readSettings());
    setLatencySamples (engine.getLatencySamples());
}

void Contra86Processor::reset()
{
    engine.reset();
}

dsp86::Settings Contra86Processor::readSettings() const noexcept
{
    auto value = [] (const std::atomic<float>* p) { return p->load (std::memory_order_relaxed); };
    auto index = [value] (const std::atomic<float>* p) { return juce::roundToInt (value (p)); };

    dsp86::Settings s;
    s.octave     = index (raw.range) - 1;
    s.pw         = value (raw.pw);
    s.pwmSource  = static_cast<dsp86::PwmSource> (index (raw.pwmSource));
    s.saw        = value (raw.saw);
    s.pulse      = value (raw.pulse);
    s.sub        = value (raw.sub);
    s.noise      = value (raw.noise);
    s.lfoPitch   = value (raw.lfoPitch);
    s.hpfHz      = value (raw.hpf);
    s.cutoffHz   = value (raw.cutoff);
    s.resonance  = value (raw.resonance);
    s.envAmount  = value (raw.envAmount);
    s.lfoFilter  = value (raw.lfoFilter);
    s.keyTrack   = value (raw.keyTrack);
    s.attack     = value (raw.attack);
    s.decay      = value (raw.decay);
    s.sustain    = value (raw.sustain);
    s.release    = value (raw.release);
    s.vcaMode    = static_cast<dsp86::VcaMode> (index (raw.vcaMode));
    s.lfoRate    = value (raw.lfoRate);
    s.lfoDelay   = value (raw.lfoDelay);
    s.chorus     = static_cast<dsp86::Chorus::Mode> (index (raw.chorus));
    s.voiceMode  = static_cast<dsp86::VoiceMode> (index (raw.voiceMode));
    s.glide      = value (raw.glide);
    s.drift      = value (raw.drift);
    s.velocity   = value (raw.velocity);
    s.volumeDb   = value (raw.volume);

    constexpr int unisonVoices[] = { 1, 3, 5, 7 };
    constexpr float delayBeats[] = { 0.25f, 1.0f / 3.0f, 0.5f, 0.75f, 2.0f / 3.0f, 1.0f, 1.5f, 2.0f };

    s.unison        = unisonVoices[juce::jlimit (0, 3, index (raw.unison))];
    s.unisonDetune  = value (raw.unisonDetune);
    s.unisonWidth   = value (raw.unisonWidth);
    s.ampAttack     = value (raw.ampAttack);
    s.ampDecay      = value (raw.ampDecay);
    s.ampSustain    = value (raw.ampSustain);
    s.ampRelease    = value (raw.ampRelease);
    s.delayBeats    = delayBeats[juce::jlimit (0, 7, index (raw.delayTime))];
    s.delayFeedback = value (raw.delayFeedback);
    s.delayMix      = value (raw.delayMix);
    s.reverbSize    = value (raw.reverbSize);
    s.reverbMix     = value (raw.reverbMix);
    return s;
}

double Contra86Processor::hostBpm() const noexcept
{
    if (auto* ph = getPlayHead())
        if (const auto position = ph->getPosition())
            if (const auto bpm = position->getBpm())
                return *bpm;

    return 120.0;
}

void Contra86Processor::processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    juce::ScopedNoDenormals noDenormals;
    auto settings = readSettings();
    settings.bpm = hostBpm();
    engine.process (buffer, midi, settings);
    scope.push (buffer.getReadPointer (0), buffer.getNumChannels() > 1 ? buffer.getReadPointer (1) : nullptr,
                buffer.getNumSamples());
    midi.clear();
}

juce::AudioProcessorEditor* Contra86Processor::createEditor()
{
    return new Contra86Editor (*this);
}

int Contra86Processor::getNumPrograms()
{
    return presets::count();
}

void Contra86Processor::setCurrentProgram (int index)
{
    if (! juce::isPositiveAndBelow (index, presets::count()))
        return;

    currentProgram = index;
    presets::apply (state, index);
}

const juce::String Contra86Processor::getProgramName (int index)
{
    return presets::fullName (index);
}

void Contra86Processor::getStateInformation (juce::MemoryBlock& destData)
{
    auto tree = state.copyState();
    tree.setProperty (programAttribute, currentProgram, nullptr);

    if (auto xml = tree.createXml())
        copyXmlToBinary (*xml, destData);
}

void Contra86Processor::setStateInformation (const void* data, int sizeInBytes)
{
    const auto xml = getXmlFromBinary (data, sizeInBytes);
    if (xml == nullptr || ! xml->hasTagName (state.state.getType()))
        return;

    auto tree = juce::ValueTree::fromXml (*xml);
    currentProgram = juce::jlimit (0, presets::count() - 1, static_cast<int> (tree.getProperty (programAttribute, 0)));
    state.replaceState (tree);
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new Contra86Processor();
}
