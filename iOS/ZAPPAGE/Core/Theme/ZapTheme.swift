import SwiftUI

enum ZapTheme {
    // MARK: - Accent
    static let accent = Color(hex: "#FF6B1A")
    static let accentOptions: [Color] = [
        Color(hex: "#FF6B1A"),
        Color(hex: "#FFB400"),
        Color(hex: "#E63946"),
        Color(hex: "#3DD68C"),
        Color(hex: "#5E8BFF"),
    ]

    // MARK: - Tone
    struct Tone {
        let bg:           Color
        let card:         Color
        let line:         Color
        let text:         Color
        let textDim:      Color
        let textMuted:    Color
        let field:        Color
        let fieldFocus:   Color
        let chipBg:       Color
        let chipBorder:   Color
        let socialBg:     Color
        let socialBorder: Color
        let isDark:       Bool
    }

    static let dark = Tone(
        bg:           Color(hex: "#0A0A0B"),
        card:         Color(hex: "#141416"),
        line:         .white.opacity(0.08),
        text:         Color(hex: "#FAFAFA"),
        textDim:      .white.opacity(0.62),
        textMuted:    .white.opacity(0.42),
        field:        .white.opacity(0.05),
        fieldFocus:   .white.opacity(0.08),
        chipBg:       .white.opacity(0.06),
        chipBorder:   .white.opacity(0.08),
        socialBg:     .white.opacity(0.06),
        socialBorder: .white.opacity(0.08),
        isDark:       true
    )

    static let light = Tone(
        bg:           Color(hex: "#FBFAF7"),
        card:         .white,
        line:         .black.opacity(0.07),
        text:         Color(hex: "#0F0F11"),
        textDim:      Color(hex: "#0F0F11").opacity(0.62),
        textMuted:    Color(hex: "#0F0F11").opacity(0.42),
        field:        .black.opacity(0.03),
        fieldFocus:   .black.opacity(0.05),
        chipBg:       .black.opacity(0.04),
        chipBorder:   .black.opacity(0.06),
        socialBg:     .black.opacity(0.03),
        socialBorder: .black.opacity(0.08),
        isDark:       false
    )

    // MARK: - Typography
    static func archivoBlack(_ size: CGFloat) -> Font {
        .custom("ArchivoBlack-Regular", size: size)
    }

    // MARK: - Hero kinds
    enum HeroKind: String, CaseIterable {
        case zap, bolt, nyx, ember

        var displayName: String {
            switch self {
            case .zap:   return "ZAP"
            case .bolt:  return "BOLT"
            case .nyx:   return "NYX"
            case .ember: return "EMBER"
            }
        }

        var roleLabel: String {
            switch self {
            case .zap:   return "THE SPARK"
            case .bolt:  return "THE SWIFT"
            case .nyx:   return "THE SHADOW"
            case .ember: return "THE FLAME"
            }
        }

        var bgFrom: Color {
            switch self {
            case .zap:   return Color(hex: "#2a0f00")
            case .bolt:  return Color(hex: "#0a1a3a")
            case .nyx:   return Color(hex: "#1a0a3a")
            case .ember: return Color(hex: "#3a1400")
            }
        }

        var bgTo: Color {
            switch self {
            case .zap:   return Color(hex: "#0f0500")
            case .bolt:  return Color(hex: "#050a14")
            case .nyx:   return Color(hex: "#0a0518")
            case .ember: return Color(hex: "#150800")
            }
        }
    }
}

// MARK: - Environment key for tone
private struct ZapToneKey: EnvironmentKey {
    static let defaultValue: ZapTheme.Tone = ZapTheme.dark
}

extension EnvironmentValues {
    var zapTone: ZapTheme.Tone {
        get { self[ZapToneKey.self] }
        set { self[ZapToneKey.self] = newValue }
    }
}
