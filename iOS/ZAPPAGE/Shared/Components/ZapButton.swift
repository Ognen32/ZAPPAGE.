import SwiftUI

// MARK: - Primary button (orange CTA with arrow)
// Matches PrimaryButton in the design reference (auth.jsx).
struct PrimaryButton: View {
    let label: String
    var accent: Color = ZapTheme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(ZapTheme.archivoBlack(14))
                    .kerning(0.6)
                    .textCase(.uppercase)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: accent.opacity(0.33), radius: 8, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    .blendMode(.plusLighter)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Social button (translucent, icon + label)
// Matches SocialButton in the design reference (auth.jsx).
struct SocialButton: View {
    let icon: AnyView
    let label: String
    var tone: ZapTheme.Tone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tone.text)
                    .kerning(-0.1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(tone.socialBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tone.socialBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Apple & Google icon views
struct AppleSignInIcon: View {
    var color: Color = .primary
    var body: some View {
        Image(systemName: "apple.logo")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(color)
    }
}

struct GoogleSignInIcon: View {
    var body: some View {
        Canvas { ctx, _ in
            // Coloured G logo matching the design reference
            let blue  = Color(hex: "#4285F4")
            let green = Color(hex: "#34A853")
            let yellow = Color(hex: "#FBBC04")
            let red   = Color(hex: "#EA4335")

            // right arc (blue)
            var p = Path(); p.addArc(center: CGPoint(x:9,y:9), radius:9, startAngle:.degrees(-30), endAngle:.degrees(30), clockwise:false)
            p.addLine(to: CGPoint(x:9,y:9)); p.closeSubpath()
            ctx.fill(p, with: .color(blue))

            // bottom arc (green)
            var g = Path(); g.addArc(center: CGPoint(x:9,y:9), radius:9, startAngle:.degrees(30), endAngle:.degrees(150), clockwise:false)
            g.addLine(to: CGPoint(x:9,y:9)); g.closeSubpath()
            ctx.fill(g, with: .color(green))

            // left arc (yellow)
            var y = Path(); y.addArc(center: CGPoint(x:9,y:9), radius:9, startAngle:.degrees(150), endAngle:.degrees(210), clockwise:false)
            y.addLine(to: CGPoint(x:9,y:9)); y.closeSubpath()
            ctx.fill(y, with: .color(yellow))

            // top arc (red)
            var r = Path(); r.addArc(center: CGPoint(x:9,y:9), radius:9, startAngle:.degrees(210), endAngle:.degrees(330), clockwise:false)
            r.addLine(to: CGPoint(x:9,y:9)); r.closeSubpath()
            ctx.fill(r, with: .color(red))

            // white centre + horizontal bar
            ctx.fill(Path(ellipseIn: CGRect(x:3.5,y:3.5,width:11,height:11)), with: .color(.white))
            ctx.fill(Path(CGRect(x:9,y:7,width:6.5,height:4)), with: .color(blue))
        }
        .frame(width: 18, height: 18)
    }
}
