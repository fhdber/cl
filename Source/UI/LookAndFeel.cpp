#include "LookAndFeel.h"

namespace ui
{
LookAndFeel::LookAndFeel()
{
    setDefaultSansSerifTypeface (typeface());

    setColour (juce::PopupMenu::backgroundColourId, lightPalette.display);
    setColour (juce::PopupMenu::textColourId, juce::Colour (0xffd9dcdf));
    setColour (juce::PopupMenu::headerTextColourId, lightPalette.accent);
    setColour (juce::PopupMenu::highlightedBackgroundColourId, lightPalette.accent);
    setColour (juce::PopupMenu::highlightedTextColourId, lightPalette.display);
}

void LookAndFeel::drawRotarySlider (juce::Graphics& g, int x, int y, int width, int height, float sliderPos,
                                    float startAngle, float endAngle, juce::Slider& slider)
{
    const auto& p = palette();
    const auto hero    = static_cast<bool> (slider.getProperties()["hero"]);
    const auto bipolar = static_cast<bool> (slider.getProperties()["bipolar"]);

    const auto area = juce::Rectangle<int> (x, y, width, height).toFloat();
    const auto size = std::min (area.getWidth(), area.getHeight());
    const auto centre = area.getCentre();
    const auto arcWidth = hero ? 3.5f : 2.5f;
    const auto arcRadius = size * 0.5f - arcWidth;
    const auto knobRadius = arcRadius - size * (hero ? 0.12f : 0.13f);
    const auto angle = startAngle + sliderPos * (endAngle - startAngle);
    const auto stroke = juce::PathStrokeType (arcWidth, juce::PathStrokeType::curved, juce::PathStrokeType::rounded);

    // Wertebogen
    juce::Path track;
    track.addCentredArc (centre.x, centre.y, arcRadius, arcRadius, 0.0f, startAngle, endAngle, true);
    g.setColour (p.track);
    g.strokePath (track, stroke);

    const auto from = bipolar ? (startAngle + endAngle) * 0.5f : startAngle;
    juce::Path value;
    value.addCentredArc (centre.x, centre.y, arcRadius, arcRadius, 0.0f, std::min (from, angle), std::max (from, angle), true);
    if (hero)
    {
        g.setColour (p.accent.withAlpha (0.22f));
        g.strokePath (value, juce::PathStrokeType (arcWidth * 3.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    }
    g.setColour (p.accent);
    g.strokePath (value, stroke);

    // Knopf: weich, mit Schatten nach unten und Lichtkante oben
    juce::Path knob;
    const auto bounds = juce::Rectangle<float> (knobRadius * 2.0f, knobRadius * 2.0f).withCentre (centre);
    knob.addEllipse (bounds);
    juce::DropShadow (p.shadow, juce::roundToInt (size * 0.2f), { 0, juce::roundToInt (size * 0.08f) }).drawForPath (g, knob);

    g.setGradientFill (juce::ColourGradient (p.knobTop, bounds.getX(), bounds.getY(),
                                             p.knobBottom, bounds.getX(), bounds.getBottom(), false));
    g.fillPath (knob);

    // flache Mulde in der Mitte, wie bei gedrehten Alu-/Kunststoffknöpfen
    const auto inner = bounds.reduced (knobRadius * 0.22f);
    g.setGradientFill (juce::ColourGradient (p.knobBottom, inner.getX(), inner.getY(),
                                             p.knobTop, inner.getX(), inner.getBottom(), false));
    g.fillEllipse (inner);

    g.setColour (p.highlight);
    g.drawEllipse (bounds.reduced (0.75f), 1.0f);
    g.setColour (p.knobEdge);
    g.drawEllipse (bounds, 1.0f);

    // Zeiger: kurzer Strich vom Rand nach innen
    const auto outer = centre.getPointOnCircumference (knobRadius * 0.86f, angle);
    const auto innerPoint = centre.getPointOnCircumference (knobRadius * (hero ? 0.42f : 0.5f), angle);
    g.setColour (hero ? p.accent : p.ink);
    g.drawLine ({ innerPoint, outer }, hero ? 3.2f : 2.4f);
}

void LookAndFeel::drawPopupMenuBackground (juce::Graphics& g, int width, int height)
{
    g.fillAll (lightPalette.display);
    g.setColour (juce::Colours::white.withAlpha (0.08f));
    g.drawRect (0, 0, width, height);
}

juce::Font LookAndFeel::getPopupMenuFont()
{
    return pixelFont (15.0f);
}
}
