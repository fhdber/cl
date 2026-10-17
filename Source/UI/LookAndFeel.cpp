#include "LookAndFeel.h"

namespace ui
{
LookAndFeel::LookAndFeel()
{
    setDefaultSansSerifTypeface (typeface());

    setColour (juce::PopupMenu::backgroundColourId, colour::display);
    setColour (juce::PopupMenu::textColourId, juce::Colour (0xffd9dcdf));
    setColour (juce::PopupMenu::headerTextColourId, colour::accent);
    setColour (juce::PopupMenu::highlightedBackgroundColourId, colour::accent);
    setColour (juce::PopupMenu::highlightedTextColourId, colour::display);
}

void LookAndFeel::drawRotarySlider (juce::Graphics& g, int x, int y, int width, int height, float sliderPos,
                                    float startAngle, float endAngle, juce::Slider& slider)
{
    const auto hero    = static_cast<bool> (slider.getProperties()["hero"]);
    const auto bipolar = static_cast<bool> (slider.getProperties()["bipolar"]);

    const auto area = juce::Rectangle<int> (x, y, width, height).toFloat();
    const auto size = std::min (area.getWidth(), area.getHeight());
    const auto centre = area.getCentre();
    const auto arcRadius = size * 0.5f - 2.0f;
    const auto knobRadius = arcRadius - size * 0.11f;
    const auto angle = startAngle + sliderPos * (endAngle - startAngle);

    // Wertebogen
    juce::Path track;
    track.addCentredArc (centre.x, centre.y, arcRadius, arcRadius, 0.0f, startAngle, endAngle, true);
    g.setColour (juce::Colours::black.withAlpha (0.12f));
    g.strokePath (track, juce::PathStrokeType (2.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    const auto from = bipolar ? (startAngle + endAngle) * 0.5f : startAngle;
    juce::Path value;
    value.addCentredArc (centre.x, centre.y, arcRadius, arcRadius, 0.0f, std::min (from, angle), std::max (from, angle), true);
    g.setColour (colour::accent);
    g.strokePath (value, juce::PathStrokeType (2.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Schatten
    juce::Path knob;
    knob.addEllipse (juce::Rectangle<float> (knobRadius * 2.0f, knobRadius * 2.0f).withCentre (centre));
    juce::DropShadow (juce::Colours::black.withAlpha (0.35f), juce::roundToInt (size * 0.16f),
                      { 0, juce::roundToInt (size * 0.07f) }).drawForPath (g, knob);

    // Knopf
    const auto bounds = knob.getBounds();
    if (hero)
        g.setGradientFill (juce::ColourGradient (juce::Colour (0xffff8a45), bounds.getX(), bounds.getY(),
                                                 colour::accentDeep, bounds.getRight(), bounds.getBottom(), false));
    else
        g.setGradientFill (juce::ColourGradient (juce::Colour (0xfff4f6f8), bounds.getX(), bounds.getY(),
                                                 juce::Colour (0xffc3c8cd), bounds.getRight(), bounds.getBottom(), false));
    g.fillPath (knob);

    // innerer Lichtrand
    g.setColour (juce::Colours::white.withAlpha (hero ? 0.25f : 0.7f));
    g.drawEllipse (bounds.reduced (size * 0.07f), 1.0f);

    // schwarzer Ring
    g.setColour (colour::ink);
    g.drawEllipse (bounds, std::max (1.6f, size * 0.05f));

    // Zeigerpunkt
    const auto dotRadius = std::max (2.0f, size * 0.045f);
    const auto dotDistance = knobRadius * 0.62f;
    const auto dot = centre.getPointOnCircumference (dotDistance, angle);
    g.setColour (hero ? juce::Colours::white : colour::pointer);
    g.fillEllipse (juce::Rectangle<float> (dotRadius * 2.0f, dotRadius * 2.0f).withCentre (dot));
}

void LookAndFeel::drawPopupMenuBackground (juce::Graphics& g, int width, int height)
{
    g.fillAll (colour::display);
    g.setColour (juce::Colours::white.withAlpha (0.08f));
    g.drawRect (0, 0, width, height);
}

juce::Font LookAndFeel::getPopupMenuFont()
{
    return font (15.0f);
}
}
