import AppKit
import Combine
import SwiftUI

/// While dictating: a black band under the notch with a live waveform and the words so far.
final class DictationHUD {
    private let panel: NSPanel
    private var subscription: AnyCancellable?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = NSHostingView(rootView: DictationHUDView(dictation: .shared))
        host.sizingOptions = []
        panel.contentView = host

        subscription = Dictation.shared.$state
            .removeDuplicates()
            .sink { [weak self] state in DispatchQueue.main.async { self?.update(state) } }
    }

    private func update(_ state: Dictation.State) {
        guard state != .idle else {
            panel.orderOut(nil)
            return
        }
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        guard let screen else { return }
        let size = CGSize(width: 340, height: max(screen.safeAreaInsets.top, 24) + 44)
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                              width: size.width, height: size.height), display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}

private struct DictationHUDView: View {
    @ObservedObject var dictation: Dictation

    private static let shape = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 22,
                                                      bottomTrailingRadius: 22, topTrailingRadius: 0,
                                                      style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                Image(systemName: dictation.state == .polishing ? "sparkle" : "mic.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(dictation.state == .polishing
                                     ? Color(red: 0.85, green: 0.47, blue: 0.34) : Color.red)
                if dictation.state == .polishing {
                    Text("Wird bereinigt …")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Waveform(levels: dictation.levels)
                        .frame(width: 70, height: 18)
                    Text(dictation.transcript.isEmpty ? "Sprich jetzt …" : dictation.transcript)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(dictation.transcript.isEmpty ? 0.5 : 0.9))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.shape.fill(Color.black))
        .environment(\.colorScheme, .dark)
    }
}

private struct Waveform: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 1.5) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(height: max(2, geometry.size.height * level))
                }
            }
            .frame(maxHeight: .infinity)
            .animation(.linear(duration: 0.08), value: levels)
        }
    }
}
