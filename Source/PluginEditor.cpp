#include "PluginEditor.h"
#include "Parameters.h"

namespace
{
    namespace id = params::id;

    const juce::Identifier uiScaleProperty { "uiScale" };
    const juce::Identifier uiPageProperty { "uiPage" };
    constexpr auto themeKey = "theme";

    // Raster: drei Spalten je Reihe, Breiten nach Inhalt
    constexpr int left = 32, right = 1168;
    constexpr int pageTop = 260, pageBottom = 776;
    constexpr int soundRow[] = { pageTop, 432, 604, pageBottom };
    constexpr int characterRow[] = { pageTop, 518, pageBottom };
    constexpr int soundCols[3][4] = { { left, 512, 912, right },
                                      { left, 472, 832, right },
                                      { left, 432, 872, right } };
    constexpr int characterCols[2][4] = { { left, 472, 832, right },
                                          { left, 472, 832, right } };

    // Knopfgrößen (Höhe inkl. Beschriftung)
    constexpr int soundKnob = 98, soundHero = 114;
    constexpr int characterKnob = 110, characterHero = 156;

    juce::Rectangle<int> cell (const int* rows, const int (*cols)[4], int row, int col)
    {
        return { cols[row][col], rows[row], cols[row][col + 1] - cols[row][col], rows[row + 1] - rows[row] };
    }

    juce::PropertiesFile::Options settingsOptions()
    {
        juce::PropertiesFile::Options o;
        o.applicationName = "CONTRA-86";
        o.folderName = "CONTRABEATZ";
        o.filenameSuffix = ".settings";
        o.osxLibrarySubFolder = "Application Support";
        return o;
    }
}

