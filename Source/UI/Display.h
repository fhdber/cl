#pragma once

#include "Theme.h"
#include "ScopeBuffer.h"

#include <juce_audio_processors/juce_audio_processors.h>

class Contra86Processor;

namespace ui
{
// Schwarzes Glas-Display: Preset (Kategorie, Name, Browser), Wertanzeige
// beim Bedienen, Oszilloskop des Ausgangs.
class Display final : public juce::Component, private juce::Timer
{
public:
    explicit Display (Contra86Processor&);

    void showValue (const juce::String& name, const juce::String& value);

    void paint (juce::Graphics&) override;
    void resized() override;
    void mouseDown (const juce::MouseEvent&) override;

private:
    void timerCallback() override;
    void stepPreset (int delta);
    void selectPreset (int index);
    void openPresetMenu();
    juce::String statusText() const;

    Contra86Processor& processor;

    juce::Rectangle<float> nameArea, prevArea, nextArea, scopeArea;
    juce::String valueName, valueText;
    double valueUntil = 0.0;
    int shownProgram = -1;

    std::array<float, 2048> snapshot {};
    juce::Path wave;
};
}
