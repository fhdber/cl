#include "Display.h"
#include "PluginProcessor.h"
#include "Presets.h"
#include "Parameters.h"

namespace ui
{
namespace
{
    constexpr double valueHoldMs = 1500.0;
    constexpr int scopeSamples = 1024;
}

Display::Display (Contra86Processor& p) : processor (p)
{
    setTitle ("Preset");
    startTimerHz (30);
}

void Display::showValue (const juce::String& name, const juce::String& value)
{
    valueName = name;
    valueText = value;
    valueUntil = juce::Time::getMillisecondCounterHiRes() + valueHoldMs;
    repaint();
}

void Display::resized()
{
    auto area = getLocalBounds().toFloat().reduced (30.0f, 20.0f);
    scopeArea = area.removeFromRight (300.0f);
    area.removeFromRight (28.0f);

    auto arrows = area.removeFromBottom (24.0f);
    prevArea = arrows.removeFromLeft (30.0f);
    nextArea = arrows.removeFromLeft (30.0f);
    nameArea = area;
}

void Display::timerCallback()
{
    if (processor.getCurrentProgram() != shownProgram)
    {
        shownProgram = processor.getCurrentProgram();
        repaint();
    }

    if (valueUntil > 0.0 && juce::Time::getMillisecondCounterHiRes() > valueUntil)
    {
        valueUntil = 0.0;
        repaint();
    }

    // Oszilloskop: Fenster ab einem steigenden Nulldurchgang, damit es steht.
    processor.scope.snapshot (snapshot.data(), static_cast<int> (snapshot.size()));

    int start = 0;
    for (int i = 1; i < static_cast<int> (snapshot.size()) - scopeSamples; ++i)
        if (snapshot[static_cast<size_t> (i - 1)] < 0.0f && snapshot[static_cast<size_t> (i)] >= 0.0f)
        {
            start = i;
            break;
        }

    wave.clear();
    const auto midY = scopeArea.getCentreY();
    const auto halfHeight = scopeArea.getHeight() * 0.45f;
    for (int i = 0; i < scopeSamples; ++i)
    {
        const auto x = scopeArea.getX() + scopeArea.getWidth() * static_cast<float> (i) / (scopeSamples - 1);
        const auto s = juce::jlimit (-1.0f, 1.0f, snapshot[static_cast<size_t> (start + i)] * 3.0f);
        const auto y = midY - s * halfHeight;
        if (i == 0) wave.startNewSubPath (x, y);
        else        wave.lineTo (x, y);
    }

    repaint (scopeArea.expanded (6.0f).getSmallestIntegerContainer());
}

juce::String Display::statusText() const
{
    auto& state = processor.state;
    const auto voice  = state.getParameter (params::id::voiceMode)->getCurrentValueAsText().toUpperCase();
    const auto unison = state.getParameter (params::id::unison)->getCurrentValueAsText();
    const auto chorus = state.getParameter (params::id::chorus)->getCurrentValueAsText();

    juce::String text = voice;
    if (unison != "Off")
        text << "  /  UNISON " << unison;
    text << "  /  CHORUS " << chorus.toUpperCase();

    if (const auto dust = state.getParameter (params::id::dust)->getValue(); dust > 0.005f)
        text << "  /  DUST " << juce::roundToInt (dust * 100.0f) << "%";
    if (const auto dist = state.getParameter (params::id::dist)->getValue(); dist > 0.005f)
        text << "  /  DIST " << juce::roundToInt (dist * 100.0f) << "%";
    if (state.getParameter (params::id::sub808Level)->getValue() > 0.005f)
        text << "  /  808";
    if (state.getParameter (params::id::throwFx)->getValue() > 0.5f)
        text << "  /  THROW";
    return text;
}

void Display::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto bounds = getLocalBounds().toFloat();
    const auto radius = 18.0f;

    // Glas mit Rahmen in Gehäusefarbe
    juce::Path glass;
    glass.addRoundedRectangle (bounds, radius);
    g.setGradientFill (juce::ColourGradient (juce::Colour (0xff1a1a1b), bounds.getX(), bounds.getY(),
                                             p.display, bounds.getX(), bounds.getBottom(), false));
    g.fillPath (glass);

    // feines Punktraster wie ein LCD
    g.saveState();
    g.reduceClipRegion (glass);
    g.setColour (juce::Colours::white.withAlpha (0.035f));
    for (auto y = bounds.getY() + 6.0f; y < bounds.getBottom(); y += 6.0f)
        for (auto x = bounds.getX() + 6.0f; x < bounds.getRight(); x += 6.0f)
            g.fillRect (x, y, 1.5f, 1.5f);
    g.restoreState();

    g.setColour (juce::Colours::white.withAlpha (0.10f));
    g.drawRoundedRectangle (bounds.reduced (0.5f), radius, 1.0f);

