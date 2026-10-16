// Offline-Test: spielt jedes Factory-Preset, prüft das Signal und schreibt WAVs.
// Aufruf: CONTRA86_Render <Ausgabeordner>

#include "PluginProcessor.h"
#include "Presets.h"

#include <juce_audio_formats/juce_audio_formats.h>
#include <iostream>

namespace
{
struct Note { double start, length; int pitch; float velocity; };

std::vector<Note> phraseFor (int preset)
{
    std::vector<Note> notes;

    switch (preset)
    {
        case 2: // Saw Bass: Mono-Linie mit Legato-Überlappungen
            for (int bar = 0; bar < 2; ++bar)
                for (auto [step, pitch] : { std::pair { 0, 36 }, { 3, 36 }, { 6, 43 }, { 8, 41 }, { 11, 39 }, { 14, 48 } })
                    notes.push_back ({ bar * 1.935 + step * 0.121, 0.16, pitch, step == 0 ? 1.0f : 0.75f });
            break;

        case 4: // House Pluck: Akkord-Stabs auf der Offbeat-Achtel
            for (int i = 0; i < 8; ++i)
                for (auto pitch : { 60, 63, 67, 70 })
                    notes.push_back ({ 0.242 + i * 0.484, 0.2, pitch, 0.9f });
            break;

        default: // Akkord halten (Cm9)
            for (auto pitch : { 48, 55, 58, 62, 63 })
                notes.push_back ({ 0.0, 2.8, pitch, 0.85f });
            notes.push_back ({ 3.2, 0.6, 72, 1.0f });
            break;
    }

    return notes;
}

juce::MidiBuffer midiFor (const std::vector<Note>& notes, double sampleRate)
{
    juce::MidiBuffer midi;
    for (const auto& n : notes)
    {
        midi.addEvent (juce::MidiMessage::noteOn (1, n.pitch, n.velocity), juce::roundToInt (n.start * sampleRate));
        midi.addEvent (juce::MidiMessage::noteOff (1, n.pitch), juce::roundToInt ((n.start + n.length) * sampleRate));
    }
    return midi;
}

// blockSize <= 0: zufällige Blockgrößen 1..700 (größer als prepare-Größe)
juce::AudioBuffer<float> render (int preset, double sampleRate, int channels, int blockSize, double seconds)
{
    Contra86Processor proc;
    proc.setCurrentProgram (preset);

    juce::AudioProcessor::BusesLayout layout;
    layout.outputBuses.add (channels == 1 ? juce::AudioChannelSet::mono() : juce::AudioChannelSet::stereo());
    proc.setBusesLayout (layout);
    proc.setRateAndBufferSizeDetails (sampleRate, 512);
    proc.prepareToPlay (sampleRate, 512);

    const auto total = static_cast<int> (seconds * sampleRate);
    juce::AudioBuffer<float> result (channels, total);
    const auto allMidi = midiFor (phraseFor (preset), sampleRate);

    juce::Random random (42);
    juce::AudioBuffer<float> block (channels, 1024);
    juce::MidiBuffer midi;

    for (int pos = 0; pos < total;)
    {
        const auto n = std::min (total - pos, blockSize > 0 ? blockSize : 1 + random.nextInt (700));
        block.setSize (channels, n, false, false, true);
        block.clear();

        midi.clear();
        midi.addEvents (allMidi, pos, n, -pos);
        proc.processBlock (block, midi);

        for (int ch = 0; ch < channels; ++ch)
            result.copyFrom (ch, pos, block, ch, 0, n);
        pos += n;
    }

    proc.releaseResources();
    return result;
}

bool check (const juce::String& label, const juce::AudioBuffer<float>& b)
{
    float peak = 0.0f;
    double sumSquares = 0.0;

    for (int ch = 0; ch < b.getNumChannels(); ++ch)
        for (int i = 0; i < b.getNumSamples(); ++i)
        {
            const auto x = b.getSample (ch, i);
            if (! std::isfinite (x))
            {
                std::cout << "FAIL " << label << ": NaN/Inf\n";
                return false;
            }
            peak = std::max (peak, std::abs (x));
            sumSquares += static_cast<double> (x) * x;
        }

    const auto rms = std::sqrt (sumSquares / (b.getNumChannels() * b.getNumSamples()));
    const auto peakDb = juce::Decibels::gainToDecibels (peak);
    const auto rmsDb  = juce::Decibels::gainToDecibels (static_cast<float> (rms));
    const auto ok = peak < 1.0f && rmsDb > -50.0f;

    std::cout << (ok ? "ok   " : "FAIL ") << label.paddedRight (' ', 40)
              << " peak " << juce::String (peakDb, 1) << " dBFS, rms " << juce::String (rmsDb, 1) << " dBFS\n";
    return ok;
}

bool same (const juce::String& label, const juce::AudioBuffer<float>& a, const juce::AudioBuffer<float>& b)
{
    float maxDiff = 0.0f;
    for (int ch = 0; ch < a.getNumChannels(); ++ch)
        for (int i = 0; i < a.getNumSamples(); ++i)
            maxDiff = std::max (maxDiff, std::abs (a.getSample (ch, i) - b.getSample (ch, i)));

    const auto ok = maxDiff < 1.0e-4f;
    std::cout << (ok ? "ok   " : "FAIL ") << label.paddedRight (' ', 40) << " max diff " << maxDiff << "\n";
    return ok;
}

bool stateRoundTrip()
{
    Contra86Processor a, b;
    a.setCurrentProgram (3);

    juce::MemoryBlock data;
    a.getStateInformation (data);
    b.setStateInformation (data.getData(), static_cast<int> (data.getSize()));

    for (int i = 0; i < a.getParameters().size(); ++i)
        if (std::abs (a.getParameters()[i]->getValue() - b.getParameters()[i]->getValue()) > 1.0e-6f)
        {
            std::cout << "FAIL state round trip: " << a.getParameters()[i]->getName (64) << "\n";
            return false;
        }

    const auto ok = b.getCurrentProgram() == 3;
    std::cout << (ok ? "ok   " : "FAIL ") << "state round trip\n";
    return ok;
}

void writeWav (const juce::File& file, const juce::AudioBuffer<float>& b, double sampleRate)
{
    file.deleteFile();
    juce::WavAudioFormat wav;
    std::unique_ptr<juce::OutputStream> stream = file.createOutputStream();
    auto writer = wav.createWriterFor (stream, juce::AudioFormatWriterOptions{}
                                                   .withSampleRate (sampleRate)
                                                   .withNumChannels (b.getNumChannels())
                                                   .withBitsPerSample (24));
    if (writer != nullptr)
        writer->writeFromAudioSampleBuffer (b, 0, b.getNumSamples());
}
}

