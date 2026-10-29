import AppKit
import SwiftUI

/// Editor window: annotate a screenshot, add a backdrop, then copy, save or pin it.
final class AnnotationEditorController: NSObject, NSWindowDelegate {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var documents: [ObjectIdentifier: AnnotationDocument] = [:]
    var onPin: ((NSImage) -> Void)?

    func open(url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        open(image: image, name: url.deletingPathExtension().lastPathComponent)
    }

    func open(image: NSImage, name: String = "Bearbeitet") {
        guard let document = AnnotationDocument(image: image) else { return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 740),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = name
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 520)
        window.delegate = self

        let view = AnnotationEditorView(
            document: document,
            onCopy: { [weak self] in self?.copy(document) },
            onSave: { [weak self] in self?.save(document, name: name) },
            onPin: { [weak self] in self?.pin(document) },
            onDone: { [weak window] in window?.performClose(nil) }
        )
        window.contentView = NSHostingView(rootView: view)
        window.center()
        documents[ObjectIdentifier(window)] = document
        windows.append(window)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        documents[ObjectIdentifier(window)] = nil
        windows.removeAll { $0 === window }
    }

    private func copy(_ document: AnnotationDocument) {
        guard let data = document.exportPNG() else { return }
        CaptureService.writeImage(data)
        Toast.show("Kopiert", symbol: "doc.on.doc")
    }

    private func save(_ document: AnnotationDocument, name: String) {
        guard let data = document.exportPNG() else { return }
        let temp = CaptureService.folder.appendingPathComponent("\(name) bearbeitet.png")
        guard (try? data.write(to: temp)) != nil, let saved = CaptureService.save(temp) else { return }
        Toast.show("Gesichert: \(saved.deletingLastPathComponent().lastPathComponent)", symbol: "square.and.arrow.down")
    }

    private func pin(_ document: AnnotationDocument) {
        guard let data = document.exportPNG(), let image = NSImage(data: data) else { return }
        onPin?(image)
    }

    /// ⌘Z undo · ⌘C copy · ⌘S save while an editor is in front.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = NSApp.keyWindow,
                  let document = self.documents[ObjectIdentifier(window)],
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  !(window.firstResponder is NSTextView) else { return event }
            switch event.charactersIgnoringModifiers {
            case "z": document.undo(); return nil
            case "c": self.copy(document); return nil
            case "s": self.save(document, name: window.title); return nil
            default: return event
            }
        }
    }
}

struct AnnotationEditorView: View {
    @ObservedObject var document: AnnotationDocument
    let onCopy: () -> Void
    let onSave: () -> Void
    let onPin: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.leading, 78) // traffic lights
                .padding(.trailing, 14)
                .frame(height: 52)
            canvas
            backdropBar
                .padding(.horizontal, 14)
                .frame(height: 52)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(AnnotationTool.allCases) { tool in
                RoundButton(symbol: tool.symbol, isOn: document.tool == tool, diameter: 30, help: tool.title) {
                    document.tool = tool
                }
            }
            if document.tool == .text {
                FocusableTextField(text: Binding(get: { document.pendingText }, set: { document.pendingText = $0 }),
                                   placeholder: "Text", fontSize: 13, focusToken: 0)
                    .padding(.horizontal, 10)
                    .frame(width: 150, height: 30)
                    .background(Capsule().fill(Theme.control))
            }
            Rectangle().fill(Theme.hairline).frame(width: 1, height: 22).padding(.horizontal, 4)
            ForEach(Array(AnnotationDocument.palette.enumerated()), id: \.offset) { _, color in
                Button { document.color = color } label: {
                    Circle()
                        .fill(Color(nsColor: color))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(.white.opacity(document.color == color ? 0.95 : 0.2),
                                                       lineWidth: document.color == color ? 2 : 1))
                        .padding(3)
                }
                .buttonStyle(.plain)
            }
            Menu {
                Button("Fein") { document.width = max(2, baseWidth * 0.6) }
                Button("Normal") { document.width = baseWidth }
                Button("Kräftig") { document.width = baseWidth * 1.7 }
            } label: {
                RoundIcon(symbol: "lineweight", diameter: 30)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Strichstärke")
            Spacer()
            Group {
                RoundButton(symbol: "arrow.uturn.backward", diameter: 30, help: "Widerrufen (⌘Z)") { document.undo() }
                actionButton("Kopieren", symbol: "doc.on.doc", primary: false, action: onCopy)
                actionButton("Sichern", symbol: "square.and.arrow.down", primary: false, action: onSave)
                actionButton("Anheften", symbol: "pin", primary: false, action: onPin)
                actionButton("Fertig", symbol: "checkmark", primary: true, action: onDone)
            }
        }
    }

    private var baseWidth: CGFloat {
        max(4, round(min(document.size.width, document.size.height) / 160))
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geometry in
            let canvasSize = document.canvasSize
            let available = CGSize(width: max(1, geometry.size.width - 48), height: max(1, geometry.size.height - 48))
            let fit = min(available.width / canvasSize.width, available.height / canvasSize.height, 1.5)
            let shown = CGSize(width: canvasSize.width * fit, height: canvasSize.height * fit)
            let pad = document.canvasPadding

            Image(nsImage: document.preview)
                .resizable()
                .interpolation(.high)
                .frame(width: shown.width, height: shown.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            document.dragChanged(from: Self.imagePoint(value.startLocation, fit: fit, pad: pad),
                                                 to: Self.imagePoint(value.location, fit: fit, pad: pad))
                        }
                        .onEnded { value in
                            document.dragEnded(from: Self.imagePoint(value.startLocation, fit: fit, pad: pad),
                                               to: Self.imagePoint(value.location, fit: fit, pad: pad))
                        }
                )
                .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .background(Color(white: 0.09))
    }

    /// View point → image pixel (top-left origin), accounting for the backdrop padding.
    private static func imagePoint(_ point: CGPoint, fit: CGFloat, pad: CGFloat) -> CGPoint {
        CGPoint(x: point.x / fit - pad, y: point.y / fit - pad)
    }

    // MARK: - Backdrop

    private var backdropBar: some View {
        HStack(spacing: 10) {
            Toggle("Hintergrund", isOn: Binding(get: { document.backdrop }, set: { document.backdrop = $0 }))
                .toggleStyle(.switch)
                .font(.system(size: 12, weight: .medium))
                .fixedSize()
            if document.backdrop {
                ForEach(BackdropStyle.all) { style in
                    Button { document.backdropStyle = style.id } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color(nsColor: style.from), Color(nsColor: style.to)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 26, height: 26)
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.white.opacity(document.backdropStyle == style.id ? 0.95 : 0.15),
                                              lineWidth: document.backdropStyle == style.id ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(style.name)
                }
                Text("Rand")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
                Slider(value: Binding(get: { Double(document.padding) }, set: { document.padding = CGFloat($0) }),
                       in: 0.03...0.2)
                    .frame(width: 140)
            }
            Spacer()
            if !document.annotations.isEmpty {
                Button("Alles entfernen") { document.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(primary ? Color.black : Color.white)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(Capsule().fill(primary ? Color.white : Theme.control))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
