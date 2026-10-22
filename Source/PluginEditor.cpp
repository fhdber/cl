#include "PluginEditor.h"
#include "Parameters.h"

namespace
{
    namespace id = params::id;
    using ui::Family;

    constexpr auto themeKey = "theme";

    constexpr int left = 32, right = 1168;

    // PLAY
    const juce::Rectangle<int> visualCard { 32, 76, 744, 392 }, padCard { 792, 76, 376, 392 };
    const juce::Rectangle<int> soundCard { 32, 484, 1136, 156 }, chainCard { 32, 656, 1136, 124 };

    // EDIT: Karten-Reihen und Spalten
    constexpr int editTop = 252, editGap = 12, editBottom = 776;
    constexpr int soundRows = 3, characterRows = 2;
    constexpr int soundCols[3][4] = { { left, 512, 912, right },
                                      { left, 472, 832, right },
                                      { left, 432, 872, right } };
    constexpr int characterCols[2][4] = { { left, 472, 832, right },
                                          { left, 472, 832, right } };

    // Reglerhöhen inkl. Beschriftung
    constexpr int editKnob = 80, editHero = 96, characterKnob = 92, characterHero = 124;

    juce::Rectangle<int> editRow (int rows, int row)
    {
        const auto h = (editBottom - editTop - (rows - 1) * editGap) / rows;
        return { left, editTop + row * (h + editGap), right - left, h };
    }