int main (int argc, char** argv)
{
    juce::ScopedJuceInitialiser_GUI juce;

    const auto outDir = juce::File::getCurrentWorkingDirectory().getChildFile (argc > 1 ? argv[1] : "renders");
    outDir.createDirectory();

    auto ok = stateRoundTrip();

    for (int p = 0; p < presets::count(); ++p)
    {
        const auto name = presets::name (p);

        for (auto sr : { 44100, 48000, 96000, 192000 })
        {
            const auto label = name + " @ " + juce::String (sr / 1000.0, 1) + " kHz";
            const auto reference = render (p, sr, 2, 512, 4.5);
            ok &= check (label, reference);

            if (sr == 48000)
            {
                ok &= same (name + " block 1 vs 512", reference, render (p, sr, 2, 1, 4.5));
                ok &= same (name + " random blocks vs 512", reference, render (p, sr, 2, 0, 4.5));
                ok &= check (name + " mono", render (p, sr, 1, 512, 4.5));
                writeWav (outDir.getChildFile (name.replaceCharacter (' ', '_') + ".wav"), reference, sr);
            }
        }
    }

    std::cout << (ok ? "\nALL PASSED" : "\nFAILURES") << "  (WAVs in " << outDir.getFullPathName() << ")\n";
    return ok ? 0 : 1;
}
