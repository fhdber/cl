#include "Controls.h"

namespace ui
{
FineSlider::FineSlider()
    : juce::Slider (juce::Slider::RotaryHorizontalVerticalDrag, juce::Slider::NoTextBox)
{
    setRotaryParameters (juce::MathConstants<float>::pi * 1.22f, juce::MathConstants<float>::pi * 2.78f, true);
    setMouseDragSensitivity (220);
}

void FineSlider::mouseDown (const juce::MouseEvent& e)
{
    lastPosition = virtualPosition = e.position;
    juce::Slider::mouseDown (e);
}

// Die Mausbewegung wird schrittweise skaliert, damit das Umschalten der
// Feinjustierung mitten im Ziehen keinen Sprung erzeugt.
void FineSlider::mouseDrag (const juce::MouseEvent& e)
{
    const auto fine = e.mods.isShiftDown() || e.mods.isCommandDown();
    virtualPosition += (e.position - lastPosition) * (fine ? 0.15f : 1.0f);
    lastPosition = e.position;
    juce::Slider::mouseDrag (e.withNewPosition (virtualPosition));
}

void FineSlider::mouseEnter (const juce::MouseEvent& e)
{
    juce::Slider::mouseEnter (e);
    if (onHover)
        onHover();
}

//==============================================================================
Knob::Knob (juce::AudioProcessorValueTreeState& state, const juce::String& paramId, const juce::String& labelText,
            ShowValue showValue, bool hero)
    : parameter (*state.getParameter (paramId)),
      label (labelText),
      show (std::move (showValue)),
      attachment (state, paramId, slider)
{
    slider.getProperties().set ("hero", hero);
    slider.getProperties().set ("bipolar", parameter.getNormalisableRange().start < 0.0f);
    slider.setDoubleClickReturnValue (true, parameter.convertFrom0to1 (parameter.getDefaultValue()));
    slider.onValueChange = [this] { if (slider.isMouseOverOrDragging()) report(); };
    slider.onHover = [this] { report(); };
    slider.setTitle (label);
    addAndMakeVisible (slider);
}

void Knob::report()
{
    if (show)
        show (parameter.getName (64), parameter.getCurrentValueAsText());
}

void Knob::resized()
{
    auto area = getLocalBounds();
    slider.setBounds (area.removeFromTop (area.getHeight() - 20));
}

void Knob::paint (juce::Graphics& g)
{
    g.setColour (colour::ink);
    drawTracked (g, label.toUpperCase(), getLocalBounds().removeFromBottom (18).toFloat(), 9.0f,
                 juce::Justification::centred);
}

//==============================================================================
SegmentedControl::SegmentedControl (juce::AudioProcessorValueTreeState& state, const juce::String& paramId,
                                    juce::StringArray segmentLabels, ShowValue showValue)
    : parameter (*state.getParameter (paramId)),
      labels (std::move (segmentLabels)),
      show (std::move (showValue)),
      attachment (parameter, [this] (float value)
                  {
                      selected = juce::roundToInt (value);
                      repaint();
                  })
{
    attachment.sendInitialUpdate();
    setTitle (parameter.getName (64));
}

juce::Rectangle<float> SegmentedControl::segmentBounds (int index) const
{
    const auto area = getLocalBounds().toFloat().reduced (2.0f);
    const auto w = area.getWidth() / static_cast<float> (labels.size());
    return { area.getX() + w * static_cast<float> (index), area.getY(), w, area.getHeight() };
}

void SegmentedControl::paint (juce::Graphics& g)
{
    const auto area = getLocalBounds().toFloat();
    const auto radius = area.getHeight() * 0.5f;

    g.setColour (juce::Colours::black.withAlpha (0.06f));
    g.fillRoundedRectangle (area, radius);
    g.setColour (juce::Colours::black.withAlpha (0.22f));
    g.drawRoundedRectangle (area.reduced (0.5f), radius, 1.0f);

    for (int i = 0; i < labels.size(); ++i)
    {
        auto seg = segmentBounds (i);
        const auto active = i == selected;

        if (active)
        {
            g.setColour (colour::ink);
            g.fillRoundedRectangle (seg, seg.getHeight() * 0.5f);

            const auto led = juce::Rectangle<float> (4.0f, 4.0f).withCentre ({ seg.getX() + 9.0f, seg.getCentreY() });
            g.setColour (colour::accent);
            g.fillEllipse (led);
            seg.removeFromLeft (8.0f);
        }

        g.setColour (active ? juce::Colours::white : colour::inkSoft);
        drawTracked (g, labels[i], seg, 8.5f, juce::Justification::centred, 0.04f);
    }
}

void SegmentedControl::mouseDown (const juce::MouseEvent& e)
{
    for (int i = 0; i < labels.size(); ++i)
        if (segmentBounds (i).contains (e.position))
        {
            attachment.setValueAsCompleteGesture (static_cast<float> (i));
            if (show)
                show (parameter.getName (64), parameter.getCurrentValueAsText());
            return;
        }
}
}
