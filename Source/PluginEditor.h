#pragma once

#include "PluginProcessor.h"
#include "UI/CharacterPad.h"
#include "UI/Controls.h"
#include "UI/Display.h"
#include "UI/LookAndFeel.h"

// Gesamte Oberfläche auf der festen Designfläche; der Editor skaliert sie.
// PLAY: Visualizer, CHARACTER-Pad, Kernregler, Effektkette.
// EDIT: alle Parameter in Karten, Reiter Sound / Character.
// Theme hell/dunkel nach Uhrzeit oder fest.
class Contra86Panel final : public juce::Component, private juce::Timer
{
public:
    enum Page { play, editSound, editCharacter };

    explicit Contra86Panel (Contra86Processor&);

    void paint (juce::Graphics&) override;
    void resized() override;

    void setPage (int page);
    // Für Screenshots: Theme setzen, ohne die Einstellung zu speichern.
    void previewTheme (ui::ThemeMode);
    // Für Screenshots: Display zeigt das Bild eines Parameters.
    void previewParameter (const juce::String& paramId);

private:
    struct Item
    {
        juce::Component* component;
        float weight;
        int height;
    };

    struct Section
    {
        int page;
        juce::String title;
        juce::Rectangle<int> area;
        std::vector<ui::Segments*> header; // rechts oben, von rechts nach links
        std::vector<Item> items;
    };

    void timerCallback() override;
    void applyTheme();
    void setThemeMode (ui::ThemeMode, bool save);

    Item knob (const juce::String& id, const juce::String& label, int height, ui::KnobLook look);
    ui::SegmentedControl& segment (const juce::String& id, juce::StringArray labels);
    template <typename T> T& own (std::unique_ptr<T>);
    void layoutSection (const Section&);
    void layoutRow (const std::vector<Item>&, juce::Rectangle<int> area, int baseline);
    std::vector<juce::Rectangle<int>> cards() const;

    Contra86Processor& processor;
    ui::ShowParameter show;
    ui::Display display;
    std::vector<std::unique_ptr<juce::Component>> controls;
    std::vector<Section> sections;
    std::vector<Item> playKnobs, chain;
    ui::CharacterPad* pad = nullptr;
    ui::ThrowButton* throwButton = nullptr;
    ui::Segments pageSwitch { { "Play", "Edit" } };
    ui::Segments editTabs { { "Sound", "Character" } };
    ui::Segments themeSwitch { { "Auto", "Day", "Night" } };
    int page = play;
    ui::ThemeMode themeMode = ui::ThemeMode::automatic;
    bool shownDark = false;
    juce::PropertiesFile settings;
};

class Contra86Editor final : public juce::AudioProcessorEditor
{
public:
    explicit Contra86Editor (Contra86Processor&);
    ~Contra86Editor() override;

    void resized() override;

    Contra86Panel& getPanel() noexcept { return panel; }

private:
    Contra86Processor& contraProcessor;
    ui::LookAndFeel lookAndFeel;
    Contra86Panel panel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Contra86Editor)
};
