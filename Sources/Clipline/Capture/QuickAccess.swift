import AppKit
import Combine
import SwiftUI

/// After a capture: a card in the bottom-left corner (like CleanShot's Quick Access Overlay)
/// with copy, save, edit, pin, OCR and Claude. Drag it straight into another app.
final class QuickAccessController {
    final class Item: ObservableObject, Identifiable {
        let id = UUID()
        let url: URL
        let image: NSImage?
        @Published var isHovered = false

        init(url: URL) {
            self.url = url
            image = NSImage(contentsOf: url)
        }
    }

    private struct Entry {
        let item: Item
        let panel: NSPanel
        var hoverSubscription: AnyCancellable?
    }

    private var entries: [Entry] = []
    private var dismissWork: [UUID: DispatchWorkItem] = [:]
    private let cardSize = CGSize(width: 240, height: 158)

    var onEdit: ((URL) -> Void)?
    var onPin: ((URL) -> Void)?
    var onClaude: ((URL) -> Void)?
    var onRecognizeText: ((URL) -> Void)?
    var onCopy: ((URL) -> Void)?

    func show(_ url: URL) {
        guard Prefs.captureQuickAccess else { return }
        let item = Item(url: url)
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: cardSize),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = QuickAccessCard(item: item, actions: QuickAccessCard.Actions(
            copy: { [weak self] in self?.onCopy?(url); self?.dismiss(item.id) },
            save: { [weak self] in
                if let saved = CaptureService.save(url) {
                    Toast.show("Gesichert: \(saved.deletingLastPathComponent().lastPathComponent)", symbol: "square.and.arrow.down")
                }
                self?.dismiss(item.id)
            },
            edit: { [weak self] in self?.onEdit?(url); self?.dismiss(item.id) },
            pin: { [weak self] in self?.onPin?(url); self?.dismiss(item.id) },
            text: { [weak self] in self?.onRecognizeText?(url); self?.dismiss(item.id) },
            claude: { [weak self] in self?.onClaude?(url); self?.dismiss(item.id) },
            close: { [weak self] in self?.dismiss(item.id) }
        ))
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host

        var entry = Entry(item: item, panel: panel)
        entry.hoverSubscription = item.$isHovered.sink { [weak self] hovered in
            if hovered { self?.dismissWork[item.id]?.cancel() } else { self?.scheduleDismiss(item.id) }
        }
        entries.insert(entry, at: 0)
        layout(animated: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 1
        }
        layout(animated: true)
        scheduleDismiss(item.id)
    }

    private func scheduleDismiss(_ id: UUID) {
        dismissWork[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss(id) }
        dismissWork[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func dismiss(_ id: UUID) {
        dismissWork[id]?.cancel()
        dismissWork[id] = nil
        guard let index = entries.firstIndex(where: { $0.item.id == id }) else { return }
        let panel = entries[index].panel
        entries.remove(at: index)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
        layout(animated: true)
    }

    /// Newest card at the bottom, older ones stacked above.
    private func layout(animated: Bool) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        for (index, entry) in entries.enumerated() {
            let frame = NSRect(x: visible.minX + 20,
                               y: visible.minY + 20 + CGFloat(index) * (cardSize.height + 12),
                               width: cardSize.width, height: cardSize.height)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.2
                    entry.panel.animator().setFrame(frame, display: true)
                }
            } else {
                entry.panel.setFrame(frame, display: true)
            }
        }
    }
}

private struct QuickAccessCard: View {
    struct Actions {
        let copy: () -> Void
        let save: () -> Void
        let edit: () -> Void
        let pin: () -> Void
        let text: () -> Void
        let claude: () -> Void
        let close: () -> Void
    }

    @ObservedObject var item: QuickAccessController.Item
    let actions: Actions

    private static let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        ZStack {
            Color(white: 0.1)
            if let image = item.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            }
            if item.isHovered {
                Color.black.opacity(0.5)
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        iconButton("doc.on.doc", help: "Kopieren", action: actions.copy)
                        iconButton("square.and.arrow.down", help: "Sichern", action: actions.save)
                        Spacer()
                        iconButton("xmark", help: "Schließen", action: actions.close)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        pill("Bearbeiten", symbol: "pencil.tip", action: actions.edit)
                        pill("Anheften", symbol: "pin", action: actions.pin)
                    }
                    HStack(spacing: 6) {
                        iconButton("text.viewfinder", help: "Text erkennen und kopieren", action: actions.text)
                        iconButton("sparkle", help: "Claude fragen", action: actions.claude)
                    }
                }
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Self.shape)
        .overlay(Self.shape.strokeBorder(.white.opacity(0.15)))
        .contentShape(Self.shape)
        .onHover { item.isHovered = $0 }
        .onTapGesture(count: 2, perform: actions.edit)
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .environment(\.colorScheme, .dark)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.black.opacity(0.6)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func pill(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(Color.white))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
