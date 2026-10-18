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
        3, 1, juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR, true, false);
    oversampling->initProcessing (static_cast<size_t> (maxBlock));

    // Die Stimmen werden direkt auf 2× Rate erzeugt, es läuft also nur der
    // Downsampling-Pfad. Dessen Verzögerung ist die halbe Gesamtlatenz.
    latencySamples = juce::roundToInt (oversampling->getLatencyInSamples() * 0.5f);

    zeroBuffer.setSize (3, maxBlock);
    zeroBuffer.clear();
    stereoBuffer.setSize (3, maxBlock);
    reverbBuffer.setSize (2, maxBlock);

    for (size_t i = 0; i < voices.size(); ++i)
        voices[i].prepare (osRate, 0x1234567u * static_cast<uint32_t> (i + 1));

    chorus.prepare (baseRate);
    delay.prepare (baseRate);
    phaser.prepare (baseRate);
    tube.prepare (osRate);
    leadDist.prepare (osRate);
    dust.prepare (baseRate);
    reverb.setSampleRate (baseRate);

    const auto g = std::tan (juce::MathConstants<double>::pi * 200.0 / baseRate);
    reverbHpfG = static_cast<float> (g);

    cutoff.reset (osRate, 0.02);
    for (auto* s : { &resonance, &envAmount, &lfoFilter, &keyTrack, &pw, &saw, &pulse,
                     &sub, &noise, &lfoPitch, &drift, &bend, &modWheel, &unisonDetune, &unisonWidth, &drive, &blend, &subLevel })
        s->reset (osRate, 0.02);

    hpfHz.reset (baseRate, 0.02);
    volume.reset (baseRate, 0.02);
    reverbMix.reset (baseRate, 0.02);

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
    delay.reset();
    phaser.reset();
    tube.reset();
    dust.reset();
    leadDist.reset();
    reverb.reset();
    reverbActive = false;
    for (auto* f : { &hpfL, &hpfR, &reverbHpfL, &reverbHpfR })
        f->reset();

    keyDown.fill (false);
    sustained.fill (false);
    sustainPedal = false;
    monoCount = 0;
    lfoPhase = 0.0f;
    lfoDelayGain = 1.0f;

    applySettings (current);

    cutoff.setCurrentAndTargetValue (cutoff.getTargetValue());
    for (auto* s : { &resonance, &envAmount, &lfoFilter, &keyTrack, &pw, &saw, &pulse,
                     &sub, &noise, &lfoPitch, &drift, &unisonDetune, &unisonWidth, &drive, &blend, &subLevel, &volume, &reverbMix })
        s->setCurrentAndTargetValue (s->getTargetValue());
    hpfHz.setCurrentAndTargetValue (hpfHz.getTargetValue());
    bend.setCurrentAndTargetValue (0.0f);
    modWheel.setCurrentAndTargetValue (0.0f);
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
    lfoPitch.setTargetValue (s.lfoPitch * s.lfoPitch * 12.0f);
    drift.setTargetValue (s.drift);
    unisonDetune.setTargetValue (s.unisonDetune);
    unisonWidth.setTargetValue (s.unisonWidth);
    drive.setTargetValue (s.drive);
    tube.setAmount (s.tube);
    dust.setAmount (s.dust, s.dustTape, s.dustCrush, s.dustNoise, s.dustTone);
    leadDist.setAmount (s.dist);
    blend.setTargetValue (s.blend);
    subLevel.setTargetValue (s.subLevel);

    mods.bWave        = s.bWave;
    mods.bRatio       = std::exp2 (s.bOctave + s.bSemi / 12.0f + s.bFine / 1200.0f);
    mods.subOctave    = static_cast<float> (s.subOctave * 12);
    mods.subDropSemis = s.subDrop * 12.0f;
    mods.subDrive     = s.subDrive;
    mods.subDecayCoef   = std::exp (-6.9f / (std::max (0.05f, s.subDecay) * static_cast<float> (osRate)));
    mods.subReleaseCoef = std::exp (-6.9f / (0.08f * static_cast<float> (osRate)));
    mods.subDropCoef    = std::exp (-1.0f / (0.04f * static_cast<float> (osRate)));
    phaser.setParameters (static_cast<Phaser::Mode> (s.phaser), s.phaserMix);
    hpfHz.setTargetValue (s.hpfHz);
    volume.setTargetValue (juce::Decibels::decibelsToGain (s.volumeDb, -48.0f));
    reverbMix.setTargetValue (s.reverbMix);

    chorus.setMode (s.chorus);

    const auto bpm = s.bpm > 20.0 && s.bpm < 999.0 ? s.bpm : 120.0;
    // Throw: solange gehalten, Delay voll aufreißen (Feedback mindestens 72 %)
    delay.setParameters (static_cast<float> (s.delayBeats * 60.0 / bpm),
                         s.throwOn ? std::max (s.delayFeedback, 0.72f) : s.delayFeedback,
                         s.throwOn ? 1.0f : s.delayMix);

    const auto roomSize = 0.55f + 0.43f * s.reverbSize;
    if (std::abs (roomSize - reverbParams.roomSize) > 1.0e-4f)
    {
        reverbParams.roomSize   = roomSize;
        reverbParams.damping    = 0.6f - 0.3f * s.reverbSize;
        reverbParams.width      = 1.0f;
        reverbParams.wetLevel   = 1.0f / 3.0f;
        reverbParams.dryLevel   = 0.0f;
        reverbParams.freezeMode = 0.0f;
        reverb.setParameters (reverbParams);
    }

    lfoInc = s.lfoRate / static_cast<float> (osRate);
    lfoDelayStep = s.lfoDelay > 0.0f ? 1.0f / (s.lfoDelay * static_cast<float> (osRate)) : 1.0f;

    mods.octaveShift = static_cast<float> (s.octave * 12);
    mods.glideCoef   = s.voiceMode == VoiceMode::mono && s.glide > 0.0005f
                         ? std::exp (-4.6f / (s.glide * static_cast<float> (osRate))) : 0.0f;
    mods.pwmSource   = s.pwmSource;
    mods.vcaMode     = s.vcaMode;
    mods.unison      = std::clamp (s.unison, 1, maxUnison);

    const AdsrTimes env1 { s.attack, s.decay, s.sustain, s.release };
    const AdsrTimes env2 { s.ampAttack, s.ampDecay, s.ampSustain, s.ampRelease };
    for (auto& v : voices)
        v.updateEnvelopes (env1, env2, s.drift, osRate);
}

