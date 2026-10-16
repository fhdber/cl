#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

namespace presets
{
int count();
juce::String name (int index);
juce::String category (int index);

// "Kategorie / Name", für die Programmliste des Hosts.
juce::String fullName (int index);

// Setzt alle Parameter auf Default und danach die Werte des Presets.
// Aufruf vom Message-Thread (Host-Programmwechsel oder UI).
void apply (juce::AudioProcessorValueTreeState& state, int index);
}
