import AppKit
import SwiftUI

struct ClaudeView: View {
    @ObservedObject var session: ClaudeSession
    let onClose: () -> Void
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onSaveClip: () -> Void
    let onOpenSettings: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    private static let accent = Color(red: 0.85, green: 0.47, blue: 0.34) // Claude's terracotta

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if ClaudeClient.shared.hasKey {
                contextCard
                actionRow
                promptRow
                Rectangle().fill(Theme.hairline).frame(height: 1)
                responseArea
                footer
            } else {
                missingKey
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Self.shape.fill(Color(white: 0.06)))
        .overlay(Self.shape.strokeBorder(.white.opacity(0.1)))
        .clipShape(Self.shape)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Parts

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.accent)
            Text("Claude")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Menu {
                ForEach(ClaudeModel.allCases) { model in
                    Button(model.title) {
                        UserDefaults.standard.set(model.rawValue, forKey: Prefs.Key.claudeModel)
                        session.objectWillChange.send()
                    }
                }
            } label: {
                Text(ClaudeModel.preferred.shortTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(Theme.control))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            RoundButton(symbol: "xmark", diameter: 24, help: "Schließen (Esc)", action: onClose)
        }
    }

    @ViewBuilder
    private var contextCard: some View {
        HStack(spacing: 10) {
            switch session.context {
            case .text(let text, let source):
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Theme.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.map { "Aus \($0)" } ?? "Kontext")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 12))
                        .lineLimit(2)
                }
            case .image(let data, let title):
                if let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bild")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Text(title ?? "Bild aus der Zwischenablage")
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
            case nil:
                Image(systemName: "bubble.left")
                    .foregroundStyle(Theme.secondaryText)
                Text("Kein Kontext – frag einfach los, oder markier vorher Text in einer App.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
            if session.context != nil {
                RoundButton(symbol: "xmark", diameter: 20, help: "Kontext entfernen") { session.context = nil }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
    }

    private var actionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(session.actions) { action in
                    Button { session.run(action) } label: {
                        Label(action.title, systemImage: action.symbol)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 11)
                            .frame(height: 28)
                            .background(Capsule().fill(Theme.control))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(session.context == nil)
                    .opacity(session.context == nil ? 0.4 : 1)
                }
            }
        }
    }

    private var promptRow: some View {
        HStack(spacing: 8) {
            FocusableTextField(text: Binding(get: { session.prompt }, set: { session.prompt = $0 }),
                               placeholder: session.context == nil ? "Frag Claude …" : "Was soll Claude damit machen?",
                               fontSize: 14,
                               focusToken: session.focusToken,
                               onSubmit: { session.submit() })
                .frame(height: 30)
            if session.isRunning {
                RoundButton(symbol: "stop.fill", diameter: 28, help: "Stoppen") { session.cancel() }
            } else {
                Button { session.submit() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(session.prompt.isEmpty ? Color.white.opacity(0.3) : Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
    }

    private var responseArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let task = session.lastTask {
                    Text(task)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
                if let error = session.error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                } else if session.response.isEmpty && session.isRunning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Claude denkt nach …")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else if session.response.isEmpty {
                    Text("Wähl eine Aktion oder schreib eine Frage.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    Text(session.response)
                        .font(.system(size: 14))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(ClaudeModel.preferred.title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            footerButton("Kopieren", symbol: "doc.on.doc", primary: false, action: onCopy)
            footerButton("Als Clip", symbol: "tray.and.arrow.down", primary: false, action: onSaveClip)
            footerButton("Einfügen", symbol: "return", primary: true, action: onPaste)
        }
        .disabled(session.response.isEmpty || session.isRunning)
        .opacity(session.response.isEmpty || session.isRunning ? 0.45 : 1)
    }

    private func footerButton(_ title: String, symbol: String, primary: Bool, action: @escaping () -> Void) -> some View {
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

    private var missingKey: some View {
        VStack(spacing: 12) {
            Image(systemName: "key")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Self.accent)
            Text("Verbinde Clipline mit Claude")
                .font(.system(size: 15, weight: .semibold))
            Text("Trag deinen Anthropic-API-Schlüssel in den Einstellungen ein. Er wird im Schlüsselbund gespeichert.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            footerButton("Einstellungen öffnen", symbol: "gearshape", primary: true, action: onOpenSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
