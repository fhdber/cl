#include "CharacterPad.h"

namespace ui
{
namespace
{
    constexpr int columns = 14, rows = 13;
}

CharacterPad::CharacterPad (juce::AudioProcessorValueTreeState& state, const juce::String& xParam, const juce::String& yParam,
                            ShowParameter showParameter)
    : xParameter (*state.getParameter (xParam)),
      yParameter (*state.getParameter (yParam)),
      show (std::move (showParameter)),
      xAttachment (xParameter, [this] (float v) { x = xParameter.convertTo0to1 (v); repaint(); }),
      yAttachment (yParameter, [this] (float v) { y = yParameter.convertTo0to1 (v); repaint(); })
{
    xAttachment.sendInitialUpdate();
    yAttachment.sendInitialUpdate();
    setTitle ("Character");
    setMouseCursor (juce::MouseCursor::CrosshairCursor);
}

juce::Rectangle<float> CharacterPad::field() const
{
    return getLocalBounds().toFloat().withTrimmedLeft (52.0f).withTrimmedRight (24.0f)
                           .withTrimmedTop (60.0f).withTrimmedBottom (60.0f);
}

void CharacterPad::setFromPosition (juce::Point<float> pos)
{
    const auto f = field();
    const auto nx = juce::jlimit (0.0f, 1.0f, (pos.x - f.getX()) / f.getWidth());
    const auto ny = juce::jlimit (0.0f, 1.0f, 1.0f - (pos.y - f.getY()) / f.getHeight());
    xAttachment.setValueAsPartOfGesture (xParameter.convertFrom0to1 (nx));
    yAttachment.setValueAsPartOfGesture (yParameter.convertFrom0to1 (ny));
}

void CharacterPad::mouseDown (const juce::MouseEvent& e)
{
    if (! field().expanded (12.0f).contains (e.position))
        return;

    lastPosition = virtualPosition = e.position;
    xAttachment.beginGesture();
    yAttachment.beginGesture();
    setFromPosition (e.position);
    if (show)
        show (xParameter);
}

void CharacterPad::mouseDrag (const juce::MouseEvent& e)
{
    if (! field().expanded (12.0f).contains (e.mouseDownPosition))
        return;

    const auto fine = e.mods.isShiftDown() || e.mods.isCommandDown();
    virtualPosition += (e.position - lastPosition) * (fine ? 0.15f : 1.0f);
    lastPosition = e.position;
    setFromPosition (virtualPosition);

    // Display zeigt die Achse, die sich gerade stärker bewegt
    if (show)
    {
        const auto d = e.getOffsetFromDragStart();
        show (std::abs (d.x) >= std::abs (d.y) ? xParameter : yParameter);
    }
}

void CharacterPad::mouseUp (const juce::MouseEvent& e)
{
    if (! field().expanded (12.0f).contains (e.mouseDownPosition))
        return;

    xAttachment.endGesture();
    yAttachment.endGesture();
}

void CharacterPad::mouseDoubleClick (const juce::MouseEvent&)
{
    xAttachment.setValueAsCompleteGesture (xParameter.convertFrom0to1 (xParameter.getDefaultValue()));
    yAttachment.setValueAsCompleteGesture (yParameter.convertFrom0to1 (yParameter.getDefaultValue()));
}

void CharacterPad::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto bounds = getLocalBounds().toFloat();
    const auto f = field();
    const auto dust = gradient (Family::dust), heat = gradient (Family::heat), space = gradient (Family::space);

    // Kopf
    g.setColour (p.ink);
    g.setFont (font (15.0f, Weight::semibold));
    g.drawText ("Character", juce::Rectangle<float> (24.0f, 18.0f, 200.0f, 24.0f), juce::Justification::centredLeft, false);
    g.setColour (p.inkSoft);
    g.setFont (font (12.0f, Weight::regular));
    g.drawText ("Drag to shape", juce::Rectangle<float> (bounds.getRight() - 224.0f, 18.0f, 200.0f, 24.0f),
                juce::Justification::centredRight, false);

