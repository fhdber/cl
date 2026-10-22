#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "BinaryData.h"

namespace ui
{
// Farbpalette eines Themes. Neutral wie Apple/ChatGPT, Farbe nur für Werte.
struct Palette
{
    juce::Colour panel, card, ink, inkSoft, line, track;
    juce::Colour segBg, segThumb, shadow, display, accent, accentDeep, led;
};

inline const Palette lightPalette {
    juce::Colour (0xfff5f5f7), juce::Colour (0xffffffff), juce::Colour (0xff1d1d1f), juce::Colour (0xff6e6e73),
    juce::Colour (0x14000000), juce::Colour (0x24000000),
    juce::Colour (0xffe8e8ed), juce::Colour (0xffffffff), juce::Colour (0x1f000000),
    juce::Colour (0xff0a0a0a), juce::Colour (0xfffb5206), juce::Colour (0xffd93f00), juce::Colour (0xffe5322d) };

inline const Palette darkPalette {
    juce::Colour (0xff171717), juce::Colour (0xff212121), juce::Colour (0xffececec), juce::Colour (0xff9b9b9b),
    juce::Colour (0x14ffffff), juce::Colour (0x29ffffff),
    juce::Colour (0xff2c2c2c), juce::Colour (0xff454545), juce::Colour (0x66000000),
    juce::Colour (0xff0a0a0a), juce::Colour (0xffff6224), juce::Colour (0xffe84a0c), juce::Colour (0xffff3b30) };

// Funktionsfarben: jede Gruppe ein Verlauf vom hellen zum satten Ton.
enum class Family { tone, motion, space, heat, dust, sub };

struct Gradient { juce::Colour from, to; };

inline Gradient gradient (Family f)
{
    switch (f)
    {
        case Family::motion: return { juce::Colour (0xffa08bff), juce::Colour (0xff5a6cff) };
        case Family::space:  return { juce::Colour (0xff4fd6e8), juce::Colour (0xff2f7bea) };
        case Family::heat:   return { juce::Colour (0xffffb547), juce::Colour (0xffe5320a) };
        case Family::dust:   return { juce::Colour (0xffe6cb94), juce::Colour (0xffa86b3c) };
        case Family::sub:    return { juce::Colour (0xffff5c8a), juce::Colour (0xffb5225b) };
        case Family::tone:   break;
    }
    return { juce::Colour (0xffff9a5c), juce::Colour (0xfffb5206) };
}

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

namespace detail
{
    inline juce::Typeface::Ptr load (const char* data, int size) { return juce::Typeface::createSystemTypefaceFor (data, static_cast<size_t> (size)); }
}

enum class Weight { regular, medium, semibold };

inline juce::Typeface::Ptr interTypeface (Weight w)
{
    static auto regular  = detail::load (BinaryData::InterRegular_ttf, BinaryData::InterRegular_ttfSize);
    static auto medium   = detail::load (BinaryData::InterMedium_ttf, BinaryData::InterMedium_ttfSize);
    static auto semibold = detail::load (BinaryData::InterSemiBold_ttf, BinaryData::InterSemiBold_ttfSize);
    return w == Weight::semibold ? semibold : w == Weight::medium ? medium : regular;
}

// Wortmarke
inline juce::Typeface::Ptr wordmarkTypeface()
{
    static auto tf = detail::load (BinaryData::MichromaRegular_ttf, BinaryData::MichromaRegular_ttfSize);
    return tf;
}

// Dot-Matrix für große Display-Schrift
inline juce::Typeface::Ptr dotTypeface()
{
    static auto tf = detail::load (BinaryData::DotoBlack_ttf, BinaryData::DotoBlack_ttfSize);
    return tf;
}

// Pixel-Schrift für kleine Display-Schrift
inline juce::Typeface::Ptr pixelTypeface()
{
    static auto tf = detail::load (BinaryData::SilkscreenRegular_ttf, BinaryData::SilkscreenRegular_ttfSize);
    return tf;
}

inline juce::Font font (float height, Weight w = Weight::medium)
{
    return juce::Font (juce::FontOptions (interTypeface (w)).withHeight (height)).withExtraKerningFactor (-0.005f);
}

inline juce::Font wordmarkFont (float height) { return juce::Font (juce::FontOptions (wordmarkTypeface()).withHeight (height)); }
inline juce::Font dotFont (float height)      { return juce::Font (juce::FontOptions (dotTypeface()).withHeight (height)); }
inline juce::Font pixelFont (float height)    { return juce::Font (juce::FontOptions (pixelTypeface()).withHeight (height)); }

inline float textWidth (const juce::Font& f, const juce::String& text)
{
    return juce::GlyphArrangement::getStringWidth (f, text);
}

// Weiße Karte mit weichem Schatten (Apple-Stil)
inline void drawCard (juce::Graphics& g, juce::Rectangle<float> r, float radius = 28.0f)
{
    const auto& p = palette();
    juce::Path shape;
    shape.addRoundedRectangle (r, radius);
    juce::DropShadow (p.shadow.withMultipliedAlpha (0.45f), 24, { 0, 8 }).drawForPath (g, shape);
    g.setColour (p.card);
    g.fillPath (shape);
}

// Farbe einer Funktionsgruppe an Position t (0 … 1)
inline juce::Colour gradientAt (Family f, float t)
{
    const auto gr = gradient (f);
    return gr.from.interpolatedWith (gr.to, juce::jlimit (0.0f, 1.0f, t));
}
}
