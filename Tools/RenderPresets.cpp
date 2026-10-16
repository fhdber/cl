// Offline-Test: spielt jedes Factory-Preset, prüft das Signal und schreibt WAVs
// (einzeln und als Showcase pro Kategorie).
// Aufruf: CONTRA86_Render <Ausgabeordner>

#include "PluginProcessor.h"
#include "Presets.h"

#include <juce_audio_formats/juce_audio_formats.h>
#include <iostream>
#include <map>

namespace
{
struct Note { double start, length; int pitch; float velocity; };

constexpr double phraseSeconds = 4.0;

std::vector<Note> phraseFor (const juce::String& category)
{
    std::vector<Note> notes;
    constexpr double step = 0.125; // Sechzehntel bei 120 BPM

    if (category == "Bass")
    {
        for (int bar = 0; bar < 2; ++bar)
            for (auto [s, pitch] : { std::pair { 0, 36 }, { 3, 36 }, { 6, 43 }, { 8, 41 }, { 11, 39 }, { 14, 48 } })
                notes.push_back ({ bar * 2.0 + s * step, 0.16, pitch, s == 0 ? 1.0f : 0.75f });
    }
    else if (category == "Lead")
    {
        for (auto [s, len, pitch] : { std::tuple { 0, 3, 72 }, { 4, 2, 75 }, { 6, 2, 77 }, { 8, 6, 79 },
                                      { 15, 1, 77 }, { 16, 2, 75 }, { 18, 2, 74 }, { 20, 8, 72 } })
            notes.push_back ({ s * step, len * step + 0.02, pitch, 0.9f });
    }
    else if (category == "Pluck")
    {
        for (int i = 0; i < 16; ++i)
            notes.push_back ({ i * 2 * step, step, std::array { 60, 63, 67, 70, 72, 70, 67, 63 }[static_cast<size_t> (i % 8)], 0.9f });
    }
    else if (category == "Keys")
    {
        for (int i = 0; i < 4; ++i)
            for (auto pitch : { 60, 63, 67, 70 })
                notes.push_back ({ 0.25 + i * 0.75, 0.3, pitch - (i >= 2 ? 2 : 0), 0.9f });
    }
    else if (category == "FX")
    {
        notes.push_back ({ 0.0, 2.5, 60, 1.0f });
    }
    else
    {
        for (auto pitch : { 48, 55, 58, 62, 63 })
            notes.push_back ({ 0.0, 2.6, pitch, 0.85f });
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
    const auto allMidi = midiFor (phraseFor (presets::category (preset)), sampleRate);

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
    const auto ok = peak < 1.0f && peakDb > -30.0f;

    std::cout << (ok ? "ok   " : "FAIL ") << label.paddedRight (' ', 44)
              << " peak " << juce::String (peakDb, 1).paddedLeft (' ', 5) << " dBFS, rms "
              << juce::String (rmsDb, 1).paddedLeft (' ', 5) << " dBFS\n";
    return ok;
}

bool same (const juce::String& label, const juce::AudioBuffer<float>& a, const juce::AudioBuffer<float>& b)
{
    float maxDiff = 0.0f;
    for (int ch = 0; ch < a.getNumChannels(); ++ch)
        for (int i = 0; i < a.getNumSamples(); ++i)
            maxDiff = std::max (maxDiff, std::abs (a.getSample (ch, i) - b.getSample (ch, i)));

    const auto ok = maxDiff < 1.0e-4f;
    if (! ok)
        std::cout << "FAIL " << label.paddedRight (' ', 44) << " max diff " << maxDiff << "\n";
    return ok;
}

bool stateRoundTrip()
{
    Contra86Processor a, b;
    a.setCurrentProgram (5);

    juce::MemoryBlock data;
    a.getStateInformation (data);
    b.setStateInformation (data.getData(), static_cast<int> (data.getSize()));

    for (int i = 0; i < a.getParameters().size(); ++i)
        if (std::abs (a.getParameters()[i]->getValue() - b.getParameters()[i]->getValue()) > 1.0e-6f)
        {
            std::cout << "FAIL state round trip: " << a.getParameters()[i]->getName (64) << "\n";
            return false;
        }

    const auto ok = b.getCurrentProgram() == 5;
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

void append (juce::AudioBuffer<float>& showcase, const juce::AudioBuffer<float>& b)
{
    const auto start = showcase.getNumSamples();
    showcase.setSize (2, start + b.getNumSamples(), true, true);
    for (int ch = 0; ch < 2; ++ch)
        showcase.copyFrom (ch, start, b, ch, 0, b.getNumSamples());
}
// Rendert den Editor mit laufendem Preset als PNG (für Doku und Sichtprüfung).
int screenshot (const juce::File& file, int preset, float scale)
{
    Contra86Processor proc;
    proc.setCurrentProgram (preset);
    proc.setRateAndBufferSizeDetails (48000.0, 512);
    proc.prepareToPlay (48000.0, 512);

    juce::AudioBuffer<float> block (2, 512);
    juce::MidiBuffer midi;
    midi.addEvent (juce::MidiMessage::noteOn (1, 48, 0.9f), 0);
    midi.addEvent (juce::MidiMessage::noteOn (1, 55, 0.9f), 0);
    midi.addEvent (juce::MidiMessage::noteOn (1, 63, 0.9f), 0);
    for (int i = 0; i < 120; ++i)
    {
        proc.processBlock (block, midi);
        midi.clear();
    }

    std::unique_ptr<juce::AudioProcessorEditor> editor (proc.createEditorAndMakeActive());
    editor->setSize (juce::roundToInt (1040 * scale), juce::roundToInt (820 * scale));
    editor->setVisible (true);
    juce::Timer::callAfterDelay (400, [] { juce::MessageManager::getInstance()->stopDispatchLoop(); });
    juce::MessageManager::getInstance()->runDispatchLoop();

    const auto image = editor->createComponentSnapshot (editor->getLocalBounds(), true, 2.0f);
    file.deleteFile();
    juce::FileOutputStream out (file);
    juce::PNGImageFormat().writeImageToStream (image, out);
    std::cout << "screenshot " << file.getFullPathName() << "\n";
    editor.reset();
    return 0;
}
}

int main (int argc, char** argv)
{
    juce::ScopedJuceInitialiser_GUI juce;

    if (argc > 2 && juce::String (argv[1]) == "--ui")
        return screenshot (juce::File::getCurrentWorkingDirectory().getChildFile (argv[2]),
                           argc > 3 ? juce::String (argv[3]).getIntValue() : 1, 1.0f);

    const auto outDir = juce::File::getCurrentWorkingDirectory().getChildFile (argc > 1 ? argv[1] : "renders");
    outDir.createDirectory();

    constexpr int demoRate = 48000;
    auto ok = stateRoundTrip();
    int checked = 0;
    std::map<juce::String, juce::AudioBuffer<float>> showcases;

    for (int p = 0; p < presets::count(); ++p)
    {
        const auto name = presets::fullName (p);
        const auto t0 = juce::Time::getMillisecondCounterHiRes();
        const auto reference = render (p, demoRate, 2, 512, phraseSeconds);
        const auto cpu = (juce::Time::getMillisecondCounterHiRes() - t0) / (phraseSeconds * 10.0);
        ok &= check (name, reference);
        std::cout << "     CPU " << juce::String (cpu, 1) << " % eines Kerns (48 kHz)\n";

        ok &= same (name + " block 1", reference, render (p, demoRate, 2, 1, phraseSeconds));
        ok &= same (name + " random blocks", reference, render (p, demoRate, 2, 0, phraseSeconds));

        for (auto sr : { 44100, 96000, 192000 })
        {
            const auto b = render (p, sr, 2, 512, 2.0);
            const auto label = name + " @ " + juce::String (sr / 1000.0, 1) + " kHz";
            const auto good = b.getNumSamples() > 0 && check (label, b);
            ok &= good;
        }

        const auto monoOk = check (name + " mono", render (p, demoRate, 1, 512, phraseSeconds));
        ok &= monoOk;
        checked += 6;

        writeWav (outDir.getChildFile (presets::category (p) + "_" + presets::name (p).replaceCharacter (' ', '_') + ".wav"),
                  reference, demoRate);

        if (p > 0)
            append (showcases[presets::category (p)], reference);
    }

    for (auto& [category, buffer] : showcases)
        writeWav (outDir.getChildFile ("Showcase_" + category + ".wav"), buffer, demoRate);

    std::cout << (ok ? "\nALL PASSED" : "\nFAILURES") << " (" << presets::count() << " presets, "
              << checked << " checks)  WAVs in " << outDir.getFullPathName() << "\n";
    return ok ? 0 : 1;
}
