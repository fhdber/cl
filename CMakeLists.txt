cmake_minimum_required(VERSION 3.22)

if(APPLE)
    set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "Universal Binary")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS")
endif()

project(CONTRA86 VERSION 0.5.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# JUCE: per FetchContent. Lokale Kopie nutzen mit
#   -DFETCHCONTENT_SOURCE_DIR_JUCE=/pfad/zu/JUCE
include(FetchContent)
FetchContent_Declare(JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG        9.0.4
    GIT_SHALLOW    TRUE)
FetchContent_MakeAvailable(JUCE)

juce_add_plugin(CONTRA86
    COMPANY_NAME                "CONTRABEATZ"
    BUNDLE_ID                   "com.contrabeatz.contra86"
    PLUGIN_MANUFACTURER_CODE    Cntb
    PLUGIN_CODE                 Cb86
    PRODUCT_NAME                "CONTRA-86"
    FORMATS                     VST3 AU Standalone
    IS_SYNTH                    TRUE
    NEEDS_MIDI_INPUT            TRUE
    NEEDS_MIDI_OUTPUT           FALSE
    IS_MIDI_EFFECT              FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE
    VST3_CATEGORIES             Instrument Synth
    AU_MAIN_TYPE                kAudioUnitType_MusicDevice
    COPY_PLUGIN_AFTER_BUILD     TRUE)

juce_add_binary_data(CONTRA86_Assets SOURCES
    Resources/Fonts/Michroma-Regular.ttf
    Resources/Fonts/Doto-Black.ttf
    Resources/Fonts/Silkscreen-Regular.ttf)

set(CONTRA86_SOURCES
    Source/PluginProcessor.cpp
    Source/PluginEditor.cpp
    Source/Parameters.cpp
    Source/Presets.cpp
    Source/DSP/SynthEngine.cpp
    Source/UI/LookAndFeel.cpp
    Source/UI/Controls.cpp
    Source/UI/Display.cpp)

target_sources(CONTRA86 PRIVATE ${CONTRA86_SOURCES})

target_include_directories(CONTRA86 PRIVATE Source)

target_compile_definitions(CONTRA86 PUBLIC
    JUCE_WEB_BROWSER=0
    JUCE_USE_CURL=0
    JUCE_VST3_CAN_REPLACE_VST2=0)

target_link_libraries(CONTRA86
    PRIVATE
        CONTRA86_Assets
        juce::juce_audio_utils
        juce::juce_dsp
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags)

# Offline-Test: rendert alle Presets, prüft NaN/Pegel/Blockgrößen, schreibt WAVs;
# mit --ui <datei.png> zusätzlich ein Screenshot des Editors.
#   cmake -B build -DCONTRA86_TOOLS=ON && cmake --build build --target CONTRA86_Render
option(CONTRA86_TOOLS "Build offline render test" OFF)

if(CONTRA86_TOOLS)
    juce_add_console_app(CONTRA86_Render PRODUCT_NAME "CONTRA86_Render")

    target_sources(CONTRA86_Render PRIVATE Tools/RenderPresets.cpp ${CONTRA86_SOURCES})

    target_include_directories(CONTRA86_Render PRIVATE Source)

    target_compile_definitions(CONTRA86_Render PRIVATE
        JucePlugin_Name="CONTRA-86"
        JucePlugin_VersionString="${PROJECT_VERSION}"
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0)

    target_link_libraries(CONTRA86_Render
        PRIVATE
            CONTRA86_Assets
            juce::juce_audio_utils
            juce::juce_audio_formats
            juce::juce_dsp
        PUBLIC
            juce::juce_recommended_config_flags
            juce::juce_recommended_warning_flags)
endif()