    // Preset bzw. Wert
    const auto showingValue = valueUntil > 0.0;
    auto text = nameArea;
    g.setColour (p.accent.withAlpha (0.7f));
    g.setFont (pixelFont (14.0f).withExtraKerningFactor (0.08f));
    g.drawText (showingValue ? valueName.toUpperCase() : presets::category (shownProgram).toUpperCase(),
                text.removeFromTop (22.0f), juce::Justification::centredLeft, false);

    g.setColour (p.accent);
    auto title = text.removeFromTop (58.0f);
    const auto mainText = (showingValue ? valueText : presets::name (shownProgram)).toUpperCase();
    g.setFont (dotFont (50.0f));
    g.drawFittedText (mainText, title.toNearestInt(), juce::Justification::centredLeft, 1, 0.6f);

    g.setColour (juce::Colours::white.withAlpha (0.45f));
    g.setFont (pixelFont (12.0f).withExtraKerningFactor (0.04f));
    g.drawText (statusText(), text.removeFromTop (22.0f), juce::Justification::centredLeft, false);

    // Pfeile
    for (auto [area, left] : { std::pair { prevArea, true }, { nextArea, false } })
    {
        const auto c = area.getCentre();
        juce::Path tri;
        if (left) tri.addTriangle (c.x + 4.0f, c.y - 6.0f, c.x + 4.0f, c.y + 6.0f, c.x - 5.0f, c.y);
        else      tri.addTriangle (c.x - 4.0f, c.y - 6.0f, c.x - 4.0f, c.y + 6.0f, c.x + 5.0f, c.y);
        g.setColour (p.accent.withAlpha (0.85f));
        g.fillPath (tri);
    }

    // Oszilloskop mit Mittellinie und Zeitstrichen
    g.setColour (juce::Colours::white.withAlpha (0.12f));
    for (int i = 0; i <= 20; ++i)
    {
        const auto x = scopeArea.getX() + scopeArea.getWidth() * static_cast<float> (i) / 20.0f;
        const auto len = i % 5 == 0 ? 6.0f : 3.0f;
        g.fillRect (x, scopeArea.getBottom() - len, 1.0f, len);
    }
    g.setColour (juce::Colours::white.withAlpha (0.18f));
    for (auto x = scopeArea.getX(); x < scopeArea.getRight(); x += 4.0f)
        g.fillRect (x, scopeArea.getCentreY(), 1.5f, 1.0f);

    g.setColour (p.accent.withAlpha (0.18f));
    g.strokePath (wave, juce::PathStrokeType (5.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    g.setColour (p.accent);
    g.strokePath (wave, juce::PathStrokeType (1.6f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Abspielmarke wie bei einem Recorder
    const auto markX = scopeArea.getX() + scopeArea.getWidth() * 0.62f;
    g.setColour (p.led);
    g.fillRect (markX - 0.75f, scopeArea.getY(), 1.5f, scopeArea.getHeight() - 8.0f);
    g.fillEllipse (markX - 3.0f, scopeArea.getY() - 3.0f, 6.0f, 6.0f);
}

void Display::mouseDown (const juce::MouseEvent& e)
{
    if (prevArea.expanded (4.0f).contains (e.position))      stepPreset (-1);
    else if (nextArea.expanded (4.0f).contains (e.position)) stepPreset (1);
    else if (nameArea.contains (e.position))                 openPresetMenu();
}

void Display::stepPreset (int delta)
{
    const auto n = presets::count();
    selectPreset ((processor.getCurrentProgram() + delta + n) % n);
}

void Display::selectPreset (int index)
{
    processor.setCurrentProgram (index);
    processor.updateHostDisplay (juce::AudioProcessor::ChangeDetails{}.withProgramChanged (true));
    valueUntil = 0.0;
    repaint();
}

void Display::openPresetMenu()
{
    juce::PopupMenu menu;
    std::map<juce::String, juce::PopupMenu> categories;
    juce::StringArray order;

    menu.addItem (1, presets::name (0), true, processor.getCurrentProgram() == 0);

    for (int i = 1; i < presets::count(); ++i)
    {
        const auto cat = presets::category (i);
        if (! order.contains (cat))
            order.add (cat);
        categories[cat].addItem (i + 1, presets::name (i), true, processor.getCurrentProgram() == i);
    }

    for (const auto& cat : order)
        menu.addSubMenu (cat, categories[cat], true, nullptr,
                         presets::category (processor.getCurrentProgram()) == cat);

    menu.showMenuAsync (juce::PopupMenu::Options().withTargetComponent (this)
                                                  .withTargetScreenArea (localAreaToGlobal (nameArea.toNearestInt())),
                        [safe = juce::Component::SafePointer<Display> (this)] (int result)
                        {
                            if (safe != nullptr && result > 0)
                                safe->selectPreset (result - 1);
                        });
}
}