Contra86Panel::Contra86Panel (Contra86Processor& p)
    : processor (p), display (p), settings (settingsOptions())
{
    addAndMakeVisible (display);

    // ── SOUND ─────────────────────────────────────────────────────────
    sections.push_back ({ 0, "OSC A", cell (soundRow, soundCols, 0, 0),
                          { &segment (id::pwmSource, { "LFO", "MAN", "ENV" }),
                            &segment (id::range, { "16'", "8'", "4'" }) },
                          { knob (id::sawLevel, "Saw", soundKnob), knob (id::pulseLevel, "Pulse", soundKnob),
                            knob (id::subLevel, "Sub", soundKnob), knob (id::noiseLevel, "Noise", soundKnob),
                            knob (id::pw, "PW", soundKnob) } });

    sections.push_back ({ 0, "OSC B", cell (soundRow, soundCols, 0, 1),
                          { &segment (id::oscBWave, { "SAW", "SQR", "PLS", "NSE" }) },
                          { knob (id::oscBOctave, "Oct", soundKnob), knob (id::oscBSemi, "Semi", soundKnob),
                            knob (id::oscBFine, "Fine", soundKnob) } });

    auto& blend = own (std::make_unique<ui::Crossfader> (processor.state, id::blend,
                                                         [this] (const juce::String& n, const juce::String& v) { display.showValue (n, v); }));
    sections.push_back ({ 0, "LAYER", cell (soundRow, soundCols, 0, 2), {}, { { &blend, 1.0f, 84 } } });

    sections.push_back ({ 0, "FILTER", cell (soundRow, soundCols, 1, 0), {},
                          { knob (id::hpf, "HPF", soundKnob), knob (id::cutoff, "Cutoff", soundHero, true),
                            knob (id::resonance, "Reso", soundKnob), knob (id::envAmount, "Env 1", soundKnob),
                            knob (id::keyTrack, "Key", soundKnob) } });

    sections.push_back ({ 0, "LFO", cell (soundRow, soundCols, 1, 1), {},
                          { knob (id::lfoRate, "Rate", soundKnob), knob (id::lfoDelay, "Delay", soundKnob),
                            knob (id::lfoPitch, "Pitch", soundKnob), knob (id::lfoFilter, "Filter", soundKnob) } });

    sections.push_back ({ 0, "UNISON", cell (soundRow, soundCols, 1, 2),
                          { &segment (id::unison, { "OFF", "3", "5", "7" }) },
                          { knob (id::unisonDetune, "Detune", soundKnob), knob (id::unisonWidth, "Width", soundKnob) } });

    sections.push_back ({ 0, "ENV 1", cell (soundRow, soundCols, 2, 0), {},
                          { knob (id::attack, "A", soundKnob), knob (id::decay, "D", soundKnob),
                            knob (id::sustain, "S", soundKnob), knob (id::release, "R", soundKnob) } });

    sections.push_back ({ 0, "ENV 2", cell (soundRow, soundCols, 2, 1),
                          { &segment (id::vcaMode, { "ENV 1", "GATE", "ENV 2" }) },
                          { knob (id::ampAttack, "A", soundKnob), knob (id::ampDecay, "D", soundKnob),
                            knob (id::ampSustain, "S", soundKnob), knob (id::ampRelease, "R", soundKnob) } });

    sections.push_back ({ 0, "VOICE", cell (soundRow, soundCols, 2, 2),
                          { &segment (id::voiceMode, { "POLY", "MONO" }) },
                          { knob (id::glide, "Glide", soundKnob), knob (id::velocity, "Velo", soundKnob) } });

    // ── CHARACTER ─────────────────────────────────────────────────────
    sections.push_back ({ 1, "DUST", cell (characterRow, characterCols, 0, 0), {},
                          { knob (id::dust, "Dust", characterHero, true), knob (id::dustTape, "Tape", characterKnob),
                            knob (id::dustCrush, "Crush", characterKnob), knob (id::dustNoise, "Noise", characterKnob),
                            knob (id::dustTone, "Tone", characterKnob) } });
    sections.back().items[0].weight = 1.5f;

    sections.push_back ({ 1, "808", cell (characterRow, characterCols, 0, 1),
                          { &segment (id::subOctave, { "0", "-1" }) },
                          { knob (id::sub808Level, "Level", characterHero, true), knob (id::subDecay, "Decay", characterKnob),
                            knob (id::subDrop, "Drop", characterKnob), knob (id::subDrive, "Drive", characterKnob) } });
    sections.back().items[0].weight = 1.5f;

    sections.push_back ({ 1, "CHARACTER", cell (characterRow, characterCols, 0, 2), {},
                          { knob (id::drive, "Drive", characterKnob), knob (id::tube, "Tube", characterKnob),
                            knob (id::drift, "Drift", characterKnob) } });

    sections.push_back ({ 1, "SPACE", cell (characterRow, characterCols, 1, 0), {},
                          { knob (id::delayTime, "Time", characterKnob), knob (id::delayFeedback, "Fdbk", characterKnob),
                            knob (id::delayMix, "Delay", characterKnob), knob (id::reverbSize, "Size", characterKnob),
                            knob (id::reverbMix, "Verb", characterKnob) } });

    auto& throwPad = own (std::make_unique<ui::MomentaryPad> (processor.state, id::throwFx, "Throw",
                                                              [this] (const juce::String& n, const juce::String& v) { display.showValue (n, v); }));
    sections.push_back ({ 1, "LEAD", cell (characterRow, characterCols, 1, 1), {},
                          { knob (id::dist, "Dist", characterHero, true), { &throwPad, 1.0f, 128 } } });

    sections.push_back ({ 1, "MOD FX", cell (characterRow, characterCols, 1, 2),
                          { &segment (id::chorus, { "OFF", "I", "II", "I+II" }) },
                          { { &segment (id::phaser, { "OFF", "SLOW", "FAST" }), 1.7f, 30 },
                            knob (id::phaserMix, "Phase", characterKnob) } });

    volumeKnob = dynamic_cast<ui::Knob*> (knob (id::volume, "Volume", 112, true).component);

    // ── Seiten und Theme ──────────────────────────────────────────────
    addAndMakeVisible (soundTab);
    addAndMakeVisible (characterTab);
    soundTab.onClick = [this] { setPage (0); };
    characterTab.onClick = [this] { setPage (1); };

    addAndMakeVisible (themeSwitch);
    themeSwitch.setTitle ("Theme");
    themeSwitch.onSelect = [this] (int i) { setThemeMode (static_cast<ui::ThemeMode> (i), true); };
    setThemeMode (static_cast<ui::ThemeMode> (juce::jlimit (0, 2, settings.getIntValue (themeKey, 0))), false);
    startTimer (20000);

    setPage (juce::jlimit (0, 1, static_cast<int> (processor.state.state.getProperty (uiPageProperty, 0))));
}

template <typename T>
T& Contra86Panel::own (std::unique_ptr<T> component)
{
    auto& c = *component;
    addAndMakeVisible (c);
    controls.push_back (std::move (component));
    return c;
}

