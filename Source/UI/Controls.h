#pragma once

#include "Theme.h"

#include <juce_audio_processors/juce_audio_processors.h>

namespace ui
{
// Meldet den bedienten Parameter ans Display (Hover, Drehen, Umschalten).
using ShowParameter = std::function<void (juce::RangedAudioParameter&)>;

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

// Aussehen eines Reglers
struct KnobLook
{
    KnobLook (Family f = Family::tone, bool isHero = false, juce::String moduleTitle = {})
        : family (f), hero (isHero), title (std::move (moduleTitle)) {}

    Family family;
    bool hero;
    juce::String title; // gesetzt = Modul-Stil: Titel oben, Beschriftung klein darunter
};

class Knob final : public juce::Component
{
public:
    Knob (juce::AudioProcessorValueTreeState&, const juce::String& paramId, const juce::String& label,
          ShowParameter show, KnobLook look = {});

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    void report();

    juce::RangedAudioParameter& parameter;
    juce::String label;
    ShowParameter show;
    KnobLook look;
    FineSlider slider;
    juce::AudioProcessorValueTreeState::SliderAttachment attachment;
};

// Kapsel-Umschalter (Apple Segmented Control); Grundlage für Parameter-Auswahl,
// Seiten- und Theme-Wahl.
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

// Kapsel-Umschalter für Auswahl-Parameter.
class SegmentedControl final : public Segments
{
public:
    SegmentedControl (juce::AudioProcessorValueTreeState&, const juce::String& paramId,
                      juce::StringArray labels, ShowParameter show);

private:
    juce::RangedAudioParameter& parameter;
    ShowParameter show;
    juce::ParameterAttachment attachment;
};

// Horizontaler Crossfader A–B (Blend).
class Crossfader final : public juce::Component
{
public:
    Crossfader (juce::AudioProcessorValueTreeState&, const juce::String& paramId, ShowParameter show);

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
    ShowParameter show;
    Track slider;
    juce::AudioProcessorValueTreeState::SliderAttachment attachment;
};

// Runde Taste, gedrückt halten = Parameter an (Throw).
class ThrowButton final : public juce::Component
{
public:
    ThrowButton (juce::AudioProcessorValueTreeState&, const juce::String& paramId, ShowParameter show);

    void paint (juce::Graphics&) override;
    void mouseDown (const juce::MouseEvent&) override;
    void mouseUp (const juce::MouseEvent&) override;

private:
    juce::RangedAudioParameter& parameter;
    ShowParameter show;
    bool on = false;
    juce::ParameterAttachment attachment;
};
}
