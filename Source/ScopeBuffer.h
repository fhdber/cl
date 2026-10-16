#pragma once

#include <array>
#include <atomic>

// Lock-freier Ringpuffer: Audio-Thread schreibt, UI liest eine Momentaufnahme.
// Einzelne Samples können beim Lesen schon überschrieben sein – fürs
// Oszilloskop egal, dafür ohne Locks.
class ScopeBuffer
{
public:
    static constexpr int size = 4096;

    void push (const float* left, const float* right, int numSamples) noexcept
    {
        auto w = writePos.load (std::memory_order_relaxed);
        for (int i = 0; i < numSamples; ++i, ++w)
            data[static_cast<size_t> (w & (size - 1))].store (right != nullptr ? 0.5f * (left[i] + right[i]) : left[i],
                                                              std::memory_order_relaxed);
        writePos.store (w, std::memory_order_release);
    }

    // Kopiert die letzten numSamples (<= size) nach dest, älteste zuerst.
    void snapshot (float* dest, int numSamples) const noexcept
    {
        const auto w = writePos.load (std::memory_order_acquire);
        for (int i = 0; i < numSamples; ++i)
            dest[i] = data[static_cast<size_t> ((w - numSamples + i) & (size - 1))].load (std::memory_order_relaxed);
    }

private:
    std::array<std::atomic<float>, size> data {};
    std::atomic<int> writePos { 0 };
};
