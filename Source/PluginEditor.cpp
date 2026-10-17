#include "PluginEditor.h"
#include "Parameters.h"

namespace
{
    namespace id = params::id;

    const juce::Identifier uiScaleProperty { "uiScale" };

    constexpr int gridLeft = 40, gridRight = 1000;
    constexpr int rowTop[] = { 254, 414, 574, 734, 894 };
    constexpr int footerTop = rowTop[4];
}

Contra86Panel::Contra86Panel (Contra86Processor& p)
    : processor (p), display (p)
{
    addAndMakeVisible (display);

    auto row = [] (int r, int x, int w) { return juce::Rectangle<int> (x, rowTop[r], w, rowTop[r + 1] - rowTop[r]); };

    sections.push_back ({ "OSC", row (0, gridLeft, 660),
                          { { &segment (id::pwmSource, { "LFO", "MAN", "ENV" }), 168 },
                            { &segment (id::range, { "16'", "8'", "4'" }), 150 } },
                          { &knob (id::sawLevel, "Saw"), &knob (id::pulseLevel, "Pulse"), &knob (id::subLevel, "Sub"),
                            &knob (id::noiseLevel, "Noise"), &knob (id::pw, "PW") } });

    sections.push_back ({ "UNISON", row (0, 700, 300),
                          { { &segment (id::unison, { "OFF", "3", "5", "7" }), 180 } },
                          { &knob (id::unisonDetune, "Detune"), &knob (id::unisonWidth, "Width") } });

    sections.push_back ({ "FILTER", row (1, gridLeft, 450), {},
                          { &knob (id::hpf, "HPF"), &knob (id::cutoff, "Cutoff", true), &knob (id::resonance, "Reso"),
                            &knob (id::envAmount, "Env 1"), &knob (id::keyTrack, "Key") } });

    sections.push_back ({ "LFO", row (1, 490, 270), {},
                          { &knob (id::lfoRate, "Rate"), &knob (id::lfoDelay, "Delay"),
                            &knob (id::lfoPitch, "Pitch"), &knob (id::lfoFilter, "Filter") } });

    sections.push_back ({ "VOICE", row (1, 760, 240),
                          { { &segment (id::voiceMode, { "POLY", "MONO" }), 136 } },
                          { &knob (id::glide, "Glide"), &knob (id::velocity, "Velo") } });

    sections.push_back ({ "ENV 1 FILTER", row (2, gridLeft, 280), {},
                          { &knob (id::attack, "A"), &knob (id::decay, "D"), &knob (id::sustain, "S"), &knob (id::release, "R") } });

    sections.push_back ({ "ENV 2 AMP", row (2, 320, 330),
                          { { &segment (id::vcaMode, { "ENV 1", "GATE", "ENV 2" }), 190 } },
                          { &knob (id::ampAttack, "A"), &knob (id::ampDecay, "D"), &knob (id::ampSustain, "S"), &knob (id::ampRelease, "R") } });

    sections.push_back ({ "SPACE", row (2, 650, 350), {},
                          { &knob (id::delayTime, "Time"), &knob (id::delayFeedback, "Fdbk"), &knob (id::delayMix, "Delay"),
                            &knob (id::reverbSize, "Size"), &knob (id::reverbMix, "Verb") } });

    sections.push_back ({ "CHARACTER", row (3, gridLeft, 480), {},
                          { &knob (id::drive, "Drive"), &knob (id::tube, "Tube"), &knob (id::drift, "Drift"),
                            &knob (id::dust, "Dust", true) } });

    sections.push_back ({ "MOD FX", row (3, 520, 480),
                          { { &segment (id::phaser, { "OFF", "SLOW", "FAST" }), 170 },
                            { &segment (id::chorus, { "OFF", "I", "II", "I+II" }), 178 } },
                          { &knob (id::phaserMix, "Phase") } });

    volumeKnob = &knob (id::volume, "Volume", true);
}

ui::Knob& Contra86Panel::knob (const juce::String& paramId, const juce::String& label, bool hero)
{
    auto show = [this] (const juce::String& n, const juce::String& v) { display.showValue (n, v); };
    auto& k = *knobs.emplace_back (std::make_unique<ui::Knob> (processor.state, paramId, label, show, hero));
    addAndMakeVisible (k);
    return k;
}

ui::SegmentedControl& Contra86Panel::segment (const juce::String& paramId, juce::StringArray labels)
{
    auto show = [this] (const juce::String& n, const juce::String& v) { display.showValue (n, v); };
    auto& s = *segments.emplace_back (std::make_unique<ui::SegmentedControl> (processor.state, paramId, std::move (labels), show));
    addAndMakeVisible (s);
    return s;
}

void Contra86Panel::layoutSection (const Section& section)
{
    auto area = section.area.reduced (14, 10);
    auto header = area.removeFromTop (26);

    for (const auto& [seg, width] : section.segments)
    {
        seg->setBounds (header.removeFromRight (width).withSizeKeepingCentre (width, 24));
        header.removeFromRight (8);
    }

    area.removeFromTop (6);
    const auto cellWidth = area.getWidth() / static_cast<int> (section.knobs.size());
    for (auto* k : section.knobs)
        k->setBounds (area.removeFromLeft (cellWidth).withSizeKeepingCentre (cellWidth, 100));
}

