#pragma once

#include "Theme.h"

namespace ui
{
// Reduzierte Hardware-Knöpfe: weicher Knopf mit Mulde und Zeigerstrich,
// dünner oranger Wertebogen. Farben aus dem aktuellen Theme. Slider-Properties:
//   "hero"    – kräftiger Bogen mit Schein, oranger Zeiger (Cutoff, Dust, Volume …)
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
