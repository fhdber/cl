import SwiftUI

/// Supaste-style dark palette.
enum Theme {
    static let surface = Color.black
    static let control = Color(white: 0.16)
    static let card = Color(white: 0.11)
    static let hairline = Color.white.opacity(0.07)
    static let secondaryText = Color.white.opacity(0.5)
    static let selection = Color(red: 0.04, green: 0.52, blue: 1.0)

    /// Deep, slightly desaturated tones for custom categories (blue, red, green, amber, violet, teal).
    static let categoryPalette: [Color] = [
        Color(red: 0.11, green: 0.23, blue: 0.53),
        Color(red: 0.50, green: 0.12, blue: 0.18),
        Color(red: 0.12, green: 0.36, blue: 0.20),
        Color(red: 0.47, green: 0.29, blue: 0.07),
        Color(red: 0.30, green: 0.17, blue: 0.50),
        Color(red: 0.06, green: 0.33, blue: 0.38),
    ]

    static func categoryColor(_ index: Int?) -> Color {
        guard let index else { return control }
        return categoryPalette[index % categoryPalette.count]
    }
}
