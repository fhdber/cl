#include "PluginEditor.h"

namespace
{
    constexpr int headerHeight = 40;
}

Contra86Editor::Contra86Editor (Contra86Processor& p)
    : AudioProcessorEditor (p), generic (p)
{
    addAndMakeVisible (generic);
    setResizable (true, true);
    setResizeLimits (420, 360, 1200, 1400);
    setSize (520, 720);
}

void Contra86Editor::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff111111));

    g.setColour (juce::Colours::white);
    g.setFont (juce::FontOptions (18.0f, juce::Font::bold));
    g.drawText ("CONTRA-86", getLocalBounds().removeFromTop (headerHeight).reduced (14, 0),
                juce::Justification::centredLeft);
}

void Contra86Editor::resized()
{
    generic.setBounds (getLocalBounds().withTrimmedTop (headerHeight));
}
