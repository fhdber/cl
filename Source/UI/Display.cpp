#include "Display.h"
#include "PluginProcessor.h"
#include "Presets.h"
#include "Parameters.h"

namespace ui
{
namespace
{
    namespace id = params::id;

    constexpr double valueHoldMs = 1500.0;
    constexpr int scopeSamples = 1024;
    constexpr float minFreq = 20.0f, maxFreq = 20000.0f;
    constexpr float delayBeats[] = { 0.25f, 1.0f / 3.0f, 0.5f, 0.75f, 2.0f / 3.0f, 1.0f, 1.5f, 2.0f };

    float freqToX (juce::Rectangle<float> r, float f)
    {
        return r.getX() + r.getWidth() * std::log (f / minFreq) / std::log (maxFreq / minFreq);
    }

    float xToFreq (juce::Rectangle<float> r, float x)
    {
        return minFreq * std::pow (maxFreq / minFreq, juce::jlimit (0.0f, 1.0f, (x - r.getX()) / r.getWidth()));
    }

    bool isOneOf (const juce::String& s, std::initializer_list<const char*> ids)
    {
        for (auto* i : ids)
            if (s == i)
                return true;
        return false;
    }

    // Linie mit Schein im Verlauf einer Funktionsgruppe
    void strokeGlow (juce::Graphics& g, const juce::Path& path, Gradient gr, juce::Rectangle<float> r, float width = 2.4f)
    {
        g.setGradientFill (juce::ColourGradient (gr.from.withAlpha (0.18f), r.getX(), 0.0f, gr.to.withAlpha (0.18f), r.getRight(), 0.0f, false));
        g.strokePath (path, juce::PathStrokeType (width * 4.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
        g.setGradientFill (juce::ColourGradient (gr.from, r.getX(), 0.0f, gr.to, r.getRight(), 0.0f, false));
        g.strokePath (path, juce::PathStrokeType (width, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    }

    Gradient accentGradient()
    {
        return { palette().accent.brighter (0.25f), palette().accent };
    }
}

Display::Display (Contra86Processor& p) : processor (p)
{
    setTitle ("Preset");
    startTimerHz (30);
}

float Display::raw (const char* paramId) const
{
    return processor.state.getRawParameterValue (paramId)->load (std::memory_order_relaxed);
}

void Display::showParameter (juce::RangedAudioParameter& parameter)
{
    shown = &parameter;
    shownId = parameter.getParameterID();

    if (isOneOf (shownId, { id::cutoff, id::resonance, id::envAmount, id::keyTrack, id::hpf }))
        visual = Visual::filter;
    else if (isOneOf (shownId, { id::attack, id::decay, id::sustain, id::release }))
        visual = Visual::envFilter;
    else if (isOneOf (shownId, { id::ampAttack, id::ampDecay, id::ampSustain, id::ampRelease, id::vcaMode }))
        visual = Visual::envAmp;
    else if (isOneOf (shownId, { id::lfoRate, id::lfoDelay, id::lfoPitch, id::lfoFilter }))
        visual = Visual::lfo;
    else if (isOneOf (shownId, { id::sub808Level, id::subDecay, id::subDrop, id::subDrive, id::subOctave }))
        visual = Visual::sub;
    else if (isOneOf (shownId, { id::delayTime, id::delayFeedback, id::delayMix, id::throwFx, id::reverbSize, id::reverbMix }))
        visual = Visual::delay;
    else if (isOneOf (shownId, { id::dust, id::dustTape, id::dustCrush, id::dustNoise, id::dustTone }))
        visual = Visual::dust;
    else
        visual = Visual::scope;

    valueUntil = juce::Time::getMillisecondCounterHiRes() + valueHoldMs;
    repaint();
}

void Display::resized()
{
    const auto bounds = getLocalBounds().toFloat();
    compact = bounds.getHeight() < 200.0f;

    if (compact)
    {
        auto left = bounds.reduced (24.0f, 16.0f).removeFromLeft (380.0f);
        headerArea = left.removeFromTop (20.0f);
        valueArea = left;
        prevArea = { left.getRight() - 52.0f, headerArea.getY(), 24.0f, 20.0f };
        nextArea = prevArea.translated (26.0f, 0.0f);
        visualArea = bounds.reduced (24.0f, 16.0f).withTrimmedLeft (410.0f);
        statusArea = {};
        return;
    }

    auto area = bounds.reduced (28.0f, 24.0f);
    headerArea = area.removeFromTop (20.0f);
    prevArea = { headerArea.getRight() - 52.0f, headerArea.getY(), 24.0f, 20.0f };
    nextArea = prevArea.translated (28.0f, 0.0f);
    area.removeFromTop (16.0f);
    valueArea = area.removeFromTop (82.0f);
    statusArea = area.removeFromBottom (20.0f);
    area.removeFromBottom (12.0f);
    visualArea = area;
}

void Display::timerCallback()
{
    if (processor.getCurrentProgram() != shownProgram)
    {
        shownProgram = processor.getCurrentProgram();
        repaint();
    }

    if (valueUntil > 0.0 && juce::Time::getMillisecondCounterHiRes() > valueUntil && ! draggingCurve)
    {
        valueUntil = 0.0;
        visual = Visual::scope;
        shown = nullptr;
    }

    // Oszilloskop: Fenster ab einem steigenden Nulldurchgang, damit es steht.
    processor.scope.snapshot (snapshot.data(), static_cast<int> (snapshot.size()));
    scopeStart = 0;
    for (int i = 1; i < static_cast<int> (snapshot.size()) - scopeSamples; ++i)
        if (snapshot[static_cast<size_t> (i - 1)] < 0.0f && snapshot[static_cast<size_t> (i)] >= 0.0f)
        {
            scopeStart = i;
            break;
        }

    updateSpectrum();
    repaint();
}

void Display::updateSpectrum()
{
    std::fill (fftData.begin(), fftData.end(), 0.0f);
    std::copy (snapshot.begin(), snapshot.end(), fftData.begin());
    window.multiplyWithWindowingTable (fftData.data(), snapshot.size());
    fft.performFrequencyOnlyForwardTransform (fftData.data());

    const auto sampleRate = processor.getSampleRate() > 0.0 ? processor.getSampleRate() : 48000.0;
    const auto binHz = static_cast<float> (sampleRate) / static_cast<float> (snapshot.size());
    const auto count = static_cast<int> (bands.size());

    for (int b = 0; b < count; ++b)
    {
        const auto f0 = 30.0f * std::pow (16000.0f / 30.0f, static_cast<float> (b) / static_cast<float> (count));
        const auto f1 = 30.0f * std::pow (16000.0f / 30.0f, static_cast<float> (b + 1) / static_cast<float> (count));
        const auto i0 = juce::jlimit (1, 1023, static_cast<int> (f0 / binHz));
        const auto i1 = juce::jlimit (i0 + 1, 1024, static_cast<int> (f1 / binHz) + 1);

        auto peak = 0.0f;
        for (int i = i0; i < i1; ++i)
            peak = std::max (peak, fftData[static_cast<size_t> (i)]);

        const auto db = juce::Decibels::gainToDecibels (peak / 512.0f, -100.0f);
        const auto level = juce::jlimit (0.0f, 1.0f, (db + 78.0f) / 66.0f);
        auto& band = bands[static_cast<size_t> (b)];
        band = std::max (level, band * 0.86f);
    }
}

juce::String Display::statusText() const
{
    auto& state = processor.state;
    juce::String text = state.getParameter (id::voiceMode)->getCurrentValueAsText().toUpperCase();

    if (const auto unison = state.getParameter (id::unison)->getCurrentValueAsText(); unison != "Off")
        text << "  ·  UNISON " << unison;
    if (const auto blend = raw (id::blend); blend > 0.005f)
        text << "  ·  BLEND " << juce::roundToInt (blend * 100.0f) << "%";
    if (raw (id::sub808Level) > 0.005f)
        text << "  ·  808";
    if (const auto dust = raw (id::dust); dust > 0.005f)
        text << "  ·  DUST " << juce::roundToInt (dust * 100.0f) << "%";
    if (raw (id::throwFx) > 0.5f)
        text << "  ·  THROW";
    return text;
}

//==============================================================================
void Display::paint (juce::Graphics& g)
{
    const auto& p = palette();
    const auto bounds = getLocalBounds().toFloat();
    const auto radius = compact ? 18.0f : 28.0f;

    g.setColour (p.display);
    g.fillRoundedRectangle (bounds, radius);

    // Kopfzeile: Kategorie, Preset-Nummer, Pfeile
    const auto showingValue = valueUntil > 0.0 && shown != nullptr;
    g.setFont (pixelFont (12.0f).withExtraKerningFactor (0.08f));
    g.setColour (juce::Colours::white.withAlpha (0.5f));
    g.drawText (presets::category (shownProgram).toUpperCase() + "  /  " + juce::String (shownProgram + 1) + " OF "
                    + juce::String (presets::count()),
                headerArea, juce::Justification::centredLeft, false);

    for (auto [area, left] : { std::pair { prevArea, true }, { nextArea, false } })
    {
        const auto c = area.getCentre();
        juce::Path tri;
        if (left) tri.addTriangle (c.x + 4.0f, c.y - 6.0f, c.x + 4.0f, c.y + 6.0f, c.x - 4.0f, c.y);
        else      tri.addTriangle (c.x - 4.0f, c.y - 6.0f, c.x - 4.0f, c.y + 6.0f, c.x + 4.0f, c.y);
        g.setColour (juce::Colours::white.withAlpha (0.6f));
        g.fillPath (tri);
    }

    // Wert beim Bedienen, sonst Preset-Name
    auto value = valueArea;
    g.setFont (pixelFont (12.0f).withExtraKerningFactor (0.08f));
    g.setColour (juce::Colours::white.withAlpha (0.5f));
    g.drawText (showingValue ? shown->getName (32).toUpperCase() : "PRESET", value.removeFromTop (compact ? 18.0f : 22.0f),
                juce::Justification::centredLeft, false);

    g.setColour (p.accent);
    g.setFont (dotFont (compact ? 36.0f : 50.0f));
    g.drawFittedText ((showingValue ? shown->getCurrentValueAsText() : presets::name (shownProgram)).toUpperCase(),
                      value.removeFromTop (compact ? 46.0f : 60.0f).toNearestInt(), juce::Justification::centredLeft, 1, 0.6f);

    // Visual
    switch (visual)
    {
        case Visual::filter:    paintSpectrum (g, visualArea); paintFilter (g, visualArea); break;
        case Visual::envFilter: paintEnvelope (g, visualArea, false); break;
        case Visual::envAmp:    paintEnvelope (g, visualArea, true); break;
        case Visual::lfo:       paintLfo (g, visualArea); break;
        case Visual::sub:       paintSub (g, visualArea); break;
        case Visual::delay:     paintDelay (g, visualArea); break;
        case Visual::dust:      paintScope (g, visualArea, true); break;
        case Visual::scope:     paintSpectrum (g, visualArea); paintScope (g, visualArea, false); break;
    }

    if (! statusArea.isEmpty())
    {
        g.setColour (juce::Colours::white.withAlpha (0.4f));
        g.setFont (pixelFont (12.0f).withExtraKerningFactor (0.06f));
        g.drawText (statusText(), statusArea, juce::Justification::centredLeft, false);
    }
}

void Display::paintSpectrum (juce::Graphics& g, juce::Rectangle<float> r) const
{
    const auto count = static_cast<float> (bands.size());
    const auto w = r.getWidth() / count;
    g.setColour (juce::Colours::white.withAlpha (0.09f));
    for (size_t i = 0; i < bands.size(); ++i)
    {
        const auto h = std::max (3.0f, bands[i] * r.getHeight() * 0.8f);
        g.fillRoundedRectangle (r.getX() + w * static_cast<float> (i) + 1.5f, r.getBottom() - h, w - 3.0f, h, 2.0f);
    }
}

void Display::paintScope (juce::Graphics& g, juce::Rectangle<float> r, bool quantised) const
{
    // Dust: Welle gerastert (Crush), wackelt (Tape), Knistern (Noise)
    const auto dust = quantised ? raw (id::dust) : 0.0f;
    const auto levels = quantised ? std::max (3.0f, 48.0f * (1.0f - 0.92f * dust * raw (id::dustCrush) * 2.0f)) : 0.0f;
    const auto stepEvery = quantised ? 1 + juce::roundToInt (14.0f * dust * raw (id::dustCrush)) : 1;
    const auto wobble = quantised ? dust * raw (id::dustTape) * 8.0f : 0.0f;
    const auto phase = static_cast<float> (juce::Time::getMillisecondCounter() % 4000) / 4000.0f * juce::MathConstants<float>::twoPi;

    juce::Path wave;
    auto held = 0.0f;
    for (int i = 0; i < scopeSamples; ++i)
    {
        auto s = juce::jlimit (-1.0f, 1.0f, snapshot[static_cast<size_t> (scopeStart + i)] * 3.0f);
        if (quantised)
        {
            if (i % stepEvery == 0)
                held = std::round (s * levels) / levels;
            s = held;
        }
        const auto x = r.getX() + r.getWidth() * static_cast<float> (i) / (scopeSamples - 1);
        const auto y = r.getCentreY() - s * r.getHeight() * 0.42f
                     + wobble * std::sin (phase + static_cast<float> (i) * 0.01f);
        if (i == 0) wave.startNewSubPath (x, y);
        else        wave.lineTo (x, y);
    }

    strokeGlow (g, wave, quantised ? gradient (Family::dust) : accentGradient(), r, quantised ? 2.0f : 1.8f);

    if (quantised)
    {
        juce::Random random (static_cast<juce::int64> (juce::Time::getMillisecondCounter() / 120));
        const auto specks = juce::roundToInt (60.0f * dust * raw (id::dustNoise) * 2.0f);
        g.setColour (juce::Colours::white.withAlpha (0.35f));
        for (int i = 0; i < specks; ++i)
        {
            const auto size = 1.5f + random.nextFloat() * 2.0f;
            g.fillRect (r.getX() + random.nextFloat() * r.getWidth(), r.getY() + random.nextFloat() * r.getHeight(), size, size);
        }
    }
    else if (! compact)
    {
        // Abspielmarke wie bei einem Recorder
        const auto x = r.getX() + r.getWidth() * 0.62f;
        g.setColour (palette().led);
        g.fillRect (x - 0.75f, r.getY(), 1.5f, r.getHeight());
        g.fillEllipse (x - 3.0f, r.getY() - 3.0f, 6.0f, 6.0f);
    }
}

juce::Point<float> Display::filterPoint (juce::Rectangle<float> r, float freq) const
{
    const auto cutoff = raw (id::cutoff), hpf = raw (id::hpf);
    const auto k = 3.9f * raw (id::resonance);

    // 4-Pol-Ladder mit Rückkopplung k, dazu 1-Pol-Hochpass
    const std::complex<float> s (0.0f, freq / cutoff);
    const auto one = std::complex<float> (1.0f, 0.0f);
    const auto lp = (1.0f + k) / std::abs ((one + s) * (one + s) * (one + s) * (one + s) + k);
    const std::complex<float> sh (0.0f, freq / hpf);
    const auto hp = std::abs (sh / (one + sh));
    const auto db = juce::Decibels::gainToDecibels (lp * hp * 0.5f + 1.0e-6f);
    const auto norm = juce::jlimit (0.0f, 1.0f, (db + 42.0f) / 60.0f);
    return { freqToX (r, freq), r.getBottom() - norm * r.getHeight() };
}

void Display::paintFilter (juce::Graphics& g, juce::Rectangle<float> r) const
{
    juce::Path curve;
    for (int i = 0; i <= 160; ++i)
    {
        const auto f = minFreq * std::pow (maxFreq / minFreq, static_cast<float> (i) / 160.0f);
        const auto pt = filterPoint (r, f);
        if (i == 0) curve.startNewSubPath (pt);
        else        curve.lineTo (pt);
    }
    strokeGlow (g, curve, gradient (Family::tone), r, 2.6f);

    const auto handle = filterPoint (r, raw (id::cutoff));
    g.setColour (gradient (Family::tone).to.withAlpha (0.45f));
    g.fillEllipse (juce::Rectangle<float> (22.0f, 22.0f).withCentre (handle));
    g.setColour (juce::Colours::white);
    g.fillEllipse (juce::Rectangle<float> (12.0f, 12.0f).withCentre (handle));

    if (! compact)
    {
        g.setColour (juce::Colours::white.withAlpha (0.45f));
        g.setFont (font (12.0f, Weight::regular));
        g.drawText ("Drag the curve", juce::Rectangle<float> (140.0f, 18.0f).withCentre (handle.translated (-84.0f, 22.0f)),
                    juce::Justification::centredRight, false);
    }
}

void Display::paintEnvelope (juce::Graphics& g, juce::Rectangle<float> r, bool amp) const
{
    const auto a = raw (amp ? id::ampAttack : id::attack), d = raw (amp ? id::ampDecay : id::decay);
    const auto s = raw (amp ? id::ampSustain : id::sustain), rel = raw (amp ? id::ampRelease : id::release);

    // Zeiten wurzelskaliert, damit kurze und lange Phasen lesbar bleiben
    const auto wa = std::sqrt (a) + 0.05f, wd = std::sqrt (d) + 0.05f, ws = 0.8f, wr = std::sqrt (rel) + 0.05f;
    const auto total = wa + wd + ws + wr;
    const auto area = r.reduced (0.0f, 10.0f).withTrimmedBottom (20.0f);
    const auto x0 = area.getX(), xa = x0 + area.getWidth() * wa / total, xd = xa + area.getWidth() * wd / total;
    const auto xs = xd + area.getWidth() * ws / total, xr = area.getRight();
    const auto top = area.getY(), bottom = area.getBottom(), sy = bottom - s * area.getHeight();

    juce::Path env;
    env.startNewSubPath (x0, bottom);
    env.quadraticTo ((x0 + xa) * 0.5f, top + area.getHeight() * 0.1f, xa, top);
    env.quadraticTo (xa + (xd - xa) * 0.2f, sy, xd, sy);
    env.lineTo (xs, sy);
    env.quadraticTo (xs + (xr - xs) * 0.2f, bottom, xr, bottom);
    strokeGlow (g, env, gradient (Family::motion), r, 2.4f);

    const auto stage = shownId.endsWithIgnoreCase ("ttack") ? 0 : shownId.endsWithIgnoreCase ("ecay") ? 1
                     : shownId.endsWithIgnoreCase ("ustain") ? 2 : shownId.endsWithIgnoreCase ("elease") ? 3 : -1;
    const juce::Point<float> points[] = { { xa, top }, { xd, sy }, { xs, sy }, { xr, bottom } };
    if (stage >= 0)
    {
        const auto pt = points[stage];
        g.setColour (palette().led.withAlpha (0.35f));
        g.fillEllipse (juce::Rectangle<float> (20.0f, 20.0f).withCentre (pt));
        g.setColour (palette().led);
        g.fillEllipse (juce::Rectangle<float> (10.0f, 10.0f).withCentre (pt));
    }

    g.setFont (pixelFont (12.0f));
    const float labelX[] = { (x0 + xa) * 0.5f, (xa + xd) * 0.5f, (xd + xs) * 0.5f, (xs + xr) * 0.5f };
    const char* labels[] = { "A", "D", "S", "R" };
    for (int i = 0; i < 4; ++i)
    {
        g.setColour (juce::Colours::white.withAlpha (i == stage ? 0.9f : 0.35f));
        g.drawText (labels[i], juce::Rectangle<float> (labelX[i] - 10.0f, r.getBottom() - 18.0f, 20.0f, 18.0f), juce::Justification::centred, false);
    }
}

void Display::paintLfo (juce::Graphics& g, juce::Rectangle<float> r) const
{
    const auto rate = raw (id::lfoRate), delay = raw (id::lfoDelay);
    constexpr float seconds = 2.0f;
    const auto offset = static_cast<float> (juce::Time::getMillisecondCounter() % 100000) / 1000.0f;

    juce::Path wave;
    for (int i = 0; i <= 240; ++i)
    {
        const auto t = seconds * static_cast<float> (i) / 240.0f;
        const auto ph = std::fmod ((t + offset) * rate, 1.0f);
        const auto tri = 4.0f * std::abs (ph - 0.5f) - 1.0f;
        const auto fade = delay > 0.01f ? juce::jmin (1.0f, t / delay) : 1.0f;
        const auto pt = juce::Point<float> (r.getX() + r.getWidth() * t / seconds, r.getCentreY() - tri * fade * r.getHeight() * 0.4f);
        if (i == 0) wave.startNewSubPath (pt);
        else        wave.lineTo (pt);
    }
    strokeGlow (g, wave, gradient (Family::motion), r, 2.2f);

    if (delay > 0.01f)
    {
        const auto x = r.getX() + r.getWidth() * juce::jmin (1.0f, delay / seconds);
        g.setColour (juce::Colours::white.withAlpha (0.25f));
        g.fillRect (r.getX(), r.getBottom() - 1.0f, x - r.getX(), 1.0f);
        g.setFont (pixelFont (12.0f));
        g.drawText ("FADE IN", juce::Rectangle<float> (r.getX(), r.getBottom() - 20.0f, 100.0f, 16.0f), juce::Justification::centredLeft, false);
    }
}

void Display::paintSub (juce::Graphics& g, juce::Rectangle<float> r) const
{
    const auto decay = juce::jmax (0.05f, raw (id::subDecay)), drop = raw (id::subDrop);
    const auto seconds = juce::jmax (0.4f, decay * 1.1f);

    juce::Path pitch, level;
    for (int i = 0; i <= 200; ++i)
    {
        const auto t = seconds * static_cast<float> (i) / 200.0f;
        const auto x = r.getX() + r.getWidth() * t / seconds;
        const auto semis = drop * 12.0f * std::exp (-t / 0.04f);
        const auto py = r.getCentreY() + r.getHeight() * 0.1f - semis / 12.0f * r.getHeight() * 0.45f;
        const auto ly = r.getBottom() - std::exp (-6.9f * t / decay) * r.getHeight() * 0.85f;
        if (i == 0) { pitch.startNewSubPath (x, py); level.startNewSubPath (x, ly); }
        else        { pitch.lineTo (x, py); level.lineTo (x, ly); }
    }
    g.setColour (juce::Colours::white.withAlpha (0.3f));
    g.strokePath (level, juce::PathStrokeType (1.4f));
    strokeGlow (g, pitch, gradient (Family::sub), r, 2.6f);

    g.setFont (pixelFont (12.0f));
    g.setColour (gradient (Family::sub).from);
    g.drawText ("PITCH", juce::Rectangle<float> (r.getX(), r.getBottom() - 18.0f, 70.0f, 16.0f), juce::Justification::centredLeft, false);
    g.setColour (juce::Colours::white.withAlpha (0.35f));
    g.drawText ("LEVEL", juce::Rectangle<float> (r.getX() + 70.0f, r.getBottom() - 18.0f, 70.0f, 16.0f), juce::Justification::centredLeft, false);
}

void Display::paintDelay (juce::Graphics& g, juce::Rectangle<float> r) const
{
    const auto thrown = raw (id::throwFx) > 0.5f;
    const auto feedback = thrown ? std::max (raw (id::delayFeedback), 0.72f) : raw (id::delayFeedback);
    const auto mix = thrown ? 1.0f : raw (id::delayMix);
    const auto beats = delayBeats[juce::jlimit (0, 7, juce::roundToInt (raw (id::delayTime)))];
    const auto spacing = r.getWidth() * 0.11f * beats / 0.75f;
    const auto space = gradient (Family::space);

    // Hall als weicher Schleier hinter den Echos
    if (const auto verb = raw (id::reverbMix); verb > 0.005f)
    {
        juce::Path tail;
        tail.startNewSubPath (r.getX(), r.getBottom());
        tail.lineTo (r.getX(), r.getBottom() - r.getHeight() * 0.5f * verb);
        tail.quadraticTo (r.getX() + r.getWidth() * (0.2f + 0.7f * raw (id::reverbSize)), r.getBottom(), r.getRight(), r.getBottom());
        tail.closeSubPath();
        g.setColour (space.from.withAlpha (0.12f));
        g.fillPath (tail);
    }

    // Original weiß, Echos im Space-Verlauf, Höhe = Feedback^n
    g.setColour (juce::Colours::white.withAlpha (0.8f));
    g.fillRoundedRectangle (r.getX(), r.getY() + r.getHeight() * 0.1f, 7.0f, r.getHeight() * 0.9f, 3.0f);
    auto amp = std::max (0.35f, mix);
    for (int n = 1; n < 16; ++n)
    {
        const auto x = r.getX() + spacing * static_cast<float> (n);
        if (x > r.getRight() - 7.0f || amp < 0.02f)
            break;
        const auto h = r.getHeight() * 0.9f * amp;
        const auto c = space.from.interpolatedWith (space.to, static_cast<float> (n) / 8.0f);
        if (thrown)
        {
            g.setColour (c.withAlpha (0.3f));
            g.fillRoundedRectangle (x - 4.0f, r.getBottom() - h - 4.0f, 15.0f, h + 4.0f, 5.0f);
        }
        g.setColour (c);
        g.fillRoundedRectangle (x, r.getBottom() - h, 7.0f, h, 3.0f);
        amp *= std::max (0.05f, feedback);
    }
}

//==============================================================================
void Display::mouseDown (const juce::MouseEvent& e)
{
    if (prevArea.expanded (6.0f).contains (e.position))      { stepPreset (-1); return; }
    if (nextArea.expanded (6.0f).contains (e.position))      { stepPreset (1); return; }
    if (headerArea.contains (e.position) || valueArea.contains (e.position)) { openPresetMenu(); return; }

    if (visualArea.expanded (8.0f).contains (e.position))
    {
        auto* cutoff = processor.state.getParameter (id::cutoff);
        auto* reso = processor.state.getParameter (id::resonance);
        draggingCurve = true;
        dragStart = e.position;
        dragCutoff = cutoff->getValue();
        dragReso = reso->getValue();
        cutoff->beginChangeGesture();
        reso->beginChangeGesture();
        showParameter (*cutoff);
    }
}

void Display::mouseDrag (const juce::MouseEvent& e)
{
    if (! draggingCurve)
        return;

    auto* cutoff = processor.state.getParameter (id::cutoff);
    auto* reso = processor.state.getParameter (id::resonance);
    const auto fine = e.mods.isShiftDown() || e.mods.isCommandDown() ? 0.15f : 1.0f;
    const auto d = (e.position - dragStart) * fine;

    // waagerecht: Cutoff auf der Frequenzachse, senkrecht: Resonanz
    const auto startX = freqToX (visualArea, cutoff->convertFrom0to1 (dragCutoff));
    const auto freq = xToFreq (visualArea, startX + d.x);
    cutoff->setValueNotifyingHost (cutoff->convertTo0to1 (freq));
    reso->setValueNotifyingHost (juce::jlimit (0.0f, 1.0f, dragReso - d.y / (visualArea.getHeight() * 1.2f)));
    showParameter (std::abs (d.y) > std::abs (d.x) * 1.5f ? *reso : *cutoff);
}

void Display::mouseUp (const juce::MouseEvent&)
{
    if (! draggingCurve)
        return;

    draggingCurve = false;
    processor.state.getParameter (id::cutoff)->endChangeGesture();
    processor.state.getParameter (id::resonance)->endChangeGesture();
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
    visual = Visual::scope;
    shown = nullptr;
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
                                                  .withTargetScreenArea (localAreaToGlobal (valueArea.toNearestInt())),
                        [safe = juce::Component::SafePointer<Display> (this)] (int result)
                        {
                            if (safe != nullptr && result > 0)
                                safe->selectPreset (result - 1);
                        });
}
}
