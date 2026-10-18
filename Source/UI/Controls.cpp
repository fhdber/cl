#include "Controls.h"

namespace ui
{
namespace
{
    // Feinjustierung: Mausbewegung schrittweise skalieren, damit das Umschalten
    // mitten im Ziehen keinen Sprung erzeugt.
    juce::MouseEvent scaledDrag (const juce::MouseEvent& e, juce::Point<float>& last, juce::Point<float>& virtualPos)
    {
        const auto fine = e.mods.isShiftDown() || e.mods.isCommandDown();
        virtualPos += (e.position - last) * (fine ? 0.15f : 1.0f);
        last = e.position;
        return e.withNewPosition (virtualPos);
    }
}

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

void FineSlider::mouseDrag (const juce::MouseEvent& e)
{
    juce::Slider::mouseDrag (scaledDrag (e, lastPosition, virtualPosition));
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
    slider.setBounds (area.removeFromTop (area.getHeight() - 24));
}

void Knob::paint (juce::Graphics& g)
{
    g.setColour (palette().ink);
    drawTracked (g, label.toUpperCase(), getLocalBounds().removeFromBottom (20).toFloat(), 13.0f,
                 juce::Justification::centred);
}

//==============================================================================
Segments::Segments (juce::StringArray segmentLabels) : labels (std::move (segmentLabels)) {}

void Segments::setSelected (int index)
{
    selected = index;
    repaint();
}

namespace
{
    constexpr float segmentPadding = 14.0f, segmentText = 12.0f, segmentTracking = 0.04f;

    float labelWidth (const juce::String& text)
    {
        return juce::GlyphArrangement::getStringWidth (font (segmentText).withExtraKerningFactor (segmentTracking), text);
    }
}

int Segments::getNaturalWidth() const
{
    auto w = 4.0f;
    for (const auto& l : labels)
        w += labelWidth (l) + 2.0f * segmentPadding;
    return juce::roundToInt (std::ceil (w));
}

// Breite je Segment nach Textlänge, zusätzlicher Platz gleichmäßig verteilt
juce::Rectangle<float> Segments::segmentBounds (int index) const
{
    const auto area = getLocalBounds().toFloat().reduced (2.0f);
    const auto extra = (area.getWidth() - static_cast<float> (getNaturalWidth() - 4)) / static_cast<float> (labels.size());

    auto x = area.getX();
    for (int i = 0; i < index; ++i)
        x += labelWidth (labels[i]) + 2.0f * segmentPadding + extra;

    return { x, area.getY(), labelWidth (labels[index]) + 2.0f * segmentPadding + extra, area.getHeight() };
}

void Segments::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto area = getLocalBounds().toFloat();
    const auto radius = area.getHeight() * 0.5f;

    g.setColour (p.track);
    g.fillRoundedRectangle (area, radius);
    g.setColour (p.knobEdge);
    g.drawRoundedRectangle (area.reduced (0.5f), radius, 1.0f);

    for (int i = 0; i < labels.size(); ++i)
    {
        const auto seg = segmentBounds (i);
        const auto active = i == selected;

        if (active)
        {
            g.setColour (p.segOn);
            g.fillRoundedRectangle (seg, seg.getHeight() * 0.5f);
        }

        g.setColour (active ? p.segOnText : p.inkSoft);
        drawTracked (g, labels[i], seg, segmentText, juce::Justification::centred, segmentTracking);
    }
}

void Segments::mouseDown (const juce::MouseEvent& e)
{
    for (int i = 0; i < labels.size(); ++i)
        if (segmentBounds (i).contains (e.position))
        {
            if (onSelect)
                onSelect (i);
            return;
        }
}

SegmentedControl::SegmentedControl (juce::AudioProcessorValueTreeState& state, const juce::String& paramId,
                                    juce::StringArray segmentLabels, ShowValue showValue)
    : Segments (std::move (segmentLabels)),
      parameter (*state.getParameter (paramId)),
      show (std::move (showValue)),
      attachment (parameter, [this] (float value) { setSelected (juce::roundToInt (value)); })
{
    attachment.sendInitialUpdate();
    setTitle (parameter.getName (64));
    onSelect = [this] (int i)
    {
        attachment.setValueAsCompleteGesture (static_cast<float> (i));
        if (show)
            show (parameter.getName (64), parameter.getCurrentValueAsText());
    };
}

//==============================================================================
Crossfader::Track::Track()
    : juce::Slider (juce::Slider::LinearHorizontal, juce::Slider::NoTextBox)
{
    setMouseDragSensitivity (260);
    setSliderSnapsToMousePosition (false);
}

void Crossfader::Track::mouseDown (const juce::MouseEvent& e)
{
    lastPosition = virtualPosition = e.position;
    juce::Slider::mouseDown (e);
}

void Crossfader::Track::mouseDrag (const juce::MouseEvent& e)
{
    juce::Slider::mouseDrag (scaledDrag (e, lastPosition, virtualPosition));
}

void Crossfader::Track::mouseEnter (const juce::MouseEvent& e)
{
    juce::Slider::mouseEnter (e);
    if (onHover)
        onHover();
}