void Contra86Panel::resized()
{
    display.setBounds (gridLeft, 34, gridRight - gridLeft, 196);

    for (const auto& section : sections)
        layoutSection (section);

    volumeKnob->setBounds (gridRight - 84, footerTop + 2, 84, 70);
}

void Contra86Panel::paint (juce::Graphics& g)
{
    using namespace ui;
    const auto bounds = getLocalBounds().toFloat();

    // Gehäuse
    g.setColour (colour::bezel);
    g.fillRoundedRectangle (bounds, 46.0f);

    const auto panel = bounds.reduced (12.0f);
    g.setGradientFill (juce::ColourGradient (colour::panelTop, panel.getX(), panel.getY(),
                                             colour::panelBottom, panel.getRight(), panel.getBottom(), false));
    g.fillRoundedRectangle (panel, 36.0f);
    g.setColour (juce::Colours::white.withAlpha (0.65f));
    g.drawRoundedRectangle (panel.reduced (1.0f), 35.0f, 1.2f);

    // Raster
    g.setColour (colour::line);
    for (int r = 0; r < 5; ++r)
        g.fillRect (static_cast<float> (gridLeft), static_cast<float> (rowTop[r]), static_cast<float> (gridRight - gridLeft), 1.0f);

    for (const auto& section : sections)
    {
        const auto a = section.area.toFloat();
        if (a.getX() > gridLeft)
            g.fillRect (a.getX(), a.getY() + 12.0f, 1.0f, a.getHeight() - 24.0f);
    }

    for (const auto& section : sections)
    {
        g.setColour (colour::inkSoft);
        drawTracked (g, section.title, section.area.toFloat().reduced (14.0f, 10.0f).removeFromTop (26.0f),
                     12.0f, juce::Justification::centredLeft, 0.14f);
    }

    // Fußzeile: Wortmarke, Lautsprecher-Raster
    const auto footer = juce::Rectangle<float> (static_cast<float> (gridLeft), static_cast<float> (footerTop),
                                                static_cast<float> (gridRight - gridLeft), 70.0f);

    g.setColour (colour::ink);
    g.setFont (font (40.0f).withExtraKerningFactor (0.02f));
    g.drawText ("CONTRA-86", footer.withTrimmedLeft (12.0f).withWidth (430.0f), juce::Justification::centredLeft, false);

    g.setColour (colour::inkSoft);
    drawTracked (g, "RETRO POLY SYNTH", footer.withTrimmedLeft (462.0f).withWidth (200.0f).withTrimmedTop (18.0f).withHeight (16.0f),
                 10.0f, juce::Justification::centredLeft, 0.2f);
    drawTracked (g, "CONTRABEATZ", footer.withTrimmedLeft (462.0f).withWidth (200.0f).withTrimmedTop (36.0f).withHeight (16.0f),
                 10.0f, juce::Justification::centredLeft, 0.2f);

    g.setColour (colour::ink.withAlpha (0.55f));
    for (int r = 0; r < 6; ++r)
        for (int c = 0; c < 18; ++c)
            g.fillEllipse (690.0f + static_cast<float> (c) * 9.0f, footer.getY() + 14.0f + static_cast<float> (r) * 9.0f, 3.2f, 3.2f);
}

//==============================================================================
Contra86Editor::Contra86Editor (Contra86Processor& p)
    : AudioProcessorEditor (p), contraProcessor (p), panel (p)
{
    setLookAndFeel (&lookAndFeel);
    addAndMakeVisible (panel);
    panel.setBounds (0, 0, ui::designWidth, ui::designHeight);

    const auto w = static_cast<double> (ui::designWidth);
    const auto h = static_cast<double> (ui::designHeight);
    setResizable (true, true);
    setResizeLimits (juce::roundToInt (w * 0.5), juce::roundToInt (h * 0.5), juce::roundToInt (w * 1.5), juce::roundToInt (h * 1.5));
    if (auto* c = getConstrainer())
        c->setFixedAspectRatio (w / h);

    const auto scale = juce::jlimit (0.5, 1.5, static_cast<double> (contraProcessor.state.state.getProperty (uiScaleProperty, 1.0)));
    // Nie größer als der Bildschirm (mit Platz für Host-Fensterleiste)
    auto fitted = scale;
    if (const auto* display = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay())
        fitted = std::min (scale, (static_cast<double> (display->userBounds.getHeight()) - 120.0) / h);

    setSize (juce::roundToInt (w * std::max (0.5, fitted)), juce::roundToInt (h * std::max (0.5, fitted)));
}

Contra86Editor::~Contra86Editor()
{
    setLookAndFeel (nullptr);
}

void Contra86Editor::resized()
{
    const auto scale = static_cast<float> (getWidth()) / static_cast<float> (ui::designWidth);
    panel.setTransform (juce::AffineTransform::scale (scale));
    contraProcessor.state.state.setProperty (uiScaleProperty, scale, nullptr);
}
