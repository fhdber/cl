#pragma once

#include "Theme.h"
#include "ScopeBuffer.h"

#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_dsp/juce_dsp.h>

class Contra86Processor;

namespace ui
{
// Schwarzes Display mit Visualizer. Zeigt Preset und Oszilloskop mit Spektrum;
// beim Bedienen eines Reglers Wert und Bild des Reglers (Filterkurve,
// Hüllkurve, LFO, 808-Drop, Echos, Dust). Die Filterkurve lässt sich ziehen:
// waagerecht = Cutoff, senkrecht = Resonanz.
class Display final : public juce::Component, private juce::Timer
{
public:
    explicit Display (Contra86Processor&);

    void showParameter (juce::RangedAudioParameter&);

    void paint (juce::Graphics&) override;
    void resized() override;
    void mouseDown (const juce::MouseEvent&) override;
    void mouseDrag (const juce::MouseEvent&) override;
    void mouseUp (const juce::MouseEvent&) override;

private:
    enum class Visual { scope, filter, envFilter, envAmp, lfo, sub, delay, dust };

    void timerCallback() override;
    void updateSpectrum();
    void stepPreset (int delta);
    void selectPreset (int index);
    void openPresetMenu();
    juce::String statusText() const;
    float raw (const char* id) const;

    void paintSpectrum (juce::Graphics&, juce::Rectangle<float>) const;
    void paintScope (juce::Graphics&, juce::Rectangle<float>, bool quantised) const;
    void paintFilter (juce::Graphics&, juce::Rectangle<float>) const;
    void paintEnvelope (juce::Graphics&, juce::Rectangle<float>, bool amp) const;
    void paintLfo (juce::Graphics&, juce::Rectangle<float>) const;
    void paintSub (juce::Graphics&, juce::Rectangle<float>) const;
    void paintDelay (juce::Graphics&, juce::Rectangle<float>) const;
    juce::Point<float> filterPoint (juce::Rectangle<float>, float freq) const;

    Contra86Processor& processor;

    bool compact = false;
    juce::Rectangle<float> headerArea, valueArea, prevArea, nextArea, visualArea, statusArea;
    Visual visual = Visual::scope;
    juce::RangedAudioParameter* shown = nullptr;
    juce::String shownId;
    double valueUntil = 0.0;
    int shownProgram = -1;

    bool draggingCurve = false;
    juce::Point<float> dragStart;
    float dragCutoff = 0.0f, dragReso = 0.0f;

    std::array<float, 2048> snapshot {};
    int scopeStart = 0;
    juce::dsp::FFT fft { 11 };
    juce::dsp::WindowingFunction<float> window { 2048, juce::dsp::WindowingFunction<float>::hann };
    std::array<float, 4096> fftData {};
    std::array<float, 48> bands {};
};
}
