#include "SynthEngine.h"

namespace dsp86
{
void SynthEngine::prepare (double sampleRate, int maxBlockSize, const Settings& initial)
{
    current  = initial;
    baseRate = sampleRate;
    osRate   = sampleRate * factor;
    maxBlock = std::max (1, maxBlockSize);

    oversampling = std::make_unique<juce::dsp::Oversampling<float>> (
        1, 1, juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR, true, false);
    oversampling->initProcessing (static_cast<size_t> (maxBlock));

    // Die Stimmen werden direkt auf 2× Rate erzeugt, es läuft also nur der
    // Downsampling-Pfad. Dessen Verzögerung ist die halbe Gesamtlatenz.
    latencySamples = juce::roundToInt (oversampling->getLatencyInSamples() * 0.5f);

    zeroBuffer.setSize (1, maxBlock);
    zeroBuffer.clear();
    monoBuffer.setSize (1, maxBlock);
    rightBuffer.setSize (1, maxBlock);

    for (size_t i = 0; i < voices.size(); ++i)
        voices[i].prepare (osRate, 0x1234567u * static_cast<uint32_t> (i + 1));

    chorus.prepare (baseRate);

    cutoff.reset (osRate, 0.02);
    for (auto* s : { &resonance, &envAmount, &lfoFilter, &keyTrack, &pw, &saw, &pulse,
                     &sub, &noise, &lfoPitch, &drift, &bend, &modWheel })
        s->reset (osRate, 0.02);

    hpfHz.reset (baseRate, 0.02);
    volume.reset (baseRate, 0.02);

    mods.gate = AdsrCoefs::make (0.001f, 0.001f, 1.0f, 0.005f, osRate);

    reset();
}

void SynthEngine::reset()
{
    if (oversampling == nullptr)
        return;

    for (auto& v : voices)
        v.kill();

    oversampling->reset();
    chorus.reset();
    hpf.reset();

    keyDown.fill (false);
    sustained.fill (false);
    sustainPedal = false;
    monoCount = 0;
    lfoPhase = 0.0f;
    lfoDelayGain = 1.0f;

    applySettings (current);

    cutoff.setCurrentAndTargetValue (current.cutoffHz);
    resonance.setCurrentAndTargetValue (current.resonance);
    envAmount.setCurrentAndTargetValue (current.envAmount);
    lfoFilter.setCurrentAndTargetValue (current.lfoFilter);
    keyTrack.setCurrentAndTargetValue (current.keyTrack);
    pw.setCurrentAndTargetValue (current.pw);
    saw.setCurrentAndTargetValue (current.saw);
    pulse.setCurrentAndTargetValue (current.pulse);
    sub.setCurrentAndTargetValue (current.sub);
    noise.setCurrentAndTargetValue (current.noise);
    lfoPitch.setCurrentAndTargetValue (current.lfoPitch);
    drift.setCurrentAndTargetValue (current.drift);
    bend.setCurrentAndTargetValue (0.0f);
    modWheel.setCurrentAndTargetValue (0.0f);
    hpfHz.setCurrentAndTargetValue (current.hpfHz);
    volume.setCurrentAndTargetValue (juce::Decibels::decibelsToGain (current.volumeDb));
}

void SynthEngine::applySettings (const Settings& s) noexcept
{
    if (s.voiceMode != current.voiceMode)
        allNotesOff();

    current = s;

    cutoff.setTargetValue (s.cutoffHz);
    resonance.setTargetValue (s.resonance);
    envAmount.setTargetValue (s.envAmount * 8.0f);
    lfoFilter.setTargetValue (s.lfoFilter * 4.0f);
    keyTrack.setTargetValue (s.keyTrack);
    pw.setTargetValue (s.pw);
    saw.setTargetValue (s.saw);
    pulse.setTargetValue (s.pulse);
    sub.setTargetValue (s.sub);
    noise.setTargetValue (s.noise);
    lfoPitch.setTargetValue (s.lfoPitch * s.lfoPitch * 2.0f);
    drift.setTargetValue (s.drift);
    hpfHz.setTargetValue (s.hpfHz);
    volume.setTargetValue (juce::Decibels::decibelsToGain (s.volumeDb, -48.0f));

    chorus.setMode (s.chorus);

    lfoInc = s.lfoRate / static_cast<float> (osRate);
    lfoDelayStep = s.lfoDelay > 0.0f ? 1.0f / (s.lfoDelay * static_cast<float> (osRate)) : 1.0f;

    mods.octaveShift = static_cast<float> (s.octave * 12);
    mods.glideCoef   = s.voiceMode == VoiceMode::mono && s.glide > 0.0005f
                         ? std::exp (-4.6f / (s.glide * static_cast<float> (osRate))) : 0.0f;
    mods.pwmSource   = s.pwmSource;
    mods.vcaMode     = s.vcaMode;
    mods.env         = AdsrCoefs::make (s.attack, s.decay, s.sustain, s.release, osRate);
}

void SynthEngine::process (juce::AudioBuffer<float>& out, const juce::MidiBuffer& midi, const Settings& settings) noexcept
{
    applySettings (settings);

    const auto numSamples  = out.getNumSamples();
    const auto numChannels = out.getNumChannels();
    auto midiIt = midi.begin();

    for (int chunkStart = 0; chunkStart < numSamples; chunkStart += maxBlock)
    {
        const auto len = std::min (maxBlock, numSamples - chunkStart);

        juce::dsp::AudioBlock<const float> zeros (zeroBuffer.getArrayOfReadPointers(), 1, static_cast<size_t> (len));
        auto up = oversampling->processSamplesUp (zeros);
        auto* os = up.getChannelPointer (0);
        juce::FloatVectorOperations::clear (os, len * factor);

        int pos = 0;
        for (; midiIt != midi.end(); ++midiIt)
        {
            const auto meta = *midiIt;
            const auto eventPos = juce::jlimit (0, numSamples - 1, meta.samplePosition) - chunkStart;
            if (eventPos >= len)
                break;

            if (eventPos > pos)
            {
                renderOversampled (os, pos * factor, eventPos * factor);
                pos = eventPos;
            }

            handleMidi (meta.data, meta.numBytes);
        }

        renderOversampled (os, pos * factor, len * factor);

        auto* left  = monoBuffer.getWritePointer (0);
        auto* right = rightBuffer.getWritePointer (0);
        juce::dsp::AudioBlock<float> monoBlock (monoBuffer.getArrayOfWritePointers(), 1, static_cast<size_t> (len));
        oversampling->processSamplesDown (monoBlock);

        const auto piOverSr = juce::MathConstants<float>::pi / static_cast<float> (baseRate);
        for (int i = 0; i < len; ++i)
            left[i] = hpf.process (left[i], std::tan (hpfHz.getNextValue() * piOverSr));

        chorus.process (left, left, right, len);

        for (int i = 0; i < len; ++i)
        {
            const auto g = volume.getNextValue();
            left[i]  *= g;
            right[i] *= g;
        }

        if (numChannels == 1)
        {
            auto* dst = out.getWritePointer (0, chunkStart);
            for (int i = 0; i < len; ++i)
                dst[i] = 0.5f * (left[i] + right[i]);
        }
        else if (numChannels >= 2)
        {
            out.copyFrom (0, chunkStart, left, len);
            out.copyFrom (1, chunkStart, right, len);
            for (int ch = 2; ch < numChannels; ++ch)
                out.clear (ch, chunkStart, len);
        }
    }
}

void SynthEngine::renderOversampled (float* os, int start, int end) noexcept
{
    for (int p = start; p < end; p += modChunk)
    {
        const auto n = std::min (modChunk, end - p);

        for (int i = 0; i < n; ++i)
        {
            lfoPhase += lfoInc;
            if (lfoPhase >= 1.0f)
                lfoPhase -= 1.0f;

            lfoDelayGain = std::min (1.0f, lfoDelayGain + lfoDelayStep);
            const auto lfo = (4.0f * std::abs (lfoPhase - 0.5f) - 1.0f) * lfoDelayGain;

            const auto i_ = static_cast<size_t> (i);
            lfoBuf[i_]     = lfo;
            pitchBuf[i_]   = bend.getNextValue() + lfo * (lfoPitch.getNextValue() + 0.5f * modWheel.getNextValue());
            pwBuf[i_]      = pw.getNextValue();
            sawBuf[i_]     = saw.getNextValue();
            pulseBuf[i_]   = pulse.getNextValue();
            subBuf[i_]     = sub.getNextValue();
            noiseBuf[i_]   = noise.getNextValue();
            cutoffBuf[i_]  = cutoff.getNextValue();
            resoBuf[i_]    = resonance.getNextValue();
            envBuf[i_]     = envAmount.getNextValue();
            lfoFiltBuf[i_] = lfo * lfoFilter.getNextValue();
            keyBuf[i_]     = keyTrack.getNextValue();
        }

        mods.drift = drift.skip (n);
        mods.pitchSemis = pitchBuf.data();
        mods.lfo        = lfoBuf.data();
        mods.pw         = pwBuf.data();
        mods.saw        = sawBuf.data();
        mods.pulse      = pulseBuf.data();
        mods.sub        = subBuf.data();
        mods.noise      = noiseBuf.data();
        mods.cutoffHz   = cutoffBuf.data();
        mods.resonance  = resoBuf.data();
        mods.envOctaves = envBuf.data();
        mods.lfoOctaves = lfoFiltBuf.data();
        mods.keyTrack   = keyBuf.data();

        for (auto& v : voices)
            v.render (os + p, n, mods);
    }
}

void SynthEngine::handleMidi (const juce::uint8* data, int numBytes) noexcept
{
    if (numBytes < 1)
        return;

    const auto status = data[0] & 0xf0;
    const auto d1 = numBytes > 1 ? data[1] & 0x7f : 0;
    const auto d2 = numBytes > 2 ? data[2] & 0x7f : 0;

    switch (status)
    {
        case 0x90:
            if (numBytes < 3) return;
            if (d2 > 0) noteOn (d1, static_cast<float> (d2) / 127.0f);
            else        noteOff (d1);
            break;

        case 0x80:
            if (numBytes >= 2) noteOff (d1);
            break;

        case 0xe0:
            if (numBytes >= 3)
                bend.setTargetValue (static_cast<float> (((d2 << 7) | d1) - 8192) / 8192.0f * 2.0f);
            break;

        case 0xb0:
            if (numBytes < 3) return;
            switch (d1)
            {
                case 1:
                    modWheel.setTargetValue (static_cast<float> (d2) / 127.0f);
                    break;

                case 64:
                    sustainPedal = d2 >= 64;
                    if (! sustainPedal)
                        for (int n = 0; n < 128; ++n)
                            if (sustained[static_cast<size_t> (n)])
                                releaseNote (n);
                    break;

                case 120:
                    for (auto& v : voices)
                        v.kill();
                    allNotesOff();
                    break;

                case 121:
                    bend.setTargetValue (0.0f);
                    modWheel.setTargetValue (0.0f);
                    break;

                case 123:
                    allNotesOff();
                    break;

                default:
                    break;
            }
            break;

        default:
            break;
    }
}

int SynthEngine::heldKeyCount() const noexcept
{
    int count = 0;
    for (size_t n = 0; n < 128; ++n)
        if (keyDown[n] || sustained[n])
            ++count;
    return count;
}

void SynthEngine::noteOn (int note, float velocity) noexcept
{
    if (heldKeyCount() == 0)
        lfoDelayGain = current.lfoDelay > 0.0f ? 0.0f : 1.0f;

    keyDown[static_cast<size_t> (note)] = true;
    sustained[static_cast<size_t> (note)] = false;
    ++noteCounter;

    if (current.voiceMode == VoiceMode::mono)
    {
        const auto legato = monoCount > 0;

        int w = 0;
        for (int r = 0; r < monoCount; ++r)
            if (monoStack[static_cast<size_t> (r)] != note)
                monoStack[static_cast<size_t> (w++)] = monoStack[static_cast<size_t> (r)];
        monoCount = w;

        if (monoCount == static_cast<int> (monoStack.size()))
        {
            std::move (monoStack.begin() + 1, monoStack.end(), monoStack.begin());
            --monoCount;
        }

        monoStack[static_cast<size_t> (monoCount++)] = note;

        if (legato) voices[0].legatoTo (note, noteCounter);
        else        voices[0].start (note, velocity, current.velocity, noteCounter, false);
        return;
    }

    for (auto& v : voices)
        if (v.isActive() && v.getNote() == note)
        {
            v.start (note, velocity, current.velocity, noteCounter, false);
            return;
        }

    for (auto& v : voices)
        if (! v.isActive())
        {
            v.start (note, velocity, current.velocity, noteCounter, false);
            return;
        }

    Voice* victim = nullptr;
    for (auto& v : voices)
        if (! v.isHeld() && (victim == nullptr || v.getAge() < victim->getAge()))
            victim = &v;

    if (victim == nullptr)
        for (auto& v : voices)
            if (victim == nullptr || v.getAge() < victim->getAge())
                victim = &v;

    victim->start (note, velocity, current.velocity, noteCounter, true);
}

void SynthEngine::noteOff (int note) noexcept
{
    keyDown[static_cast<size_t> (note)] = false;

    if (sustainPedal)
        sustained[static_cast<size_t> (note)] = true;
    else
        releaseNote (note);
}

void SynthEngine::releaseNote (int note) noexcept
{
    sustained[static_cast<size_t> (note)] = false;

    if (current.voiceMode == VoiceMode::mono)
    {
        int index = -1;
        for (int i = 0; i < monoCount; ++i)
            if (monoStack[static_cast<size_t> (i)] == note)
                index = i;

        if (index < 0)
            return;

        const auto wasTop = index == monoCount - 1;
        std::move (monoStack.begin() + index + 1, monoStack.begin() + monoCount, monoStack.begin() + index);
        --monoCount;

        if (! wasTop)
            return;

        if (monoCount > 0) voices[0].legatoTo (monoStack[static_cast<size_t> (monoCount - 1)], ++noteCounter);
        else               voices[0].release();
        return;
    }

    for (auto& v : voices)
        if (v.isActive() && v.isHeld() && v.getNote() == note)
            v.release();
}

void SynthEngine::allNotesOff() noexcept
{
    for (auto& v : voices)
        if (v.isActive())
            v.release();

    keyDown.fill (false);
    sustained.fill (false);
    monoCount = 0;
}
}