Contra86Panel::Item Contra86Panel::knob (const juce::String& paramId, const juce::String& label, int height, bool hero)
{
    auto show = [this] (const juce::String& n, const juce::String& v) { display.showValue (n, v); };
    auto& k = own (std::make_unique<ui::Knob> (processor.state, paramId, label, show, hero));
    return { &k, 1.0f, height };
}

ui::SegmentedControl& Contra86Panel::segment (const juce::String& paramId, juce::StringArray labels)
{
    auto show = [this] (const juce::String& n, const juce::String& v) { display.showValue (n, v); };
    return own (std::make_unique<ui::SegmentedControl> (processor.state, paramId, std::move (labels), show));
}

void Contra86Panel::setPage (int newPage)
{
    page = newPage;
    soundTab.setActive (page == 0);
    characterTab.setActive (page == 1);

    for (const auto& section : sections)
    {
        for (auto* c : section.header)
            c->setVisible (section.page == page);
        for (const auto& item : section.items)
            item.component->setVisible (section.page == page);
    }

    processor.state.state.setProperty (uiPageProperty, page, nullptr);
    repaint();
}

void Contra86Panel::setThemeMode (ui::ThemeMode mode, bool save)
{
    themeMode = mode;
    themeSwitch.setSelected (static_cast<int> (mode));
    if (save)
    {
        settings.setValue (themeKey, static_cast<int> (mode));
        settings.saveIfNeeded();
    }
    applyTheme();
}

void Contra86Panel::previewTheme (ui::ThemeMode mode)
{
    setThemeMode (mode, false);
}

void Contra86Panel::applyTheme()
{
    const auto dark = ui::resolveDark (themeMode);
    ui::darkFlag() = dark;
    if (dark != shownDark)
    {
        shownDark = dark;
        repaint();
    }
}

void Contra86Panel::timerCallback()
{
    // Uhrzeit prüfen und die Einstellung anderer offener Fenster übernehmen
    settings.reload();
    const auto mode = static_cast<ui::ThemeMode> (juce::jlimit (0, 2, settings.getIntValue (themeKey, static_cast<int> (themeMode))));
    if (mode != themeMode)
        setThemeMode (mode, false);
    else
        applyTheme();
}

void Contra86Panel::layoutSection (const Section& section)
{
    auto area = section.area.reduced (16, 10);
    auto header = area.removeFromTop (30);

    for (auto* c : section.header)
    {
        const auto width = c->getNaturalWidth();
        c->setBounds (header.removeFromRight (width).withSizeKeepingCentre (width, 28));
        header.removeFromRight (10);
    }

    area.removeFromTop (4);
    auto totalWeight = 0.0f;
    for (const auto& item : section.items)
        totalWeight += item.weight;

    // Beschriftungen auf einer Grundlinie, kleine Elemente (Segmente) auf Knopfmitte
    // (seitenweit an der Hero-Höhe, damit die Reihe durchläuft)
    auto maxHeight = section.page == 0 ? soundHero : characterHero;
    for (const auto& item : section.items)
        maxHeight = std::max (maxHeight, item.height);
    const auto bottom = area.getCentreY() + maxHeight / 2;
    const auto knobCentre = bottom - 24 - (maxHeight - 24) / 2;

    const auto width = static_cast<float> (area.getWidth());
    auto x = static_cast<float> (area.getX());
    for (const auto& item : section.items)
    {
        const auto w = width * item.weight / totalWeight;
        const auto y = item.height < 60 ? knobCentre - item.height / 2 : bottom - item.height;
        item.component->setBounds (juce::roundToInt (x) + 2, y, juce::roundToInt (w) - 4, item.height);
        x += w;
    }
}

void Contra86Panel::resized()
{
    display.setBounds (left, 28, 780, 160);

    soundTab.setBounds (left, 204, 168, 44);
    characterTab.setBounds (left + 176, 204, 212, 44);
    themeSwitch.setBounds (right - themeSwitch.getNaturalWidth(), 212, themeSwitch.getNaturalWidth(), 28);

    for (const auto& section : sections)
        layoutSection (section);

    volumeKnob->setBounds (right - 104, 76, 104, 112);
}

