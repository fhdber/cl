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

    constexpr float segmentText = 13.0f, segmentPadding = 12.0f, segmentInset = 3.0f;
}

FineSlider::FineSlider()
    : juce::Slider (juce::Slider::RotaryHorizontalVerticalDrag, juce::Slider::NoTextBox)
{
    setRotaryParameters (juce::MathConstants<float>::pi * 1.25f, juce::MathConstants<float>::pi * 2.75f, true);
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
            ShowParameter showParameter, KnobLook knobLook)
    : parameter (*state.getParameter (paramId)),
      label (labelText),
      show (std::move (showParameter)),
      look (std::move (knobLook)),
      attachment (state, paramId, slider)
{
    slider.getProperties().set ("hero", look.hero);
    slider.getProperties().set ("family", static_cast<int> (look.family));
    slider.getProperties().set ("bipolar", parameter.getNormalisableRange().start < 0.0f);
    slider.setDoubleClickReturnValue (true, parameter.convertFrom0to1 (parameter.getDefaultValue()));
    slider.onValueChange = [this] { if (slider.isMouseOverOrDragging()) report(); };
    slider.onHover = [this] { report(); };
    slider.setTitle (look.title.isEmpty() ? label : look.title + " " + label);
    addAndMakeVisible (slider);
}

void Knob::report()
{
    if (show)
        show (parameter);
}

void Knob::resized()
{
    auto area = getLocalBounds();
    if (look.title.isNotEmpty())
        area.removeFromTop (24);
    area.removeFromBottom (look.title.isNotEmpty() ? 20 : 24);
    slider.setBounds (area);
}

void Knob::paint (juce::Graphics& g)
{
    const auto& p = palette();
    auto area = getLocalBounds().toFloat();

    if (look.title.isNotEmpty())
    {
        g.setColour (p.ink);
        g.setFont (font (13.0f, Weight::semibold));
        g.drawText (look.title, area.removeFromTop (20.0f), juce::Justification::centred, false);
        g.setColour (p.inkSoft);
        g.setFont (font (12.0f, Weight::regular));
        g.drawText (label, area.removeFromBottom (16.0f), juce::Justification::centred, false);
        return;
    }

    g.setColour (p.ink);
    g.setFont (font (13.0f));
    g.drawText (label, area.removeFromBottom (18.0f), juce::Justification::centred, false);
}

//==============================================================================
Segments::Segments (juce::StringArray segmentLabels) : labels (std::move (segmentLabels)) {}

void Segments::setSelected (int index)
{
    selected = index;
    repaint();
}

int Segments::getNaturalWidth() const
{
    auto w = 2.0f * segmentInset;
    for (const auto& l : labels)
        w += textWidth (font (segmentText), l) + 2.0f * segmentPadding;
    return juce::roundToInt (std::ceil (w));
}

// Breite je Segment nach Textlänge, zusätzlicher Platz gleichmäßig verteilt
juce::Rectangle<float> Segments::segmentBounds (int index) const
{
    const auto area = getLocalBounds().toFloat().reduced (segmentInset);
    const auto extra = (area.getWidth() - (static_cast<float> (getNaturalWidth()) - 2.0f * segmentInset))
                       / static_cast<float> (labels.size());
    auto x = area.getX();
    for (int i = 0; i < index; ++i)
        x += textWidth (font (segmentText), labels[i]) + 2.0f * segmentPadding + extra;

    return { x, area.getY(), textWidth (font (segmentText), labels[index]) + 2.0f * segmentPadding + extra, area.getHeight() };
}

