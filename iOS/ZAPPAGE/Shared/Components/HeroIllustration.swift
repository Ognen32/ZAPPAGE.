import SwiftUI

struct HeroIllustration: View {
    var accent: Color = ZapTheme.accent
    var hero: ZapTheme.HeroKind = .zap
    var isDark: Bool = true

    private var bgFrom: Color { isDark ? Color(hex: "#1a1a1f") : Color(hex: "#FFF4E8") }
    private var bgTo:   Color { isDark ? Color(hex: "#0a0a0b") : Color(hex: "#FFE0C2") }

    private var sideHeroes: [ZapTheme.HeroKind] {
        ZapTheme.HeroKind.allCases.filter { $0 != hero }
    }

    // @State drives hero motion — pure GPU compositing, no Canvas redraws
    @State private var leftY:    CGFloat = 0
    @State private var rightY:   CGFloat = 0
    @State private var powScale: CGFloat = 1.0
    @State private var powRot:   Double  = -4

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Static background ────────────────────────────────────────
            LinearGradient(colors: [bgFrom, bgTo],
                           startPoint: .init(x: 0.1, y: 0.0),
                           endPoint:   .init(x: 0.9, y: 1.0))

            HalftoneDots(accent: accent, isDark: isDark)
                .blendMode(.overlay)

            RadialGradient(colors: [accent.opacity(0.55), .clear],
                           center: .init(x: 1.15, y: -0.35),
                           startRadius: 0, endRadius: 170)