    juce::Rectangle<int> cell (int rows, const int (*cols)[4], int row, int col)
    {
        const auto r = editRow (rows, row);
        return { cols[row][col], r.getY(), cols[row][col + 1] - cols[row][col], r.getHeight() };
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

    // Modul der Effektkette mit Titel oben, Steuerung in der Mitte, Beschriftung unten
    class Module final : public juce::Component
    {
    public:
        Module (juce::String moduleTitle, juce::String moduleCaption, ui::Segments& inner)
            : title (std::move (moduleTitle)), caption (std::move (moduleCaption)), control (inner)
        {
            addAndMakeVisible (control);
        }

        void resized() override
        {
            const auto natural = control.getNaturalWidth();
            control.setBounds (getLocalBounds().withSizeKeepingCentre (std::min (getWidth(), natural), 30));
        }

        void paint (juce::Graphics& g) override
        {
            const auto& p = ui::palette();
            auto area = getLocalBounds().toFloat();
            g.setColour (p.ink);
            g.setFont (ui::font (13.0f, ui::Weight::semibold));
            g.drawText (title, area.removeFromTop (20.0f), juce::Justification::centred, false);
            g.setColour (p.inkSoft);
            g.setFont (ui::font (12.0f, ui::Weight::regular));
            g.drawText (caption, area.removeFromBottom (16.0f), juce::Justification::centred, false);
        }

    private:
        juce::String title, caption;
        ui::Segments& control;
    };
}

Contra86Panel::Contra86Panel (Contra86Processor& p)
    : processor (p),
      show ([this] (juce::RangedAudioParameter& param) { display.showParameter (param); }),
      display (p),
      settings (settingsOptions())
{
    addAndMakeVisible (display);

    // ── PLAY ──────────────────────────────────────────────────────────
    pad = &own (std::make_unique<ui::CharacterPad> (processor.state, id::dust, id::tube, show));

    playKnobs = { knob (id::cutoff, "Cutoff", 112, { Family::tone, true }),
                  knob (id::resonance, "Reso", 88, { Family::tone }),
                  knob (id::envAmount, "Env", 88, { Family::tone }),
                  knob (id::ampAttack, "Attack", 88, { Family::motion }),
                  knob (id::ampRelease, "Release", 88, { Family::motion }),
                  knob (id::blend, "Blend", 88, { Family::tone }),
                  knob (id::sub808Level, "808", 88, { Family::sub }),
                  knob (id::glide, "Glide", 88, { Family::motion }) };
    throwButton = &own (std::make_unique<ui::ThrowButton> (processor.state, id::throwFx, show));

    auto& chorusSwitch = segment (id::chorus, { "Off", "I", "II", "I+II" });
    chain = { knob (id::dist, "Drive", 96, { Family::heat, false, "Dist" }),
              { &own (std::make_unique<Module> ("Chorus", "Mode", chorusSwitch)), 1.3f, 96 },
              knob (id::phaserMix, "Mix", 96, { Family::space, false, "Phaser" }),
              knob (id::delayMix, "Mix", 96, { Family::space, false, "Delay" }),
              knob (id::reverbMix, "Mix", 96, { Family::space, false, "Reverb" }),
              knob (id::dustTape, "Tape", 96, { Family::dust, false, "Dust" }),
              knob (id::volume, "Volume", 96, { Family::tone, false, "Out" }) };

    // ── EDIT / Sound ──────────────────────────────────────────────────
    sections.push_back ({ editSound, "Osc A", cell (soundRows, soundCols, 0, 0),
                          { &segment (id::pwmSource, { "LFO", "Man", "Env" }), &segment (id::range, { "16'", "8'", "4'" }) },
                          { knob (id::sawLevel, "Saw", editKnob, {}), knob (id::pulseLevel, "Pulse", editKnob, {}),
                            knob (id::subLevel, "Sub", editKnob, {}), knob (id::noiseLevel, "Noise", editKnob, {}),
                            knob (id::pw, "PW", editKnob, {}) } });

    sections.push_back ({ editSound, "Osc B", cell (soundRows, soundCols, 0, 1),
                          { &segment (id::oscBWave, { "Saw", "Sqr", "Pls", "Nse" }) },
                          { knob (id::oscBOctave, "Oct", editKnob, {}), knob (id::oscBSemi, "Semi", editKnob, {}),
                            knob (id::oscBFine, "Fine", editKnob, {}) } });

    sections.push_back ({ editSound, "Layer", cell (soundRows, soundCols, 0, 2), {},
                          { { &own (std::make_unique<ui::Crossfader> (processor.state, id::blend, show)), 1.0f, 70 } } });

    sections.push_back ({ editSound, "Filter", cell (soundRows, soundCols, 1, 0), {},
                          { knob (id::hpf, "HPF", editKnob, {}), knob (id::cutoff, "Cutoff", editHero, { Family::tone, true }),
                            knob (id::resonance, "Reso", editKnob, {}), knob (id::envAmount, "Env 1", editKnob, {}),
                            knob (id::keyTrack, "Key", editKnob, {}) } });

    sections.push_back ({ editSound, "LFO", cell (soundRows, soundCols, 1, 1), {},
                          { knob (id::lfoRate, "Rate", editKnob, { Family::motion }), knob (id::lfoDelay, "Delay", editKnob, { Family::motion }),
                            knob (id::lfoPitch, "Pitch", editKnob, { Family::motion }), knob (id::lfoFilter, "Filter", editKnob, { Family::motion }) } });

    sections.push_back ({ editSound, "Unison", cell (soundRows, soundCols, 1, 2),
                          { &segment (id::unison, { "Off", "3", "5", "7" }) },
                          { knob (id::unisonDetune, "Detune", editKnob, {}), knob (id::unisonWidth, "Width", editKnob, { Family::space }) } });

    sections.push_back ({ editSound, "Env 1", cell (soundRows, soundCols, 2, 0), {},
                          { knob (id::attack, "A", editKnob, { Family::motion }), knob (id::decay, "D", editKnob, { Family::motion }),
                            knob (id::sustain, "S", editKnob, { Family::motion }), knob (id::release, "R", editKnob, { Family::motion }) } });

    sections.push_back ({ editSound, "Env 2", cell (soundRows, soundCols, 2, 1),
                          { &segment (id::vcaMode, { "Env 1", "Gate", "Env 2" }) },
                          { knob (id::ampAttack, "A", editKnob, { Family::motion }), knob (id::ampDecay, "D", editKnob, { Family::motion }),
                            knob (id::ampSustain, "S", editKnob, { Family::motion }), knob (id::ampRelease, "R", editKnob, { Family::motion }) } });

    sections.push_back ({ editSound, "Voice", cell (soundRows, soundCols, 2, 2),
                          { &segment (id::voiceMode, { "Poly", "Mono" }) },
                          { knob (id::glide, "Glide", editKnob, { Family::motion }), knob (id::velocity, "Velo", editKnob, { Family::motion }) } });

    // ── EDIT / Character ──────────────────────────────────────────────
    sections.push_back ({ editCharacter, "Dust", cell (characterRows, characterCols, 0, 0), {},
                          { knob (id::dust, "Dust", characterHero, { Family::dust, true }), knob (id::dustTape, "Tape", characterKnob, { Family::dust }),
                            knob (id::dustCrush, "Crush", characterKnob, { Family::dust }), knob (id::dustNoise, "Noise", characterKnob, { Family::dust }),
                            knob (id::dustTone, "Tone", characterKnob, { Family::dust }) } });
    sections.back().items[0].weight = 1.4f;

    sections.push_back ({ editCharacter, "808", cell (characterRows, characterCols, 0, 1),
                          { &segment (id::subOctave, { "0", "-1" }) },
                          { knob (id::sub808Level, "Level", characterHero, { Family::sub, true }), knob (id::subDecay, "Decay", characterKnob, { Family::sub }),
                            knob (id::subDrop, "Drop", characterKnob, { Family::sub }), knob (id::subDrive, "Drive", characterKnob, { Family::sub }) } });
    sections.back().items[0].weight = 1.4f;

    sections.push_back ({ editCharacter, "Character", cell (characterRows, characterCols, 0, 2), {},
                          { knob (id::drive, "Drive", characterKnob, { Family::heat }), knob (id::tube, "Tube", characterKnob, { Family::heat }),
                            knob (id::drift, "Drift", characterKnob, { Family::motion }) } });

    sections.push_back ({ editCharacter, "Space", cell (characterRows, characterCols, 1, 0), {},
                          { knob (id::delayTime, "Time", characterKnob, { Family::space }), knob (id::delayFeedback, "Fdbk", characterKnob, { Family::space }),
                            knob (id::delayMix, "Delay", characterKnob, { Family::space }), knob (id::reverbSize, "Size", characterKnob, { Family::space }),
                            knob (id::reverbMix, "Verb", characterKnob, { Family::space }) } });

    sections.push_back ({ editCharacter, "Lead", cell (characterRows, characterCols, 1, 1), {},
                          { knob (id::dist, "Dist", characterHero, { Family::heat, true }) } });

    sections.push_back ({ editCharacter, "Mod FX", cell (characterRows, characterCols, 1, 2),
                          { &segment (id::chorus, { "Off", "I", "II", "I+II" }) },
                          { { &segment (id::phaser, { "Off", "Slow", "Fast" }), 1.6f, 30 },
                            knob (id::phaserMix, "Phase", characterKnob, { Family::space }) } });

    // ── Kopf: Seiten, Reiter, Theme ───────────────────────────────────
    addAndMakeVisible (pageSwitch);
    pageSwitch.setTitle ("Page");
    pageSwitch.onSelect = [this] (int i) { setPage (i == 0 ? play : (page == editCharacter ? editCharacter : editSound)); };

    addChildComponent (editTabs);
    editTabs.setTitle ("Edit");
    editTabs.onSelect = [this] (int i) { setPage (i == 0 ? editSound : editCharacter); };

    addAndMakeVisible (themeSwitch);
    themeSwitch.setTitle ("Theme");
    themeSwitch.onSelect = [this] (int i) { setThemeMode (static_cast<ui::ThemeMode> (i), true); };
    setThemeMode (static_cast<ui::ThemeMode> (juce::jlimit (0, 2, settings.getIntValue (themeKey, 0))), false);
    startTimer (20000);

    setPage (juce::jlimit (0, 2, processor.uiPage.load()));
}

template <typename T>
T& Contra86Panel::own (std::unique_ptr<T> component)
{
    auto& c = *component;
    addAndMakeVisible (c);
    controls.push_back (std::move (component));
    return c;
}

Contra86Panel::Item Contra86Panel::knob (const juce::String& paramId, const juce::String& label, int height, ui::KnobLook look)
{
    auto& k = own (std::make_unique<ui::Knob> (processor.state, paramId, label, show, std::move (look)));
    return { &k, 1.0f, height };
}

ui::SegmentedControl& Contra86Panel::segment (const juce::String& paramId, juce::StringArray labels)
{
    return own (std::make_unique<ui::SegmentedControl> (processor.state, paramId, std::move (labels), show));
}

void Contra86Panel::setPage (int newPage)
{
    page = newPage;
    const auto playing = page == play;

    pageSwitch.setSelected (playing ? 0 : 1);
    editTabs.setSelected (page == editCharacter ? 1 : 0);
    editTabs.setVisible (! playing);

    pad->setVisible (playing);
    throwButton->setVisible (playing);
    for (const auto& item : playKnobs) item.component->setVisible (playing);
    for (const auto& item : chain)     item.component->setVisible (playing);

    for (const auto& section : sections)
    {
        for (auto* c : section.header)
            c->setVisible (section.page == page);
        for (const auto& item : section.items)
            item.component->setVisible (section.page == page);
    }

    processor.uiPage.store (page);
    resized();
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

void Contra86Panel::previewParameter (const juce::String& paramId)
{
    if (auto* param = processor.state.getParameter (paramId))
        display.showParameter (*param);
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

// Elemente nebeneinander nach Gewicht, Beschriftungen auf einer Grundlinie,
// kleine Elemente (Segmente) auf Höhe der Knopfmitte
void Contra86Panel::layoutRow (const std::vector<Item>& items, juce::Rectangle<int> area, int baseline)
{
    auto totalWeight = 0.0f;
    auto maxHeight = 0;
    for (const auto& item : items)
    {
        totalWeight += item.weight;
        maxHeight = std::max (maxHeight, item.height);
    }

    const auto knobCentre = baseline - 24 - (maxHeight - 24) / 2;
    auto x = static_cast<float> (area.getX());
    for (const auto& item : items)
    {
        const auto w = static_cast<float> (area.getWidth()) * item.weight / totalWeight;
        const auto y = item.height < 60 ? knobCentre - item.height / 2 : baseline - item.height;
        item.component->setBounds (juce::roundToInt (x) + 2, y, juce::roundToInt (w) - 4, item.height);
        x += w;
    }
}

void Contra86Panel::layoutSection (const Section& section)
{
    auto area = section.area.reduced (20, 16);
    auto header = area.removeFromTop (28);

    for (auto* c : section.header)
    {
        const auto width = c->getNaturalWidth();
        c->setBounds (header.removeFromRight (width).withSizeKeepingCentre (width, 28));
        header.removeFromRight (8);
    }

    layoutRow (section.items, area, area.getBottom() - 2);
}

void Contra86Panel::resized()
{
    const auto pw = std::max (180, pageSwitch.getNaturalWidth());
    pageSwitch.setBounds (600 - pw / 2, 22, pw, 34);
    const auto tw = std::max (210, themeSwitch.getNaturalWidth());
    themeSwitch.setBounds (right - tw, 22, tw, 34);

    if (page == play)
    {
        display.setBounds (visualCard);
        pad->setBounds (padCard);

        auto row = soundCard.withTrimmedLeft (28).withTrimmedRight (24);
        const auto throwArea = row.removeFromRight (104);
        throwButton->setBounds (throwArea.withSizeKeepingCentre (104, 104));
        row.removeFromRight (24);
        layoutRow (playKnobs, row, soundCard.getBottom() - 16);

        layoutRow (chain, chainCard.reduced (24, 0), chainCard.getBottom() - 14);
        return;
    }

    display.setBounds (left, 76, right - left, 112);
    editTabs.setBounds (left, 204, std::max (220, editTabs.getNaturalWidth()), 34);

    for (const auto& section : sections)
        if (section.page == page)
            layoutSection (section);
}

std::vector<juce::Rectangle<int>> Contra86Panel::cards() const
{
    if (page == play)
        return { padCard, soundCard, chainCard };

    std::vector<juce::Rectangle<int>> result;
    const auto rows = page == editSound ? soundRows : characterRows;
    for (int r = 0; r < rows; ++r)
        result.push_back (editRow (rows, r));
    return result;
}

void Contra86Panel::paint (juce::Graphics& g)
{
    using namespace ui;
    const auto& p = palette();

    g.fillAll (p.panel);

    g.setColour (p.ink);
    g.setFont (wordmarkFont (20.0f).withExtraKerningFactor (0.02f));
    g.drawText ("CONTRA-86", juce::Rectangle<float> (36.0f, 22.0f, 300.0f, 34.0f), juce::Justification::centredLeft, false);

    for (const auto& c : cards())
        drawCard (g, c.toFloat());

    // Schatten unter dem Display
    juce::Path glass;
    glass.addRoundedRectangle (display.getBounds().toFloat(), page == play ? 28.0f : 18.0f);
    juce::DropShadow (p.shadow.withMultipliedAlpha (0.9f), 30, { 0, 10 }).drawForPath (g, glass);

    if (page == play)
    {
        // Pfeile zwischen den Modulen der Effektkette
        g.setColour (p.inkSoft.withAlpha (0.6f));
        g.setFont (font (18.0f, Weight::regular));
        for (size_t i = 1; i < chain.size(); ++i)
        {
            const auto a = chain[i - 1].component->getBounds(), b = chain[i].component->getBounds();
            const auto x = static_cast<float> (a.getRight() + b.getX()) * 0.5f;
            g.drawText (juce::String::fromUTF8 ("\xe2\x80\xba"), juce::Rectangle<float> (x - 10.0f, static_cast<float> (chainCard.getCentreY()) - 12.0f, 20.0f, 24.0f),
                        juce::Justification::centred, false);
        }
    }
    else
    {
        for (const auto& section : sections)
        {
            if (section.page != page)
                continue;

            const auto a = section.area.toFloat();
            if (a.getX() > left)
            {
                g.setColour (p.line);
                g.fillRect (a.getX(), a.getY() + 20.0f, 1.0f, a.getHeight() - 40.0f);
            }

            g.setColour (p.ink);
            g.setFont (font (15.0f, Weight::semibold));
            g.drawText (section.title, a.reduced (20.0f, 16.0f).removeFromTop (28.0f), juce::Justification::centredLeft, false);
        }
    }

    g.setColour (p.inkSoft.withAlpha (0.7f));
    g.setFont (font (11.0f, Weight::regular));
    g.drawText ("v" + juce::String (JucePlugin_VersionString), juce::Rectangle<float> (static_cast<float> (right) - 120.0f, 781.0f, 120.0f, 16.0f),
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

    const auto scale = juce::jlimit (0.5, 1.6, static_cast<double> (contraProcessor.uiScale.load()));
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
    contraProcessor.uiScale.store (scale);
}