void Segments::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto area = getLocalBounds().toFloat();

    g.setColour (p.segBg);
    g.fillRoundedRectangle (area, area.getHeight() * 0.5f);

    if (juce::isPositiveAndBelow (selected, labels.size()))
    {
        const auto thumb = segmentBounds (selected);
        juce::Path shape;
        shape.addRoundedRectangle (thumb, thumb.getHeight() * 0.5f);
        juce::DropShadow (p.shadow, 4, { 0, 1 }).drawForPath (g, shape);
        g.setColour (p.segThumb);
        g.fillPath (shape);
    }

    g.setFont (font (segmentText));
    for (int i = 0; i < labels.size(); ++i)
    {
        g.setColour (i == selected ? p.ink : p.inkSoft);
        g.drawText (labels[i], segmentBounds (i), juce::Justification::centred, false);
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
                                    juce::StringArray segmentLabels, ShowParameter showParameter)
    : Segments (std::move (segmentLabels)),
      parameter (*state.getParameter (paramId)),
      show (std::move (showParameter)),
      attachment (parameter, [this] (float value) { setSelected (juce::roundToInt (value)); })
{
    attachment.sendInitialUpdate();
    setTitle (parameter.getName (64));
    onSelect = [this] (int i)
    {
        attachment.setValueAsCompleteGesture (static_cast<float> (i));
        if (show)
            show (parameter);
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
    const auto capWidth = 22.0f;
    const auto travel = area.reduced (capWidth * 0.5f, 0.0f);
    const auto pos = static_cast<float> (valueToProportionOfLength (getValue()));
    const auto x = travel.getX() + travel.getWidth() * pos;
    const auto slot = juce::Rectangle<float> (travel.getX(), area.getCentreY() - 2.0f, travel.getWidth(), 4.0f);

    g.setColour (p.track);
    g.fillRoundedRectangle (slot, 2.0f);
    const auto gr = gradient (Family::tone);
    g.setGradientFill (juce::ColourGradient (gr.from, slot.getX(), 0.0f, gr.to, slot.getRight(), 0.0f, false));
    g.fillRoundedRectangle (slot.withRight (x), 2.0f);

    const auto cap = juce::Rectangle<float> (capWidth, 34.0f).withCentre ({ x, area.getCentreY() });
    juce::Path shape;
    shape.addRoundedRectangle (cap, capWidth * 0.5f);
    juce::DropShadow (p.shadow, 6, { 0, 2 }).drawForPath (g, shape);
    g.setColour (p.segThumb);
    g.fillPath (shape);
    g.setColour (p.line);
    g.strokePath (shape, juce::PathStrokeType (1.0f));
}

Crossfader::Crossfader (juce::AudioProcessorValueTreeState& state, const juce::String& paramId, ShowParameter showParameter)
    : parameter (*state.getParameter (paramId)),
      show (std::move (showParameter)),
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
        show (parameter);
}

void Crossfader::resized()
{
    slider.setBounds (getLocalBounds().reduced (28, 0).withTrimmedBottom (24));
}

void Crossfader::paint (juce::Graphics& g)
{
    const auto& p = palette();
    auto area = getLocalBounds().toFloat();
    const auto labels = area.removeFromBottom (18.0f);
    const auto mid = area.getCentreY();

    g.setColour (p.inkSoft);
    g.setFont (font (13.0f));
    g.drawText ("A", juce::Rectangle<float> (0.0f, mid - 10.0f, 22.0f, 20.0f), juce::Justification::centred, false);
    g.drawText ("B", juce::Rectangle<float> (area.getRight() - 22.0f, mid - 10.0f, 22.0f, 20.0f), juce::Justification::centred, false);
    g.setColour (p.ink);
    g.drawText ("Blend", labels, juce::Justification::centred, false);
}

//==============================================================================
ThrowButton::ThrowButton (juce::AudioProcessorValueTreeState& state, const juce::String& paramId, ShowParameter showParameter)
    : parameter (*state.getParameter (paramId)),
      show (std::move (showParameter)),
      attachment (parameter, [this] (float value)
                  {
                      on = value > 0.5f;
                      repaint();
                  })
{
    attachment.sendInitialUpdate();
    setTitle (parameter.getName (64));
}

void ThrowButton::mouseDown (const juce::MouseEvent&)
{
    attachment.beginGesture();
    attachment.setValueAsPartOfGesture (1.0f);
    if (show)
        show (parameter);
}

void ThrowButton::mouseUp (const juce::MouseEvent&)
{
    attachment.setValueAsPartOfGesture (0.0f);
    attachment.endGesture();
    if (show)
        show (parameter);
}

void ThrowButton::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto side = static_cast<float> (std::min (getWidth(), getHeight())) - 2.0f;
    const auto disc = juce::Rectangle<float> (side, side).withCentre (getLocalBounds().toFloat().getCentre());
    const auto gr = gradient (Family::space);

    g.setColour (on ? gr.to.withAlpha (0.10f) : p.panel);
    g.fillEllipse (disc);
    g.setColour (on ? gr.to : p.track);
    g.drawEllipse (disc.reduced (0.75f), on ? 2.0f : 1.0f);

    const auto c = disc.getCentre();
    const auto led = juce::Rectangle<float> (side * 0.2f, 3.0f).withCentre ({ c.x, c.y - side * 0.13f });
    if (on)
    {
        g.setColour (gr.from.withAlpha (0.35f));
        g.fillRoundedRectangle (led.expanded (4.0f, 3.0f), 4.0f);
    }
    g.setGradientFill (juce::ColourGradient (gr.from, led.getX(), 0.0f, gr.to, led.getRight(), 0.0f, false));
    g.setOpacity (on ? 1.0f : 0.55f);
    g.fillRoundedRectangle (led, 1.5f);
    g.setOpacity (1.0f);

    g.setColour (p.ink);
    g.setFont (font (13.0f));
    g.drawText ("Throw", juce::Rectangle<float> (side, 20.0f).withCentre ({ c.x, c.y + side * 0.08f }), juce::Justification::centred, false);
}
}
