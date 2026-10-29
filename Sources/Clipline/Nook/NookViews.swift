import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Nook tab: media, calendar or shortcuts, and the mirror – NotchNook's widget row.
struct NookView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var player: NowPlaying
    @ObservedObject var calendar: CalendarFeed
    @ObservedObject var shortcuts: ShortcutsService
    @ObservedObject var mirror: CameraMirror

    var body: some View {
        Group {
            if model.isMini {
                HStack(spacing: 8) {
                    MediaWidget(player: player, compact: true)
                        .widgetCard()
                    CalendarWidget(calendar: calendar, compact: true)
                        .widgetCard()
                        .frame(width: 150) // after the card, so the card itself is this wide
                }
            } else {
                HStack(spacing: 10) {
                    MediaWidget(player: player, compact: false)
                        .widgetCard()
                    Group {
                        if model.nookSecondary == .calendar {
                            CalendarWidget(calendar: calendar, compact: false)
                        } else {
                            ShortcutsWidget(shortcuts: shortcuts)
                        }
                    }
                    .padding(.trailing, 44) // keep the header clear of the switch
                    .widgetCard()
                    .frame(width: 210)
                    .overlay(alignment: .topTrailing) { secondarySwitch.padding(8) }
                    MirrorWidget(mirror: mirror)
                        .widgetCard(padding: 0)
                        .frame(width: 150)
                }
            }
        }
        .onAppear {
            calendar.activate()
            shortcuts.loadIfNeeded()
        }
    }

    private var secondarySwitch: some View {
        HStack(spacing: 2) {
            switchButton(.calendar, symbol: "calendar")
            switchButton(.shortcuts, symbol: "square.stack.3d.up.fill")
        }
        .padding(2)
        .background(Capsule().fill(Color.black.opacity(0.35)))
    }

    private func switchButton(_ widget: NookSecondary, symbol: String) -> some View {
        Button { model.nookSecondary = widget } label: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(model.nookSecondary == widget ? Color.black : Color.white.opacity(0.7))
                .frame(width: 20, height: 18)
                .background(Capsule().fill(model.nookSecondary == widget ? Color.white : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func widgetCard(padding: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Media

struct MediaWidget: View {
    @ObservedObject var player: NowPlaying
    let compact: Bool

    var body: some View {
        if let track = player.track {
            HStack(spacing: compact ? 10 : 14) {
                artwork
                    .frame(width: compact ? 52 : 104, height: compact ? 52 : 104)
                    .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
                VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                    Text(track.title)
                        .font(.system(size: compact ? 12 : 14, weight: .semibold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: compact ? 11 : 12))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                    if !compact {
                        Spacer(minLength: 4)
                        progress(track)
                    }
                    controls
                        .padding(.top, compact ? 2 : 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "music.note")
                    .font(.system(size: compact ? 16 : 22, weight: .light))
                Text("Keine Wiedergabe")
                    .font(.system(size: 12, weight: .medium))
                if !compact {
                    Text("Musik oder Spotify starten")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = player.artwork {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Theme.control
                Image(systemName: "music.note")
                    .font(.system(size: compact ? 18 : 30, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func progress(_ track: NowPlaying.Track) -> some View {
        let fraction = track.duration > 0 ? min(1, player.position / track.duration) : 0
        return VStack(spacing: 3) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(.white.opacity(0.85))
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 4)
            HStack {
                Text(Self.time(player.position))
                Spacer()
                Text(Self.time(track.duration))
            }
            .font(.system(size: 9.5, weight: .medium).monospacedDigit())
            .foregroundStyle(Theme.secondaryText)
        }
    }

    private var controls: some View {
        HStack(spacing: compact ? 12 : 18) {
            controlButton("backward.fill", size: compact ? 11 : 14) { player.previous() }
            controlButton(player.isPlaying ? "pause.fill" : "play.fill", size: compact ? 14 : 20) { player.playPause() }
            controlButton("forward.fill", size: compact ? 11 : 14) { player.next() }
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(minWidth: size + 8, minHeight: size + 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func time(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Calendar

struct CalendarWidget: View {
    @ObservedObject var calendar: CalendarFeed
    let compact: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack(spacing: 4) {
                Button { calendar.shift(days: -1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain)
                Button { calendar.goToToday() } label: {
                    Text(PanelModel.dayTitle(calendar.day))
                        .font(.system(size: compact ? 11 : 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                Button { calendar.shift(days: 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))

            switch calendar.access {
            case .denied:
                Button("Kalenderzugriff erlauben") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.selection)
            case .unknown:
                Text("Kalender wird geladen …")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
            case .granted:
                if calendar.events.isEmpty {
                    Text("Keine Termine")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    ForEach(calendar.events.prefix(compact ? 2 : 3)) { event in
                        HStack(spacing: 7) {
                            Capsule()
                                .fill(Color(nsColor: event.color))
                                .frame(width: 3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.system(size: compact ? 11 : 12, weight: .medium))
                                    .lineLimit(1)
                                if !compact {
                                    Text(event.isAllDay ? "Ganztägig"
                                         : "\(Self.timeFormatter.string(from: event.start)) – \(Self.timeFormatter.string(from: event.end))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                        .frame(height: compact ? 16 : 30)
                    }
                }
            }
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsWidget: View {
    @ObservedObject var shortcuts: ShortcutsService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Kurzbefehle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            if shortcuts.all.isEmpty {
                Text("Keine Kurzbefehle gefunden")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(shortcuts.featured, id: \.self) { name in
                    Button { shortcuts.run(name) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.system(size: 8))
                            Text(name).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(Theme.control))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if shortcuts.all.count > shortcuts.featured.count {
                    Menu("Alle …") {
                        ForEach(shortcuts.all, id: \.self) { name in
                            Button(name) { shortcuts.run(name) }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .font(.system(size: 11))
                }
            }
        }
    }
}

// MARK: - Mirror

struct MirrorWidget: View {
    @ObservedObject var mirror: CameraMirror

    var body: some View {
        ZStack {
            if mirror.isRunning {
                CameraPreview(session: mirror.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topTrailing) {
                        RoundButton(symbol: "xmark", diameter: 22, help: "Spiegel aus") { mirror.stop() }
                            .padding(8)
                    }
            } else {
                Button {
                    if mirror.denied {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    } else {
                        mirror.start()
                    }
                } label: {
                    VStack(spacing: 6) {
                        if mirror.isRequestingAccess {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: mirror.denied ? "video.slash" : "person.crop.square")
                                .font(.system(size: 22, weight: .light))
                        }
                        Text(mirror.denied ? "Kamera nicht erlaubt"
                             : mirror.isRequestingAccess ? "Kamera freigeben …" : "Spiegel")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Tray

/// Files parked in the notch: drag in, drag out, AirDrop.
struct TrayView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var tray: TrayStore

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if tray.files.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: model.isMini ? 16 : 24, weight: .light))
                        Text("Dateien hierher ziehen")
                            .font(.system(size: 12, weight: .medium))
                        if !model.isMini {
                            Text("Sie bleiben hier, bis du sie wieder herausziehst")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(model.isDropTargeted ? 0.6 : 0.2),
                                          style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tray.files, id: \.self) { url in
                                TrayFileTile(url: url, compact: model.isMini, tray: tray)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TrayActions(model: model, tray: tray)
                .frame(width: model.isMini ? 214 : 302)
        }
    }
}

private struct TrayFileTile: View {
    let url: URL
    let compact: Bool
    let tray: TrayStore

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: compact ? 34 : 52, height: compact ? 34 : 52)
            Text(url.lastPathComponent)
                .font(.system(size: compact ? 9.5 : 11, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(8)
        .frame(width: compact ? 78 : 104, height: compact ? 78 : 130)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .help(url.path)
        .contextMenu {
            Button("Öffnen") { NSWorkspace.shared.open(url) }
            Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Per AirDrop senden") { tray.airDrop([url]) }
            Divider()
            Button("Aus Ablage entfernen") { tray.remove(url) }
            Button("Ablage leeren", role: .destructive) { tray.clear() }
        }
    }
}

/// Dropzone-style action grid: drop files onto a tile, or tap it to apply it to everything in the tray.
private struct TrayActions: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var tray: TrayStore

    struct Action: Identifiable {
        let id: String
        let title: String
        let symbol: String
        var icon: NSImage?
        let run: ([URL]) -> Void
    }

    private var actions: [Action] {
        var actions: [Action] = [
            Action(id: "airdrop", title: "AirDrop", symbol: "dot.radiowaves.up.forward") { tray.airDrop($0) },
            Action(id: "zip", title: "ZIP", symbol: "doc.zipper") { FileActions.zip($0) },
            Action(id: "claude", title: "Claude", symbol: "sparkle") { urls in model.onAskClaudeFiles?(urls) },
        ]
        guard !model.isMini else { return actions }
        actions += [
            Action(id: "resize", title: "Verkleinern", symbol: "arrow.down.right.and.arrow.up.left") { FileActions.resize($0) },
            Action(id: "jpg", title: "In JPG", symbol: "photo") { FileActions.convert($0, to: "jpeg") },
        ]
        for path in Prefs.trayFolders.prefix(2) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            actions.append(Action(id: "folder-\(path)", title: url.lastPathComponent, symbol: "folder",
                                  icon: NSWorkspace.shared.icon(forFile: path)) { FileActions.send($0, to: url) })
        }
        for path in Prefs.trayApps.prefix(1) {
            let url = URL(fileURLWithPath: path)
            actions.append(Action(id: "app-\(path)", title: url.deletingPathExtension().lastPathComponent, symbol: "app",
                                  icon: NSWorkspace.shared.icon(forFile: path)) { FileActions.open($0, withApplicationAt: url) })
        }
        return Array(actions.prefix(8))
    }

    var body: some View {
        let columns = model.isMini ? 3 : 4
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(actions) { action in
                ActionTile(action: action, compact: model.isMini, enabled: !tray.files.isEmpty) {
                    action.run(tray.files)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

private struct ActionTile: View {
    let action: TrayActions.Action
    let compact: Bool
    let enabled: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 5) {
                if let icon = action.icon {
                    Image(nsImage: icon).resizable().frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
                } else {
                    Image(systemName: action.symbol)
                        .font(.system(size: compact ? 15 : 17, weight: .medium))
                        .foregroundStyle(action.id == "airdrop" ? Theme.selection
                                         : action.id == "claude" ? Color(red: 0.85, green: 0.47, blue: 0.34)
                                         : Color.white.opacity(0.85))
                }
                Text(action.title)
                    .font(.system(size: compact ? 9.5 : 10.5, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 60 : 72)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.85)
        .help(enabled ? "\(action.title): auf alle Dateien in der Ablage anwenden – oder Dateien hierher ziehen"
                      : "Dateien hierher ziehen")
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            TrayStore.loadURLs(from: providers) { urls in action.run(urls) }
            return true
        }
    }
}