void Contra86Panel::paintSpeaker (juce::Graphics& g, juce::Rectangle<float> area) const
{
    // radiales Lochraster, nach außen feiner
    const auto& p = ui::palette();
    const auto c = area.getCentre();
    const auto maxR = std::min (area.getWidth(), area.getHeight()) * 0.5f;

    g.setColour (p.ink.withAlpha (ui::darkFlag() ? 0.5f : 0.7f));
    g.fillEllipse (juce::Rectangle<float> (3.4f, 3.4f).withCentre (c));
    for (int ring = 1; ring <= 7; ++ring)
    {
        const auto r = maxR * static_cast<float> (ring) / 7.0f;
        const auto count = ring * 8;
        const auto size = 3.4f - 0.18f * static_cast<float> (ring);
        for (int i = 0; i < count; ++i)
        {
            const auto angle = juce::MathConstants<float>::twoPi * (static_cast<float> (i) + 0.5f * static_cast<float> (ring % 2)) / static_cast<float> (count);
            g.fillEllipse (juce::Rectangle<float> (size, size).withCentre (c.getPointOnCircumference (r, angle)));
        }
    }
}

void Contra86Panel::paint (juce::Graphics& g)
{
    using namespace ui;
    const auto& p = palette();
    const auto bounds = getLocalBounds().toFloat();

    // Gehäuse
    g.setGradientFill (juce::ColourGradient (p.bodyTop, 0.0f, 0.0f, p.bodyBottom, 0.0f, bounds.getBottom(), false));
    g.fillRect (bounds);
    g.setColour (p.edge.withMultipliedAlpha (0.8f));
    g.drawRoundedRectangle (bounds.reduced (6.0f), 22.0f, 1.2f);

    // Kopf rechts: Wortmarke, Lautsprecher
    const auto head = juce::Rectangle<float> (836.0f, 28.0f, static_cast<float> (right) - 836.0f, 160.0f);
    g.setColour (p.ink);
    g.setFont (font (34.0f).withExtraKerningFactor (0.02f));
    g.drawText ("CONTRA-86", head.withHeight (42.0f), juce::Justification::centredLeft, false);

    g.setColour (p.inkSoft);
    drawTracked (g, "RETRO POLY SYNTH", head.withTrimmedTop (46.0f).withHeight (16.0f), 11.0f, juce::Justification::centredLeft, 0.2f);
    g.setColour (p.accent);
    drawTracked (g, "CONTRABEATZ", head.withTrimmedTop (64.0f).withHeight (16.0f), 11.0f, juce::Justification::centredLeft, 0.2f);

    paintSpeaker (g, juce::Rectangle<float> (head.getX() + 4.0f, head.getY() + 88.0f, 96.0f, 72.0f).withSizeKeepingCentre (72.0f, 72.0f));

    // Raster der aktiven Seite
    const auto* rows = page == 0 ? soundRow : characterRow;
    const auto rowCount = page == 0 ? 3 : 2;

    g.setColour (p.line);
    for (int r = 0; r <= rowCount; ++r)
        g.fillRect (static_cast<float> (left), static_cast<float> (rows[r]), static_cast<float> (right - left), 1.0f);

    for (const auto& section : sections)
    {
        if (section.page != page)
            continue;

        const auto a = section.area.toFloat();
        g.setColour (p.line);
        if (a.getX() > left)
            g.fillRect (a.getX(), a.getY() + 14.0f, 1.0f, a.getHeight() - 28.0f);

        g.setColour (p.inkSoft);
        drawTracked (g, section.title, a.reduced (16.0f, 10.0f).removeFromTop (30.0f), 13.0f,
                     juce::Justification::centredLeft, 0.14f);
    }

    // Versionsmarke unten rechts
    g.setColour (p.inkSoft.withAlpha (0.7f));
    g.setFont (pixelFont (10.0f));
    g.drawText ("V" + juce::String (JucePlugin_VersionString), juce::Rectangle<float> (static_cast<float> (right) - 120.0f, 778.0f, 120.0f, 16.0f),
                juce::Justification::centredRight, false);
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
    setResizeLimits (juce::roundToInt (w * 0.5), juce::roundToInt (h * 0.5), juce::roundToInt (w * 1.6), juce::roundToInt (h * 1.6));
    if (auto* c = getConstrainer())
        c->setFixedAspectRatio (w / h);

    const auto scale = juce::jlimit (0.5, 1.6, static_cast<double> (contraProcessor.state.state.getProperty (uiScaleProperty, 1.0)));
    // Nie größer als der Bildschirm (mit Platz für Host-Fensterleiste)
    auto fitted = scale;
    if (const auto* display = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay())
        fitted = std::min ({ scale, (static_cast<double> (display->userBounds.getHeight()) - 90.0) / h,
                             (static_cast<double> (display->userBounds.getWidth()) - 40.0) / w });

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
