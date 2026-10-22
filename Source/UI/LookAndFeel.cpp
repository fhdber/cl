#include "LookAndFeel.h"

namespace ui
{
LookAndFeel::LookAndFeel()
{
    setDefaultSansSerifTypeface (interTypeface (Weight::regular));

    setColour (juce::PopupMenu::backgroundColourId, juce::Colour (0xff1c1c1e));
    setColour (juce::PopupMenu::textColourId, juce::Colour (0xffececec));
    setColour (juce::PopupMenu::headerTextColourId, lightPalette.accent);
    setColour (juce::PopupMenu::highlightedBackgroundColourId, lightPalette.accent);
    setColour (juce::PopupMenu::highlightedTextColourId, juce::Colours::white);
}

void LookAndFeel::drawRotarySlider (juce::Graphics& g, int x, int y, int width, int height, float sliderPos,
                                    float startAngle, float endAngle, juce::Slider& slider)
{
    const auto& p = palette();
    const auto hero    = static_cast<bool> (slider.getProperties()["hero"]);
    const auto bipolar = static_cast<bool> (slider.getProperties()["bipolar"]);
    const auto family  = static_cast<Family> (static_cast<int> (slider.getProperties()["family"]));

    const auto area = juce::Rectangle<int> (x, y, width, height).toFloat();
    const auto size = std::min (area.getWidth(), area.getHeight());
    const auto centre = area.getCentre();
    const auto arcWidth = hero ? 4.5f : std::max (2.5f, size * 0.05f);
    const auto radius = size * 0.5f - arcWidth;
    const auto angle = startAngle + sliderPos * (endAngle - startAngle);
    const auto span = endAngle - startAngle;

    // Spur
    juce::Path track;
    track.addCentredArc (centre.x, centre.y, radius, radius, 0.0f, startAngle, endAngle, true);
    g.setColour (p.track);
    g.strokePath (track, juce::PathStrokeType (hero ? 2.0f : 1.6f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Wertebogen im Verlauf der Funktionsgruppe: je weiter aufgedreht, desto satter
    const auto from = bipolar ? (startAngle + endAngle) * 0.5f : startAngle;
    const auto a0 = std::min (from, angle), a1 = std::max (from, angle);
    if (a1 - a0 < 0.01f)
        return;

    const auto steps = std::max (2, static_cast<int> ((a1 - a0) / 0.05f));
    const auto stroke = juce::PathStrokeType (arcWidth, juce::PathStrokeType::curved, juce::PathStrokeType::rounded);
    for (int i = 0; i < steps; ++i)
    {
        const auto s0 = a0 + (a1 - a0) * static_cast<float> (i) / static_cast<float> (steps);
        const auto s1 = a0 + (a1 - a0) * static_cast<float> (i + 1) / static_cast<float> (steps);
        juce::Path seg;
        seg.addCentredArc (centre.x, centre.y, radius, radius, 0.0f, s0, s1, true);
        g.setColour (gradientAt (family, ((s0 + s1) * 0.5f - startAngle) / span));
        g.strokePath (seg, stroke);
    }

    if (hero)
    {
        juce::Path glow;
        glow.addCentredArc (centre.x, centre.y, radius, radius, 0.0f, a0, a1, true);
        g.setColour (gradient (family).to.withAlpha (0.14f));
        g.strokePath (glow, juce::PathStrokeType (arcWidth * 3.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    }
}

void LookAndFeel::drawPopupMenuBackground (juce::Graphics& g, int width, int height)
{
    g.fillAll (juce::Colour (0xff1c1c1e));
    g.setColour (juce::Colours::white.withAlpha (0.08f));
    g.drawRect (0, 0, width, height);
}

juce::Font LookAndFeel::getPopupMenuFont()
{
    return font (15.0f, Weight::regular);
}
}
