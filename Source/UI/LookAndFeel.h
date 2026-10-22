#pragma once

#include "Theme.h"

namespace ui
{
// Minimale Regler: feine Spur und Wertebogen im Verlauf der Funktionsgruppe,
// kein Knopfkörper. Slider-Properties:
//   "hero"    – größerer Bogen mit Schein (Cutoff, Dust, 808, Dist, Volume)
//   "bipolar" – Bogen startet in der Mitte
//   "family"  – Funktionsgruppe (ui::Family) für den Farbverlauf
class LookAndFeel final : public juce::LookAndFeel_V4
{
public:
    LookAndFeel();

    void drawRotarySlider (juce::Graphics&, int x, int y, int width, int height, float sliderPos,
                           float startAngle, float endAngle, juce::Slider&) override;

    void drawPopupMenuBackground (juce::Graphics&, int width, int height) override;
    juce::Font getPopupMenuFont() override;
};
}
