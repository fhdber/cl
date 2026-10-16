#pragma once

#include "PluginProcessor.h"
#include "UI/Controls.h"
#include "UI/Display.h"
#include "UI/LookAndFeel.h"

// Gesamte Oberfläche auf der festen Designfläche; der Editor skaliert sie.
class Contra86Panel final : public juce::Component
{
public:
    explicit Contra86Panel (Contra86Processor&);

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    struct Section
    {
        juce::String title;
        juce::Rectangle<int> area;
        std::vector<std::pair<ui::SegmentedControl*, int>> segments; // rechts oben, von rechts nach links
        std::vector<ui::Knob*> knobs;
    };

    ui::Knob& knob (const juce::String& id, const juce::String& label, bool hero = false);
    ui::SegmentedControl& segment (const juce::String& id, juce::StringArray labels);
    void layoutSection (const Section&);

    Contra86Processor& processor;
    ui::Display display;
    std::vector<std::unique_ptr<ui::Knob>> knobs;
    std::vector<std::unique_ptr<ui::SegmentedControl>> segments;
    std::vector<Section> sections;
    ui::Knob* volumeKnob = nullptr;
};

class Contra86Editor final : public juce::AudioProcessorEditor
{
public:
    explicit Contra86Editor (Contra86Processor&);
    ~Contra86Editor() override;

    void resized() override;

private:
    Contra86Processor& contraProcessor;
    ui::LookAndFeel lookAndFeel;
    Contra86Panel panel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Contra86Editor)
};
