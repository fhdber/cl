#pragma once

#include "Theme.h"

#include <juce_audio_processors/juce_audio_processors.h>

namespace ui
{
// Meldet Parametername und Wert ans Display (Hover, Drehen, Umschalten).
using ShowValue = std::function<void (const juce::String& name, const juce::String& value)>;

// Slider mit Feinjustierung: Shift oder Cmd beim Ziehen = ×0,15.
class FineSlider final : public juce::Slider
{
public:
    FineSlider();

    void mouseDown (const juce::MouseEvent&) override;
    void mouseDrag (const juce::MouseEvent&) override;
    void mouseEnter (const juce::MouseEvent&) override;

    std::function<void()> onHover;

private:
    juce::Point<float> lastPosition, virtualPosition;
};

class Knob final : public juce::Component
{
public:
    Knob (juce::AudioProcessorValueTreeState&, const juce::String& paramId, const juce::String& label,
          ShowValue show, bool hero = false);

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    void report();

    juce::RangedAudioParameter& parameter;
    juce::String label;
    ShowValue show;
    FineSlider slider;
    juce::AudioProcessorValueTreeState::SliderAttachment attachment;
};

// Segment-Pillen für Auswahl-Parameter.
class SegmentedControl final : public juce::Component
{
public:
    SegmentedControl (juce::AudioProcessorValueTreeState&, const juce::String& paramId,
                      juce::StringArray labels, ShowValue show);

    void paint (juce::Graphics&) override;
    void mouseDown (const juce::MouseEvent&) override;

private:
    juce::Rectangle<float> segmentBounds (int index) const;

    juce::RangedAudioParameter& parameter;
    juce::StringArray labels;
    ShowValue show;
    int selected = 0;
    juce::ParameterAttachment attachment;
};
}
