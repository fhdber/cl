#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "BinaryData.h"

namespace ui
{
// Farbpalette eines Themes. Hell = Tag, Dunkel = Abend.
struct Palette
{
    juce::Colour bodyTop, bodyBottom, edge, line, ink, inkSoft;
    juce::Colour knobTop, knobBottom, knobEdge, shadow, highlight, track;
    juce::Colour keyTop, keyBottom, segOn, segOnText;
    juce::Colour display, accent, accentDeep, led;
};

inline const Palette lightPalette {
    juce::Colour (0xffededeb), juce::Colour (0xffd8d9d7), juce::Colour (0xffffffff),
    juce::Colour (0x1a000000), juce::Colour (0xff1c1d1f), juce::Colour (0xff767a7f),
    juce::Colour (0xffffffff), juce::Colour (0xffdfe0df), juce::Colour (0x14000000),
    juce::Colour (0x40000000), juce::Colour (0xccffffff), juce::Colour (0x1c000000),
    juce::Colour (0xfff8f8f7), juce::Colour (0xffe3e4e3), juce::Colour (0xff1c1d1f), juce::Colour (0xffffffff),
    juce::Colour (0xff0a0a0a), juce::Colour (0xffee6a2e), juce::Colour (0xffe0402c), juce::Colour (0xffe5322d) };

inline const Palette darkPalette {
    juce::Colour (0xff2c2e31), juce::Colour (0xff1c1e20), juce::Colour (0x18ffffff),
    juce::Colour (0x14ffffff), juce::Colour (0xffeaebec), juce::Colour (0xff8e9399),
    juce::Colour (0xff45484c), juce::Colour (0xff2b2d30), juce::Colour (0x22ffffff),
    juce::Colour (0x80000000), juce::Colour (0x1affffff), juce::Colour (0x1affffff),
    juce::Colour (0xff3a3c40), juce::Colour (0xff2b2d30), juce::Colour (0xffeaebec), juce::Colour (0xff1c1d1f),
    juce::Colour (0xff050505), juce::Colour (0xfff07436), juce::Colour (0xffe0402c), juce::Colour (0xffff3b30) };

// Aktuelles Theme (nur Message-Thread). Gilt für alle offenen Fenster.
inline bool& darkFlag() { static bool dark = false; return dark; }
inline const Palette& palette() { return darkFlag() ? darkPalette : lightPalette; }

// Theme-Modus: 0 = Auto (Tag hell, Abend dunkel), 1 = Day, 2 = Night
enum class ThemeMode { automatic, day, night };

inline bool isEvening (const juce::Time& t)
{
    const auto hour = t.getHours();
    return hour < 7 || hour >= 19;
}

inline bool resolveDark (ThemeMode mode)
{
    return mode == ThemeMode::night || (mode == ThemeMode::automatic && isEvening (juce::Time::getCurrentTime()));
}

// Designfläche, auf die das gesamte UI skaliert wird (Querformat passt auf Laptops).
inline constexpr int designWidth  = 1200;
inline constexpr int designHeight = 800;

inline juce::Typeface::Ptr typeface()
{
    static auto tf = juce::Typeface::createSystemTypefaceFor (BinaryData::MichromaRegular_ttf,
                                                              BinaryData::MichromaRegular_ttfSize);
    return tf;
}

// Dot-Matrix für große Display-Schrift
inline juce::Typeface::Ptr dotTypeface()
{
    static auto tf = juce::Typeface::createSystemTypefaceFor (BinaryData::DotoBlack_ttf, BinaryData::DotoBlack_ttfSize);
    return tf;
}

// Pixel-Schrift für kleine Display-Schrift
inline juce::Typeface::Ptr pixelTypeface()
{
    static auto tf = juce::Typeface::createSystemTypefaceFor (BinaryData::SilkscreenRegular_ttf,
                                                              BinaryData::SilkscreenRegular_ttfSize);
    return tf;
}

inline juce::Font font (float height)      { return juce::Font (juce::FontOptions (typeface()).withHeight (height)); }
inline juce::Font dotFont (float height)   { return juce::Font (juce::FontOptions (dotTypeface()).withHeight (height)); }
inline juce::Font pixelFont (float height) { return juce::Font (juce::FontOptions (pixelTypeface()).withHeight (height)); }

inline void drawTracked (juce::Graphics& g, const juce::String& text, juce::Rectangle<float> area,
                         float height, juce::Justification just, float tracking = 0.08f)
{
    g.setFont (font (height).withExtraKerningFactor (tracking));
    g.drawText (text, area, just, false);
}

// Taste im Hardware-Stil: weiches Rechteck mit Schatten und Lichtkante.
inline void drawKey (juce::Graphics& g, juce::Rectangle<float> r, bool pressed, float radius = 10.0f)
{
    const auto& p = palette();
    juce::Path shape;
    shape.addRoundedRectangle (r, radius);
    if (! pressed)
        juce::DropShadow (p.shadow.withMultipliedAlpha (0.6f), 10, { 0, 4 }).drawForPath (g, shape);

    g.setGradientFill (juce::ColourGradient (pressed ? p.keyBottom : p.keyTop, r.getX(), r.getY(),
                                             pressed ? p.keyTop : p.keyBottom, r.getX(), r.getBottom(), false));
    g.fillPath (shape);
    g.setColour (p.highlight.withMultipliedAlpha (pressed ? 0.3f : 1.0f));
    g.drawRoundedRectangle (r.reduced (0.75f), radius, 1.0f);
    g.setColour (p.knobEdge);
    g.drawRoundedRectangle (r, radius, 1.0f);
}

// LED-Punkt mit Schein
inline void drawLed (juce::Graphics& g, juce::Point<float> c, bool on, juce::Colour colour, float size = 6.0f)
{
    if (on)
    {
        g.setColour (colour.withAlpha (0.25f));
        g.fillEllipse (juce::Rectangle<float> (size * 2.6f, size * 2.6f).withCentre (c));
    }
    g.setColour (on ? colour : palette().inkSoft.withAlpha (0.35f));
    g.fillEllipse (juce::Rectangle<float> (size, size).withCentre (c));
}
}