            // ── Canvas-only TimelineView (comics + speed lines) ──────────
            // Scoped here so ChibiHero is never asked to redraw every frame.
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    Canvas { ctx, size in drawSpeedLines(ctx, size, t) }
                    Canvas { ctx, size in drawComics(ctx, size, t) }
                }
            }

            // ── Left side hero ───────────────────────────────────────────
            ChibiHero(kind: sideHeroes[0], accent: accent, size: 48)
                .drawingGroup()
                .opacity(0.70)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(y: leftY + 8)

            // ── Right side hero ──────────────────────────────────────────
            ChibiHero(kind: sideHeroes[2], accent: accent, size: 42)
                .drawingGroup()
                .opacity(0.60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .offset(y: rightY + 8)

            // ── Main hero — static center ────────────────────────────────
            ChibiHero(kind: hero, accent: accent, size: 151)
                .drawingGroup()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: -6)

            // ── POW! tag — pulsing ───────────────────────────────────────
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
                .rotationEffect(.degrees(powRot))
                .scaleEffect(powScale)
                .padding(16)

            // ── ISSUE #001 tag ───────────────────────────────────────────
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
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true).delay(0.25)) {
            leftY = 6
        }
        withAnimation(.easeInOut(duration: 1.30).repeatForever(autoreverses: true).delay(0.55)) {
            rightY = 5
        }
        withAnimation(.easeInOut(duration: 0.48).repeatForever(autoreverses: true)) {
            powScale = 1.09
        }
        withAnimation(.easeInOut(duration: 0.60).repeatForever(autoreverses: true).delay(0.1)) {
            powRot = -6
        }
    }

    // MARK: - Animated speed lines
    private func drawSpeedLines(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        let lc = isDark ? Color.white : Color.black
        let sx = size.width / 320, sy = size.height / 200
        for i in 0..<7 {
            let fi = CGFloat(i)
            let shift = CGFloat(t * 14).truncatingRemainder(dividingBy: size.width * 0.55)
            let ox = (fi * 13 + shift).truncatingRemainder(dividingBy: size.width * 0.6)
            var line = Path()
            line.move(to:    CGPoint(x: ox * sx,        y: (172 + fi * 2.5) * sy))
            line.addLine(to: CGPoint(x: (ox+52) * sx,   y: (150 + fi * 2.5) * sy))
            ctx.stroke(line, with: .color(lc.opacity(max(0, 0.18 - Double(fi) * 0.018))),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    // MARK: - Floating comic books
    private func drawComics(_ ctx: GraphicsContext, _ size: CGSize, _ t: Double) {
        struct Comic {
            let bx, by, speed, phase: Double
            let w, h: CGFloat
            let color: Color
            let isOpen: Bool
        }
        let books: [Comic] = [
            Comic(bx: 0.04, by: 0.26, speed: 0.28, phase: 0.00, w: 22, h: 30, color: Color(hex: "#FF6B1A"), isOpen: false),
            Comic(bx: 0.92, by: 0.50, speed: 0.24, phase: 1.40, w: 20, h: 27, color: Color(hex: "#FFD84D"), isOpen: false),
            Comic(bx: 0.10, by: 0.72, speed: 0.32, phase: 2.30, w: 46, h: 20, color: Color(hex: "#5E8BFF"), isOpen: true),
            Comic(bx: 0.84, by: 0.15, speed: 0.26, phase: 0.80, w: 18, h: 24, color: Color(hex: "#3DD68C"), isOpen: false),
        ]
        for book in books {
            let x   = CGFloat(book.bx * size.width  + sin(t * book.speed + book.phase) * 8)
            let y   = CGFloat(book.by * size.height + cos(t * book.speed * 0.88 + book.phase) * 6)
            let rot = CGFloat(sin(t * 0.30 + book.phase) * 0.22)
            let alpha = 0.68 + 0.16 * sin(t * 0.42 + book.phase)
            let baseT = CGAffineTransform(translationX: x, y: y).rotated(by: rot)

            if book.isOpen {
                let pw = book.w * 0.5, ph = book.h
                let openAng = CGFloat(sin(t * 0.20 + book.phase) * 0.10 + 0.06)
                let leftT  = CGAffineTransform(translationX: x, y: y).rotated(by: rot - openAng)
                let rightT = CGAffineTransform(translationX: x, y: y).rotated(by: rot + openAng)

                ctx.fill(Path(roundedRect: CGRect(x: -pw, y: -ph/2, width: pw, height: ph), cornerRadius: 2).applying(leftT),
                         with: .color(book.color.opacity(alpha * 0.90)))
                ctx.fill(Path(roundedRect: CGRect(x: 0,  y: -ph/2, width: pw, height: ph), cornerRadius: 2).applying(rightT),
                         with: .color(book.color.opacity(alpha * 0.75)))

                for li in 0..<3 {
                    let ly = -ph/2 + 3 + CGFloat(li) * (ph / 4.2)
                    var lr = Path()
                    lr.move(to: CGPoint(x: 2, y: ly)); lr.addLine(to: CGPoint(x: pw-2, y: ly))
                    ctx.stroke(lr.applying(rightT), with: .color(.white.opacity(0.32)),
                               style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
                }
                var spine = Path()
                spine.move(to: CGPoint(x: 0, y: -ph/2)); spine.addLine(to: CGPoint(x: 0, y: ph/2))
                ctx.stroke(spine.applying(baseT), with: .color(.white.opacity(0.38)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            } else {
                let cw = book.w, ch = book.h
                ctx.fill(Path(roundedRect: CGRect(x: -cw/2, y: -ch/2, width: cw, height: ch), cornerRadius: 3).applying(baseT),
                         with: .color(book.color.opacity(alpha)))
                ctx.fill(Path(roundedRect: CGRect(x: -cw/2+2, y: -ch/2+3, width: cw-4, height: 4), cornerRadius: 1).applying(baseT),
                         with: .color(.white.opacity(0.45)))
                for li in 0..<2 {
                    let ly = -ch/2 + 11 + CGFloat(li) * 5
                    let lw = (cw-5) * (li == 0 ? 1.0 : 0.62)
                    ctx.fill(Path(roundedRect: CGRect(x: -cw/2+2, y: ly, width: lw, height: 2), cornerRadius: 1).applying(baseT),
                             with: .color(.white.opacity(0.26)))
                }
                ctx.fill(Path(roundedRect: CGRect(x: -cw/2, y: ch/2-4, width: cw, height: 3), cornerRadius: 0).applying(baseT),
                         with: .color(.black.opacity(0.28)))
            }
        }
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
                    let rect = CGRect(x: CGFloat(col)*spacing - radius,
                                     y: CGFloat(row)*spacing - radius,
                                     width: radius*2, height: radius*2)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(accent.opacity(isDark ? 0.15 : 0.2)))
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
