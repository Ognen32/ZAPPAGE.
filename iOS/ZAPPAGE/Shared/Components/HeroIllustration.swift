import SwiftUI

// Auth-screen hero card — gradient background, halftone dots, burst, speed lines, chibi hero.
// Faithfully translated from the HeroIllustration component in the design reference (auth.jsx).
struct HeroIllustration: View {
    var accent: Color = ZapTheme.accent
    var hero: ZapTheme.HeroKind = .zap
    var isDark: Bool = true

    private var bgFrom: Color { isDark ? Color(hex: "#1a1a1f") : Color(hex: "#FFF4E8") }
    private var bgTo:   Color { isDark ? Color(hex: "#0a0a0b") : Color(hex: "#FFE0C2") }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // base gradient
            LinearGradient(colors: [bgFrom, bgTo],
                           startPoint: .init(x: 0.1, y: 0.0),
                           endPoint: .init(x: 0.9, y: 1.0))

            // halftone dot overlay
            HalftoneDots(accent: accent, isDark: isDark)
                .blendMode(.overlay)

            // burst
            RadialGradient(colors: [accent.opacity(0.55), .clear],
                           center: .init(x: 1.15, y: -0.35),
                           startRadius: 0,
                           endRadius: 170)

            // speed lines
            SpeedLines(isDark: isDark)

            // chibi hero — drawn at full display size for crisp vector quality
            ChibiHero(kind: hero, accent: accent, size: 151)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -6)

            // POW! tag
            Text("POW!")
                .font(ZapTheme.archivoBlack(11))
                .kerning(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: .black.opacity(0.5), radius: 0, x: 2, y: 2)
                .rotationEffect(.degrees(-4))
                .padding(16)

            // ISSUE #001 tag — bottom-right
            Text("ISSUE #001")
                .font(ZapTheme.archivoBlack(10))
                .kerning(0.6)
                .foregroundStyle(isDark ? Color(hex: "#0f0f11") : Color(hex: "#FAFAFA"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isDark ? Color(hex: "#FAFAFA") : Color(hex: "#0f0f11"))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(isDark ? 0.4 : 0.08), radius: 12, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Halftone dot grid
private struct HalftoneDots: View {
    let accent: Color
    let isDark: Bool

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10
            let radius:  CGFloat = 0.7
            let cols = Int(size.width  / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for col in 0...cols {
                for row in 0...rows {
                    let rect = CGRect(
                        x: CGFloat(col) * spacing - radius,
                        y: CGFloat(row) * spacing - radius,
                        width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(accent.opacity(isDark ? 0.15 : 0.2)))
                }
            }
        }
    }
}

// MARK: - Speed lines
private struct SpeedLines: View {
    let isDark: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let sx = w  / 320.0
            let sy = h  / 200.0
            Canvas { context, _ in
                for i in 0..<6 {
                    let fi = CGFloat(i)
                    var line = Path()
                    line.move(to:    CGPoint(x: (20 + fi * 14) * sx, y: (170 + fi * 2) * sy))
                    line.addLine(to: CGPoint(x: (70 + fi * 16) * sx, y: (150 + fi * 2) * sy))
                    let opacity = 0.12 - fi * 0.012
                    context.stroke(
                        line,
                        with: .color((isDark ? Color.white : Color.black).opacity(opacity)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HeroIllustration(hero: .zap,   isDark: true)
        HeroIllustration(hero: .ember, isDark: false)
    }
    .padding()
    .background(Color(hex: "#0A0A0B"))
}
