import AppKit
import Combine
import SwiftUI

/// The closed notch, NotchNook-style: while music plays, a slim black band wraps the notch
/// with the artwork on the left and a moving equaliser on the right. Click opens the nook.
final class LiveActivityController {
    private let panel: NSPanel
    private var subscriptions = Set<AnyCancellable>()
    private let player = NowPlaying.shared
    private var listening = false
    var onClick: (() -> Void)?
    /// True while the shelf is open – the band steps aside.
    var isSuppressed = false { didSet { update() } }

    static let wing: CGFloat = 36

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        let host = NSHostingView(rootView: LiveActivityView(player: player, onTap: { [weak self] in self?.onClick?() }))
        host.sizingOptions = []
        panel.contentView = host

        player.$isPlaying
            .removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.update() } }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.update() }
            .store(in: &subscriptions)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled && !listening { player.start(); listening = true }
        if !enabled && listening { player.stop(); listening = false }
        update()
    }

    private func update() {
        guard listening, !isSuppressed, player.isPlaying, let frame = Self.frame() else {
            panel.orderOut(nil)
            return
        }
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    /// Only on screens with a notch: the band spans the notch plus a wing on each side.
    private static func frame() -> NSRect? {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        let height = screen.safeAreaInsets.top
        // The notch is whatever the two usable top corners leave over, centred on the screen.
        let notchWidth = screen.frame.width - left.width - right.width
        let minX = screen.frame.midX - notchWidth / 2
        return NSRect(x: minX - wing, y: screen.frame.maxY - height, width: notchWidth + 2 * wing, height: height)
    }
}

private struct LiveActivityView: View {
    @ObservedObject var player: NowPlaying
    let onTap: () -> Void

    private static let shape = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12,
                                                      bottomTrailingRadius: 12, topTrailingRadius: 0,
                                                      style: .continuous)

    var body: some View {
        HStack {
            Group {
                if let artwork = player.artwork {
                    Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 20, height: 20)
            .background(Theme.control)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            Spacer(minLength: 0)
            Equalizer(color: .white.opacity(0.85))
                .frame(width: 18, height: 14)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.shape.fill(Color.black))
        .contentShape(Self.shape)
        .onTapGesture(perform: onTap)
    }
}

/// Four bars bouncing on a sine wave – cheap, smooth and resolution-independent.
struct Equalizer: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        let phase = t * (2.6 + Double(index) * 0.7) + Double(index) * 1.3
                        let level = 0.3 + 0.7 * abs(sin(phase))
                        Capsule()
                            .fill(color)
                            .frame(height: max(3, geometry.size.height * level))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}