// Mitte unverstimmt, Paare symmetrisch nach außen, Pegel ∝ 1/√n.
void SynthEngine::updateUnison (float detune, float width) noexcept
{
    const auto n = mods.unison;
    const auto norm = 1.0f / std::sqrt (static_cast<float> (n));
    mods.stereo = n > 1 && width > 0.001f;

    for (int u = 0; u < n; ++u)
    {
        const auto uz = static_cast<size_t> (u);
        auto offset = 0.0f;
        if (u > 0)
        {
            const auto pair = static_cast<float> ((u + 1) / 2);
            offset = (u % 2 == 1 ? -1.0f : 1.0f) * pair / static_cast<float> ((n - 1) / 2);
        }

        mods.ratio[uz] = std::exp2 (offset * detune * 50.0f / 1200.0f);

        if (mods.stereo)
        {
            const auto pan = offset * width;
            mods.gainL[uz] = norm * std::sqrt (1.0f - pan);
            mods.gainR[uz] = norm * std::sqrt (1.0f + pan);
        }
        else
        {
            mods.gainL[uz] = mods.gainR[uz] = norm;
        }
    }
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

        juce::dsp::AudioBlock<const float> zeros (zeroBuffer.getArrayOfReadPointers(), 3, static_cast<size_t> (len));
        auto up = oversampling->processSamplesUp (zeros);
        auto* osL = up.getChannelPointer (0);
        auto* osR = up.getChannelPointer (1);
        auto* osSub = up.getChannelPointer (2);
        juce::FloatVectorOperations::clear (osL, len * factor);
        juce::FloatVectorOperations::clear (osR, len * factor);
        juce::FloatVectorOperations::clear (osSub, len * factor);

        int pos = 0;
        for (; midiIt != midi.end(); ++midiIt)
        {
            const auto meta = *midiIt;
            const auto eventPos = juce::jlimit (0, numSamples - 1, meta.samplePosition) - chunkStart;
            if (eventPos >= len)
                break;

            if (eventPos > pos)
            {
                renderOversampled (osL, osR, osSub, pos * factor, eventPos * factor);
                pos = eventPos;
            }

            handleMidi (meta.data, meta.numBytes);
        }

        renderOversampled (osL, osR, osSub, pos * factor, len * factor);
        tube.process (osL, osR, len * factor);
        leadDist.process (osL, osR, len * factor);

        juce::dsp::AudioBlock<float> stereoBlock (stereoBuffer.getArrayOfWritePointers(), 3, static_cast<size_t> (len));
        oversampling->processSamplesDown (stereoBlock);

        auto* left  = stereoBuffer.getWritePointer (0);
        auto* right = stereoBuffer.getWritePointer (1);

        const auto piOverSr = juce::MathConstants<float>::pi / static_cast<float> (baseRate);
        for (int i = 0; i < len; ++i)
        {
            const auto g = std::tan (hpfHz.getNextValue() * piOverSr);
            left[i]  = hpfL.process (left[i], g);
            right[i] = hpfR.process (right[i], g);
        }

        chorus.process (left, right, len);
        phaser.process (left, right, len);
        delay.process (left, right, len);
        processReverb (left, right, len);
        dust.process (left, right, len);

        // 808-Bus kommt erst hier dazu: sauber, mono, an allen Effekten vorbei
        const auto* subOut = stereoBuffer.getReadPointer (2);
        for (int i = 0; i < len; ++i)
        {
            left[i]  += subOut[i];
            right[i] += subOut[i];
        }

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

// Reverb als Send: Input mit 200-Hz-Hochpass, nur Wet wird addiert.
void SynthEngine::processReverb (float* left, float* right, int numSamples) noexcept
{
    const auto silent = reverbMix.getTargetValue() < 1.0e-6f && ! reverbMix.isSmoothing();
    if (silent)
    {
        if (reverbActive)
        {
            reverb.reset();
            reverbActive = false;
        }
        return;
    }

    reverbActive = true;
    auto* wetL = reverbBuffer.getWritePointer (0);
    auto* wetR = reverbBuffer.getWritePointer (1);

    for (int i = 0; i < numSamples; ++i)
    {
        wetL[i] = reverbHpfL.process (left[i], reverbHpfG);
        wetR[i] = reverbHpfR.process (right[i], reverbHpfG);
    }

    reverb.processStereo (wetL, wetR, numSamples);

    for (int i = 0; i < numSamples; ++i)
    {
        const auto mix = reverbMix.getNextValue();
        left[i]  += mix * wetL[i];
        right[i] += mix * wetR[i];
    }
}

void SynthEngine::renderOversampled (float* osL, float* osR, float* osSub, int start, int end) noexcept
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
            driveBuf[i_]   = drive.getNextValue();
            blendBuf[i_]   = blend.getNextValue();
        }

        updateUnison (unisonDetune.skip (n), unisonWidth.skip (n));
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
        mods.drive      = driveBuf.data();
        mods.blend      = blendBuf.data();
        mods.layerB     = blend.getTargetValue() > 1.0e-4f || blend.isSmoothing() || blendBuf[0] > 1.0e-4f;
        mods.subLevel   = subLevel.skip (n);

        for (auto& v : voices)
            v.render (osL + p, osR + p, osSub + p, n, mods);
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