    // Feld: kühl/sauber unten links → warm/heiß oben rechts
    juce::Path shape;
    shape.addRoundedRectangle (f, 20.0f);
    g.setColour (p.panel);
    g.fillPath (shape);
    g.saveState();
    g.reduceClipRegion (shape);
    g.setGradientFill (juce::ColourGradient (space.from.withAlpha (0.16f), f.getX(), 0.0f, dust.from.withAlpha (0.16f), f.getRight(), 0.0f, false));
    g.fillRect (f);
    g.setGradientFill (juce::ColourGradient (heat.to.withAlpha (0.10f), 0.0f, f.getY(), juce::Colours::transparentWhite, 0.0f, f.getBottom(), false));
    g.fillRect (f);
    g.restoreState();

    // Punktraster, leuchtet um den Puck
    const auto puck = juce::Point<float> (f.getX() + x * f.getWidth(), f.getY() + (1.0f - y) * f.getHeight());
    for (int i = 1; i <= columns; ++i)
        for (int j = 1; j <= rows; ++j)
        {
            const auto dx = f.getX() + f.getWidth() * static_cast<float> (i) / static_cast<float> (columns + 1);
            const auto dy = f.getY() + f.getHeight() * static_cast<float> (j) / static_cast<float> (rows + 1);
            const auto near = juce::jmax (0.0f, 1.0f - juce::Point<float> (dx, dy).getDistanceFrom (puck) / (f.getWidth() * 0.28f));
            const auto size = 3.0f + 4.0f * near;
            const auto up = 1.0f - (dy - f.getY()) / f.getHeight();
            g.setColour (near > 0.05f ? dust.from.interpolatedWith (heat.to, juce::jmin (1.0f, up * 0.9f + 0.2f)).withAlpha (0.3f + 0.7f * near)
                                      : p.ink.withAlpha (0.14f));
            g.fillEllipse (juce::Rectangle<float> (size, size).withCentre ({ dx, dy }));
        }

    // Puck
    const auto ring = juce::Rectangle<float> (24.0f, 24.0f).withCentre (puck);
    g.setColour (heat.to.withAlpha (0.25f));
    g.fillEllipse (ring.expanded (8.0f));
    g.setColour (p.card);
    g.fillEllipse (ring);
    g.setGradientFill (juce::ColourGradient (heat.from, ring.getX(), ring.getY(), heat.to, ring.getRight(), ring.getBottom(), false));
    juce::Path ringPath;
    ringPath.addEllipse (ring.reduced (2.5f));
    g.strokePath (ringPath, juce::PathStrokeType (5.0f));

    // Achsen mit Live-Werten
    const auto percent = [] (float v) { return juce::String (juce::roundToInt (v * 100.0f)) + "%"; };
    const auto below = juce::Rectangle<float> (f.getX(), f.getBottom() + 12.0f, f.getWidth(), 20.0f);
    g.setColour (p.inkSoft);
    g.setFont (font (12.0f, Weight::regular));
    g.drawText ("Clean", below, juce::Justification::centredLeft, false);
    g.setColour (p.ink);
    g.setFont (font (13.0f));
    g.drawText ("Dust  " + percent (x), below, juce::Justification::centredRight, false);

    g.saveState();
    g.addTransform (juce::AffineTransform::rotation (-juce::MathConstants<float>::halfPi, 30.0f, f.getY()));
    const auto side = juce::Rectangle<float> (30.0f - f.getHeight(), f.getY() - 10.0f, f.getHeight(), 20.0f);
    g.drawText ("Heat  " + percent (y), side, juce::Justification::centredRight, false);
    g.setColour (p.inkSoft);
    g.setFont (font (12.0f, Weight::regular));
    g.drawText ("Soft", side, juce::Justification::centredLeft, false);
    g.restoreState();
}
}