void Crossfader::Track::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto area = getLocalBounds().toFloat();
    const auto capWidth = 34.0f;
    const auto travel = area.reduced (capWidth * 0.5f, 0.0f);
    const auto pos = static_cast<float> (valueToProportionOfLength (getValue()));
    const auto x = travel.getX() + travel.getWidth() * pos;

    // Schlitz
    const auto slot = juce::Rectangle<float> (travel.getX(), area.getCentreY() - 3.0f, travel.getWidth(), 6.0f);
    g.setColour (p.ink.withAlpha (0.75f));
    g.fillRoundedRectangle (slot, 3.0f);
    g.setColour (p.accent);
    g.fillRoundedRectangle (slot.withRight (x), 3.0f);

    // Rasterstriche
    g.setColour (p.inkSoft.withAlpha (0.6f));
    for (int i = 0; i <= 10; ++i)
    {
        const auto tx = travel.getX() + travel.getWidth() * static_cast<float> (i) / 10.0f;
        const auto len = i % 5 == 0 ? 8.0f : 4.0f;
        g.fillRect (tx - 0.5f, area.getBottom() - len, 1.0f, len);
    }

    // Kappe
    const auto cap = juce::Rectangle<float> (capWidth, area.getHeight() - 14.0f).withCentre ({ x, area.getCentreY() - 2.0f });
    drawKey (g, cap, false, 7.0f);
    g.setColour (p.accent);
    g.fillRect (juce::Rectangle<float> (2.5f, cap.getHeight() - 14.0f).withCentre (cap.getCentre()));
}

Crossfader::Crossfader (juce::AudioProcessorValueTreeState& state, const juce::String& paramId, ShowValue showValue)
    : parameter (*state.getParameter (paramId)),
      show (std::move (showValue)),
      attachment (state, paramId, slider)
{
    slider.setDoubleClickReturnValue (true, parameter.convertFrom0to1 (parameter.getDefaultValue()));
    slider.onValueChange = [this] { if (slider.isMouseOverOrDragging()) report(); };
    slider.onHover = [this] { report(); };
    slider.setTitle (parameter.getName (64));
    addAndMakeVisible (slider);
}

void Crossfader::report()
{
    if (show)
        show (parameter.getName (64), parameter.getCurrentValueAsText());
}

void Crossfader::resized()
{
    slider.setBounds (getLocalBounds().reduced (34, 0).withTrimmedBottom (24));
}

void Crossfader::paint (juce::Graphics& g)
{
    const auto& p = palette();
    auto area = getLocalBounds().toFloat();
    const auto labels = area.removeFromBottom (20.0f);
    const auto mid = area.getCentreY() - 2.0f;

    g.setColour (p.ink);
    g.setFont (font (16.0f));
    g.drawText ("A", juce::Rectangle<float> (0.0f, mid - 12.0f, 26.0f, 24.0f), juce::Justification::centred, false);
    g.drawText ("B", juce::Rectangle<float> (area.getRight() - 26.0f, mid - 12.0f, 26.0f, 24.0f), juce::Justification::centred, false);
    drawTracked (g, "BLEND", labels, 13.0f, juce::Justification::centred);
}

//==============================================================================
MomentaryPad::MomentaryPad (juce::AudioProcessorValueTreeState& state, const juce::String& paramId,
                            const juce::String& labelText, ShowValue showValue)
    : parameter (*state.getParameter (paramId)),
      label (labelText),
      show (std::move (showValue)),
      attachment (parameter, [this] (float value)
                  {
                      on = value > 0.5f;
                      repaint();
                  })
{
    attachment.sendInitialUpdate();
    setTitle (parameter.getName (64));
}

void MomentaryPad::mouseDown (const juce::MouseEvent&)
{
    attachment.beginGesture();
    attachment.setValueAsPartOfGesture (1.0f);
    if (show)
        show (parameter.getName (64), "ON");
}

void MomentaryPad::mouseUp (const juce::MouseEvent&)
{
    attachment.setValueAsPartOfGesture (0.0f);
    attachment.endGesture();
    if (show)
        show (parameter.getName (64), "OFF");
}

void MomentaryPad::paint (juce::Graphics& g)
{
    const auto& p = palette();
    auto area = getLocalBounds().toFloat();
    const auto text = area.removeFromBottom (20.0f);
    const auto side = std::min (area.getWidth(), area.getHeight() - 6.0f);
    const auto key = juce::Rectangle<float> (side, side).withCentre (area.getCentre()).reduced (2.0f);

    drawKey (g, key, on, 14.0f);
    drawLed (g, key.getCentre(), on, p.led, 12.0f);

    g.setColour (p.ink);
    drawTracked (g, label.toUpperCase(), text, 13.0f, juce::Justification::centred);
}

//==============================================================================
TabKey::TabKey (const juce::String& labelText) : label (labelText)
{
    setTitle (label);
}

void TabKey::setActive (bool shouldBeActive)
{
    active = shouldBeActive;
    repaint();
}

void TabKey::mouseDown (const juce::MouseEvent&)
{
    if (onClick)
        onClick();
}

void TabKey::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto r = getLocalBounds().toFloat().reduced (3.0f);
    drawKey (g, r, active, 9.0f);
    drawLed (g, { r.getX() + 18.0f, r.getCentreY() }, active, p.accent, 6.0f);

    g.setColour (active ? p.ink : p.inkSoft);
    drawTracked (g, label, r.withTrimmedLeft (30.0f), 14.0f, juce::Justification::centred, 0.14f);
}
}
