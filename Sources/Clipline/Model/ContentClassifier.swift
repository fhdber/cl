import AppKit

/// Decides whether a copied string is a link, a colour, code or plain text.
enum ContentClassifier {
    static func classify(_ string: String) -> ClipKind {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if isColor(trimmed) { return .color }
        if isLink(trimmed) { return .link }
        if isCode(string) { return .code }
        return .text
    }

    static func isColor(_ s: String) -> Bool {
        s.range(of: #"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#,
                options: .regularExpression) != nil
            || s.range(of: #"^(rgb|rgba|hsl|hsla)\([^)]*\)$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isLink(_ s: String) -> Bool {
        guard !s.isEmpty, s.count < 4096, !s.contains(where: \.isWhitespace) else { return false }
        if let url = URL(string: s), let scheme = url.scheme?.lowercased() {
            if scheme == "mailto" { return true }
            if ["http", "https", "ftp"].contains(scheme) { return url.host != nil }
        }
        return s.range(of: #"^www\.[^\s]+\.[a-z]{2,}(/\S*)?$"#,
                       options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isCode(_ s: String) -> Bool {
        let signals = ["{", "}", ";", "=>", "->", "func ", "function ", "const ", "let ", "var ",
                       "def ", "import ", "return ", "</", "/>", "#include", "SELECT ", "console.", "print("]
        var score = signals.reduce(0) { s.contains($1) ? $0 + 1 : $0 }
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }.count
        if lines.count > 1 && indented * 3 >= lines.count { score += 2 }
        return lines.count == 1 ? score >= 4 : score >= 3
    }

    // MARK: - Colour parsing for swatches

    static func color(from raw: String) -> NSColor? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("#") { return hexColor(String(s.dropFirst())) }

        guard let open = s.firstIndex(of: "("), let close = s.lastIndex(of: ")") else { return nil }
        let fn = s[..<open]
        let values = s[s.index(after: open)..<close]
            .replacingOccurrences(of: "/", with: ",")
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .compactMap { Double($0.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "deg", with: "")) }
        guard values.count >= 3 else { return nil }
        let alpha = values.count > 3 ? (values[3] > 1 ? values[3] / 100 : values[3]) : 1

        if fn.hasPrefix("rgb") {
            return NSColor(srgbRed: values[0] / 255, green: values[1] / 255, blue: values[2] / 255, alpha: alpha)
        }
        // HSL → RGB
        let h = values[0].truncatingRemainder(dividingBy: 360), sat = values[1] / 100, l = values[2] / 100
        let c = (1 - abs(2 * l - 1)) * sat
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        var (r, g, b) = (0.0, 0.0, 0.0)
        switch h {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return NSColor(srgbRed: r + m, green: g + m, blue: b + m, alpha: alpha)
    }

    private static func hexColor(_ hex: String) -> NSColor? {
        var expanded = hex
        if hex.count == 3 || hex.count == 4 { expanded = hex.map { "\($0)\($0)" }.joined() }
        guard expanded.count == 6 || expanded.count == 8, let value = UInt64(expanded, radix: 16) else { return nil }
        let hasAlpha = expanded.count == 8
        let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(value & 0xFF) / 255 : 1
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
