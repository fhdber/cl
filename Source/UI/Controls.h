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

// Segment-Pillen; Grundlage für Parameter-Auswahl und Theme-Schalter.
class Segments : public juce::Component
{
public:
    explicit Segments (juce::StringArray labels);

    void paint (juce::Graphics&) override;
    void mouseDown (const juce::MouseEvent&) override;

    void setSelected (int index);
    int getSelected() const noexcept { return selected; }
    int getNaturalWidth() const;

    std::function<void (int)> onSelect;

private:
    juce::Rectangle<float> segmentBounds (int index) const;

    juce::StringArray labels;
    int selected = 0;
};

// Segment-Pillen für Auswahl-Parameter.
class SegmentedControl final : public Segments
{
public:
    SegmentedControl (juce::AudioProcessorValueTreeState&, const juce::String& paramId,
                      juce::StringArray labels, ShowValue show);

private:
    juce::RangedAudioParameter& parameter;
    ShowValue show;
    juce::ParameterAttachment attachment;
};

// Horizontaler Crossfader A–B (Blend) mit Schiebekappe.
class Crossfader final : public juce::Component
{
public:
    Crossfader (juce::AudioProcessorValueTreeState&, const juce::String& paramId, ShowValue show);

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    class Track final : public juce::Slider
    {
    public:
        Track();
        void paint (juce::Graphics&) override;
        void mouseDrag (const juce::MouseEvent&) override;
        void mouseDown (const juce::MouseEvent&) override;
        void mouseEnter (const juce::MouseEvent&) override;
        std::function<void()> onHover;

    private:
        juce::Point<float> lastPosition, virtualPosition;
    };

    void report();

    juce::RangedAudioParameter& parameter;
    ShowValue show;
    Track slider;
    juce::AudioProcessorValueTreeState::SliderAttachment attachment;
};

// Quadratische Taste, gedrückt halten = Parameter an (Throw).
class MomentaryPad final : public juce::Component
{
public:
    MomentaryPad (juce::AudioProcessorValueTreeState&, const juce::String& paramId, const juce::String& label,
                  ShowValue show);

    void paint (juce::Graphics&) override;
    void mouseDown (const juce::MouseEvent&) override;
    void mouseUp (const juce::MouseEvent&) override;

private:
    juce::RangedAudioParameter& parameter;
    juce::String label;
    ShowValue show;
    bool on = false;
    juce::ParameterAttachment attachment;
};

// Taste mit LED für die Seitenwahl.
class TabKey final : public juce::Component
{
public:
    explicit TabKey (const juce::String& label);

    void paint (juce::Graphics&) override;
    void mouseDown (const juce::MouseEvent&) override;

    void setActive (bool);
    std::function<void()> onClick;

private:
    juce::String label;
    bool active = false;
};
}
