#pragma once

#include "PluginProcessor.h"

// MVP-Editor: generische Regler, damit alles bedien- und automatisierbar ist.
// Das CONTRABEATZ-UI folgt nach abgestimmtem UI-Konzept (Source/UI/).
class Contra86Editor final : public juce::AudioProcessorEditor
{
public:
    explicit Contra86Editor (Contra86Processor&);

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    juce::GenericAudioProcessorEditor generic;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Contra86Editor)
};
