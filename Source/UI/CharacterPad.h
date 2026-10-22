#pragma once

#include "Controls.h"

namespace ui
{
// XY-Feld: ein Puck steuert zwei Parameter (X = Dust, Y = Heat/Tube).
// Punktraster leuchtet um den Puck in den Funktionsfarben.
// Ziehen = beide Werte, Shift = fein, Doppelklick = beide auf Default.
class CharacterPad final : public juce::Component
{
public:
    CharacterPad (juce::AudioProcessorValueTreeState&, const juce::String& xParam, const juce::String& yParam,
                  ShowParameter show);

    void paint (juce::Graphics&) override;
    void mouseDown (const juce::MouseEvent&) override;
    void mouseDrag (const juce::MouseEvent&) override;
    void mouseUp (const juce::MouseEvent&) override;
    void mouseDoubleClick (const juce::MouseEvent&) override;

private:
    juce::Rectangle<float> field() const;
    void setFromPosition (juce::Point<float>);

    juce::RangedAudioParameter& xParameter;
    juce::RangedAudioParameter& yParameter;
    ShowParameter show;
    float x = 0.0f, y = 0.0f; // normalisiert 0 … 1
    juce::Point<float> lastPosition, virtualPosition;
    juce::ParameterAttachment xAttachment, yAttachment;
};
}
