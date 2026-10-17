#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

namespace params
{
    // Version 1 aller IDs. Neue Parameter bekommen eine höhere Versionsnummer,
    // damit gespeicherte Sessions in allen Hosts stabil bleiben.
    inline constexpr int version = 1;
    inline constexpr int version2 = 2;
    inline constexpr int version3 = 3;
    inline constexpr int version4 = 4;

    namespace id
    {
        inline constexpr auto range      = "range";
        inline constexpr auto pw         = "pw";
        inline constexpr auto pwmSource  = "pwmSource";
        inline constexpr auto sawLevel   = "sawLevel";
        inline constexpr auto pulseLevel = "pulseLevel";
        inline constexpr auto subLevel   = "subLevel";
        inline constexpr auto noiseLevel = "noiseLevel";
        inline constexpr auto lfoPitch   = "lfoPitch";
        inline constexpr auto hpf        = "hpf";
        inline constexpr auto cutoff     = "cutoff";
        inline constexpr auto resonance  = "resonance";
        inline constexpr auto envAmount  = "envAmount";
        inline constexpr auto lfoFilter  = "lfoFilter";
        inline constexpr auto keyTrack   = "keyTrack";
        inline constexpr auto attack     = "attack";
        inline constexpr auto decay      = "decay";
        inline constexpr auto sustain    = "sustain";
        inline constexpr auto release    = "release";
        inline constexpr auto vcaMode    = "vcaMode";
        inline constexpr auto lfoRate    = "lfoRate";
        inline constexpr auto lfoDelay   = "lfoDelay";
        inline constexpr auto chorus     = "chorus";
        inline constexpr auto voiceMode  = "voiceMode";
        inline constexpr auto glide      = "glide";
        inline constexpr auto drift      = "drift";
        inline constexpr auto velocity   = "velocity";
        inline constexpr auto volume     = "volume";

        // v2
        inline constexpr auto unison        = "unison";
        inline constexpr auto unisonDetune  = "unisonDetune";
        inline constexpr auto unisonWidth   = "unisonWidth";
        inline constexpr auto ampAttack     = "ampAttack";
        inline constexpr auto ampDecay      = "ampDecay";
        inline constexpr auto ampSustain    = "ampSustain";
        inline constexpr auto ampRelease    = "ampRelease";
        inline constexpr auto delayTime     = "delayTime";
        inline constexpr auto delayFeedback = "delayFeedback";
        inline constexpr auto delayMix      = "delayMix";
        inline constexpr auto reverbSize    = "reverbSize";
        inline constexpr auto reverbMix     = "reverbMix";

        // v3
        inline constexpr auto drive         = "drive";
        inline constexpr auto tube          = "tube";
        inline constexpr auto phaser        = "phaser";
        inline constexpr auto phaserMix     = "phaserMix";

        // v4
        inline constexpr auto dust          = "dust";
    }

    juce::AudioProcessorValueTreeState::ParameterLayout createLayout();
}
