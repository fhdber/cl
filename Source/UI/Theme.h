#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include "BinaryData.h"

namespace ui
{
namespace colour
{
    inline const juce::Colour bezel       { 0xff0b0b0c };
    inline const juce::Colour panelTop    { 0xffd5d9dd };
    inline const juce::Colour panelBottom { 0xffb9bfc5 };
    inline const juce::Colour line        { 0x26000000 };
    inline const juce::Colour ink         { 0xff1b1d20 };
    inline const juce::Colour inkSoft     { 0xff5d636a };
    inline const juce::Colour accent      { 0xffee6a2e };
    inline const juce::Colour accentDeep  { 0xffe0402c };
    inline const juce::Colour pointer     { 0xffe2412b };
    inline const juce::Colour display     { 0xff060606 };
}

// Designfläche, auf die das gesamte UI skaliert wird.
inline constexpr int designWidth  = 1040;
inline constexpr int designHeight = 990;

inline juce::Typeface::Ptr typeface()
{
    static auto tf = juce::Typeface::createSystemTypefaceFor (BinaryData::MichromaRegular_ttf,
                                                              BinaryData::MichromaRegular_ttfSize);
    return tf;
}

inline juce::Font font (float height)
{
    return juce::Font (juce::FontOptions (typeface()).withHeight (height));
}

inline void drawTracked (juce::Graphics& g, const juce::String& text, juce::Rectangle<float> area,
                         float height, juce::Justification just, float tracking = 0.08f)
{
    g.setFont (font (height).withExtraKerningFactor (tracking));
    g.drawText (text, area, just, false);
}
}
