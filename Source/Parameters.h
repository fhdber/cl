#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

namespace params
{
    // Version 1 aller IDs. Neue Parameter bekommen eine höhere Versionsnummer,
    // damit gespeicherte Sessions in allen Hosts stabil bleiben.
    inline constexpr int version = 1;

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
    }

    enum class PwmSource { lfo, manual, env };
    enum class VcaMode   { env, gate };
    enum class Chorus    { off, one, two, both };
    enum class VoiceMode { poly, mono };

    juce::AudioProcessorValueTreeState::ParameterLayout createLayout();
}
