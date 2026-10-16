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
    auto area = getLocalBounds().toFloat().reduced (34.0f, 26.0f);
    scopeArea = area.removeFromRight (360.0f);
    area.removeFromRight (30.0f);

    auto arrows = area.removeFromBottom (26.0f);
    prevArea = arrows.removeFromLeft (34.0f);
    nextArea = arrows.removeFromLeft (34.0f);
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
    return text;
}

void Display::paint (juce::Graphics& g)
{
    const auto bounds = getLocalBounds().toFloat();
    const auto radius = 26.0f;

    // Glas
    g.setGradientFill (juce::ColourGradient (juce::Colour (0xff1c1c1d), bounds.getX(), bounds.getY(),
                                             colour::display, bounds.getX(), bounds.getBottom(), false));
    g.fillRoundedRectangle (bounds, radius);

    juce::Path sheen;
    sheen.startNewSubPath (bounds.getX(), bounds.getY());
    sheen.lineTo (bounds.getRight() * 0.62f, bounds.getY());
    sheen.quadraticTo (bounds.getRight() * 0.42f, bounds.getCentreY(), bounds.getX(), bounds.getBottom() * 0.86f);
    sheen.closeSubPath();
    g.saveState();
    g.reduceClipRegion (sheen);
    juce::Path clip;
    clip.addRoundedRectangle (bounds, radius);
    g.reduceClipRegion (clip);
    g.setColour (juce::Colours::white.withAlpha (0.035f));
    g.fillRect (bounds);
    g.restoreState();

    g.setColour (juce::Colours::white.withAlpha (0.10f));
    g.drawRoundedRectangle (bounds.reduced (0.5f), radius, 1.0f);

    // Preset bzw. Wert
    const auto showingValue = valueUntil > 0.0;
    auto text = nameArea;
    g.setColour (colour::accent.withAlpha (0.75f));
    drawTracked (g, showingValue ? valueName.toUpperCase() : presets::category (shownProgram).toUpperCase(),
                 text.removeFromTop (22.0f), 12.0f, juce::Justification::centredLeft, 0.12f);

    g.setColour (colour::accent);
    auto title = text.removeFromTop (60.0f);
    const auto mainText = showingValue ? valueText : presets::name (shownProgram);
    g.setFont (font (38.0f));
    g.drawFittedText (mainText, title.toNearestInt(), juce::Justification::centredLeft, 1, 0.7f);

    g.setColour (juce::Colours::white.withAlpha (0.35f));
    drawTracked (g, statusText(), text.removeFromTop (22.0f), 9.0f, juce::Justification::centredLeft, 0.1f);

    // Pfeile
    for (auto [area, left] : { std::pair { prevArea, true }, { nextArea, false } })
    {
        const auto c = area.getCentre();
        juce::Path tri;
        if (left) tri.addTriangle (c.x + 4.0f, c.y - 6.0f, c.x + 4.0f, c.y + 6.0f, c.x - 5.0f, c.y);
        else      tri.addTriangle (c.x - 4.0f, c.y - 6.0f, c.x - 4.0f, c.y + 6.0f, c.x + 5.0f, c.y);
        g.setColour (colour::accent.withAlpha (0.85f));
        g.fillPath (tri);
    }

    // Oszilloskop
    g.setColour (juce::Colours::white.withAlpha (0.06f));
    for (int i = 0; i <= 4; ++i)
    {
        const auto y = scopeArea.getY() + scopeArea.getHeight() * static_cast<float> (i) / 4.0f;
        g.drawHorizontalLine (juce::roundToInt (y), scopeArea.getX(), scopeArea.getRight());
    }

    g.setColour (colour::accent.withAlpha (0.18f));
    g.strokePath (wave, juce::PathStrokeType (5.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    g.setColour (colour::accent);
    g.strokePath (wave, juce::PathStrokeType (1.6f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
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
