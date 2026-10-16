#pragma once

#include "Theme.h"

namespace ui
{
// Knobs im Stil von Hardware-Drehreglern: heller Knopf, schwarzer Ring,
// roter Zeigerpunkt, dünner oranger Wertebogen. Slider-Properties:
//   "hero"    – oranger Knopf (Cutoff, Volume)
//   "bipolar" – Bogen startet in der Mitte
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
