#pragma once

#include "DSP/SynthEngine.h"
#include "ScopeBuffer.h"

#include <juce_audio_processors/juce_audio_processors.h>

class Contra86Processor final : public juce::AudioProcessor
{
public:
    Contra86Processor();

    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override {}
    void reset() override;

    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;
    using AudioProcessor::processBlock;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    const juce::String getName() const override { return JucePlugin_Name; }
    bool acceptsMidi() const override  { return true; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 10.0; }

    int getNumPrograms() override;
    int getCurrentProgram() override { return currentProgram; }
    void setCurrentProgram (int index) override;
    const juce::String getProgramName (int index) override;
    void changeProgramName (int, const juce::String&) override {}

    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    juce::AudioProcessorValueTreeState state;
    ScopeBuffer scope;

private:
    dsp86::Settings readSettings() const noexcept;
    double hostBpm() const noexcept;

    struct Raw
    {
        std::atomic<float>* range; std::atomic<float>* pw; std::atomic<float>* pwmSource;
        std::atomic<float>* saw; std::atomic<float>* pulse; std::atomic<float>* sub; std::atomic<float>* noise;
        std::atomic<float>* lfoPitch; std::atomic<float>* hpf; std::atomic<float>* cutoff; std::atomic<float>* resonance;
        std::atomic<float>* envAmount; std::atomic<float>* lfoFilter; std::atomic<float>* keyTrack;
        std::atomic<float>* attack; std::atomic<float>* decay; std::atomic<float>* sustain; std::atomic<float>* release;
        std::atomic<float>* vcaMode; std::atomic<float>* lfoRate; std::atomic<float>* lfoDelay; std::atomic<float>* chorus;
        std::atomic<float>* voiceMode; std::atomic<float>* glide; std::atomic<float>* drift; std::atomic<float>* velocity;
        std::atomic<float>* volume;
        std::atomic<float>* unison; std::atomic<float>* unisonDetune; std::atomic<float>* unisonWidth;
        std::atomic<float>* ampAttack; std::atomic<float>* ampDecay; std::atomic<float>* ampSustain; std::atomic<float>* ampRelease;
        std::atomic<float>* delayTime; std::atomic<float>* delayFeedback; std::atomic<float>* delayMix;
        std::atomic<float>* reverbSize; std::atomic<float>* reverbMix;
        std::atomic<float>* drive; std::atomic<float>* tube; std::atomic<float>* phaser; std::atomic<float>* phaserMix;
        std::atomic<float>* dust;
    } raw;

    dsp86::SynthEngine engine;
    int currentProgram = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Contra86Processor)
};
