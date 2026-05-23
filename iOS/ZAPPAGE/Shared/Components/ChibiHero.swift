import SwiftUI

// Original chibi heroes drawn with SwiftUI Canvas paths.
// Faithfully translated from the UI/UX design reference (home.jsx).
struct ChibiHero: View {
    var kind: ZapTheme.HeroKind = .zap
    var accent: Color = ZapTheme.accent
    var inverted: Bool = false
    var size: CGFloat = 36

    var body: some View {
        Canvas { ctx, canvasSize in
            let s = canvasSize.width / 36.0
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }

            let skin     = Color(hex: "#F4C9A0")
            let skinShade = Color(hex: "#D9A77F")
            let dark1    = Color(hex: "#1a1a1a")
            let dark0    = Color(hex: "#0f0f11")

            switch kind {
            case .zap:
                // cape
                var cape = Path(); cape.move(to: pt(6,26)); cape.addLine(to: pt(18,22))
                cape.addLine(to: pt(30,26)); cape.addLine(to: pt(28,34)); cape.addLine(to: pt(8,34))
                cape.closeSubpath()
                ctx.fill(cape, with: .color(inverted ? dark1 : Color(hex: "#7a1414")))

                // body
                ctx.fill(Path(roundedRect: CGRect(x:10*s, y:22*s, width:16*s, height:10*s), cornerRadius:3*s),
                         with: .color(inverted ? dark1 : dark0))

                // head
                ctx.fill(Path(ellipseIn: CGRect(x:9*s, y:5*s, width:18*s, height:18*s)),
                         with: .color(inverted ? Color(hex:"#222") : skin))

                // hair
                var hair = Path()
                hair.move(to: pt(10,11)); hair.addQuadCurve(to: pt(18,8), control: pt(14,7))
                hair.addQuadCurve(to: pt(26,11), control: pt(22,7)); hair.addLine(to: pt(25,14))
                hair.addQuadCurve(to: pt(18,11), control: pt(22,11))
                hair.addQuadCurve(to: pt(11,14), control: pt(14,11)); hair.closeSubpath()
                ctx.fill(hair, with: .color(inverted ? dark0 : Color(hex:"#2a1a0a")))

                // mask
                ctx.fill(Path(roundedRect: CGRect(x:10*s, y:13*s, width:16*s, height:4.5*s), cornerRadius:s),
                         with: .color(inverted ? accent : dark0))

                // eyes
                ctx.fill(Path(ellipseIn: CGRect(x:12.9*s, y:14.2*s, width:3.2*s, height:2*s)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x:19.9*s, y:14.2*s, width:3.2*s, height:2*s)), with: .color(.white))

                // mouth
                var mouth = Path(); mouth.move(to: pt(16,19)); mouth.addQuadCurve(to: pt(20,19), control: pt(18,20.5))
                ctx.stroke(mouth, with: .color(inverted ? Color(hex:"#888") : skinShade),
                           style: StrokeStyle(lineWidth:0.8*s, lineCap:.round))

                // Z-bolt chest emblem
                var bolt = Path(); bolt.move(to: pt(14,25)); bolt.addLine(to: pt(20,25))
                bolt.addLine(to: pt(16,28)); bolt.addLine(to: pt(22,28))
                ctx.stroke(bolt, with: .color(inverted ? accent : Color(hex:"#FFD84D")),
                           style: StrokeStyle(lineWidth:1.4*s, lineCap:.round, lineJoin:.round))

            case .bolt:
                // cape
                var cape = Path(); cape.move(to: pt(6,26)); cape.addLine(to: pt(18,22))
                cape.addLine(to: pt(30,26)); cape.addLine(to: pt(28,34)); cape.addLine(to: pt(8,34))
                cape.closeSubpath()
                ctx.fill(cape, with: .color(inverted ? dark1 : Color(hex:"#0a3a8a")))

                ctx.fill(Path(roundedRect: CGRect(x:10*s, y:22*s, width:16*s, height:10*s), cornerRadius:3*s),
                         with: .color(inverted ? dark1 : Color(hex:"#FFD84D")))

                ctx.fill(Path(ellipseIn: CGRect(x:9*s, y:5*s, width:18*s, height:18*s)),
                         with: .color(inverted ? Color(hex:"#222") : skin))

                // yellow hair
                var hair = Path()
                hair.move(to: pt(10,12)); hair.addQuadCurve(to: pt(18,8), control: pt(14,7))
                hair.addQuadCurve(to: pt(26,12), control: pt(23,7)); hair.addLine(to: pt(25,15))
                hair.addQuadCurve(to: pt(18,11), control: pt(22,11))
                hair.addQuadCurve(to: pt(11,15), control: pt(14,11)); hair.closeSubpath()
                ctx.fill(hair, with: .color(inverted ? dark0 : Color(hex:"#FFD84D")))

                // mask
                var mask = Path(); mask.move(to: pt(9,13)); mask.addQuadCurve(to: pt(27,13), control: pt(18,11))
                mask.addLine(to: pt(26,17)); mask.addQuadCurve(to: pt(10,17), control: pt(18,16))
                mask.closeSubpath()
                ctx.fill(mask, with: .color(inverted ? accent : Color(hex:"#FFD84D")))

                // pupils
                ctx.fill(Path(ellipseIn: CGRect(x:13.4*s, y:13.9*s, width:2.2*s, height:2.2*s)),
                         with: .color(Color(hex:"#0a3a8a")))
                ctx.fill(Path(ellipseIn: CGRect(x:20.4*s, y:13.9*s, width:2.2*s, height:2.2*s)),
                         with: .color(Color(hex:"#0a3a8a")))

                var mouth = Path(); mouth.move(to: pt(16,19.5)); mouth.addQuadCurve(to: pt(20,19.5), control: pt(18,21))
                ctx.stroke(mouth, with: .color(skinShade), style: StrokeStyle(lineWidth:0.8*s, lineCap:.round))

                // lightning emblem
                var lbolt = Path(); lbolt.move(to: pt(17,24)); lbolt.addLine(to: pt(19,27))
                lbolt.addLine(to: pt(17.5,27)); lbolt.addLine(to: pt(19,30))
                ctx.stroke(lbolt, with: .color(inverted ? accent : Color(hex:"#0a3a8a")),
                           style: StrokeStyle(lineWidth:1.4*s, lineCap:.round, lineJoin:.round))

            case .nyx:
                var cape = Path(); cape.move(to: pt(6,26)); cape.addLine(to: pt(18,22))
                cape.addLine(to: pt(30,26)); cape.addLine(to: pt(28,34)); cape.addLine(to: pt(8,34))
                cape.closeSubpath()
                ctx.fill(cape, with: .color(inverted ? dark1 : Color(hex:"#2a0a3a")))

                ctx.fill(Path(roundedRect: CGRect(x:10*s, y:22*s, width:16*s, height:10*s), cornerRadius:3*s),
                         with: .color(inverted ? dark1 : Color(hex:"#1a0a2a")))

                // full cowl head
                var cowl = Path(); cowl.move(to: pt(9,13))
                cowl.addQuadCurve(to: pt(18,5), control: pt(9,5))
                cowl.addQuadCurve(to: pt(27,13), control: pt(27,5))
                cowl.addLine(to: pt(27,18))
                cowl.addQuadCurve(to: pt(18,22), control: pt(27,22))
                cowl.addQuadCurve(to: pt(9,18), control: pt(9,22))
                cowl.closeSubpath()
                ctx.fill(cowl, with: .color(inverted ? Color(hex:"#333") : Color(hex:"#3a1a5a")))

                // face cutout
                var face = Path(); face.move(to: pt(11,14))
                face.addQuadCurve(to: pt(25,14), control: pt(18,12))
                face.addLine(to: pt(25,18))
                face.addQuadCurve(to: pt(11,18), control: pt(18,19))
                face.closeSubpath()
                ctx.fill(face, with: .color(inverted ? Color(hex:"#444") : skin))

                ctx.fill(Path(ellipseIn: CGRect(x:13.1*s, y:14.9*s, width:2.8*s, height:2.2*s)), with: .color(inverted ? dark0 : .white))
                ctx.fill(Path(ellipseIn: CGRect(x:20.1*s, y:14.9*s, width:2.8*s, height:2.2*s)), with: .color(inverted ? dark0 : .white))
                ctx.fill(Path(ellipseIn: CGRect(x:13.7*s, y:15.4*s, width:1.2*s, height:1.2*s)), with: .color(inverted ? accent : Color(hex:"#3a1a5a")))
                ctx.fill(Path(ellipseIn: CGRect(x:20.7*s, y:15.4*s, width:1.2*s, height:1.2*s)), with: .color(inverted ? accent : Color(hex:"#3a1a5a")))

                // moon emblem (crescent using two overlapping circles)
                ctx.fill(Path(ellipseIn: CGRect(x:15.2*s, y:25*s, width:5.6*s, height:5.6*s)),
                         with: .color(inverted ? accent : Color(hex:"#C9A8FF")))
                ctx.fill(Path(ellipseIn: CGRect(x:16.4*s, y:25*s, width:4.4*s, height:4.4*s)),
                         with: .color(inverted ? Color(hex:"#1a0a2a") : Color(hex:"#3a1a5a")))

            case .ember:
                var cape = Path(); cape.move(to: pt(6,26)); cape.addLine(to: pt(18,22))
                cape.addLine(to: pt(30,26)); cape.addLine(to: pt(28,34)); cape.addLine(to: pt(8,34))
                cape.closeSubpath()
                ctx.fill(cape, with: .color(inverted ? dark1 : Color(hex:"#7a1414")))

                ctx.fill(Path(roundedRect: CGRect(x:10*s, y:22*s, width:16*s, height:10*s), cornerRadius:3*s),
                         with: .color(inverted ? dark1 : Color(hex:"#a31b00")))

                ctx.fill(Path(ellipseIn: CGRect(x:9*s, y:5*s, width:18*s, height:18*s)),
                         with: .color(inverted ? Color(hex:"#222") : skin))

                // flame hair (orange base)
                var flameBg = Path()
                flameBg.move(to: pt(9,12)); flameBg.addQuadCurve(to: pt(15,7), control: pt(11,4))
                flameBg.addQuadCurve(to: pt(21,7), control: pt(18,3))
                flameBg.addQuadCurve(to: pt(27,12), control: pt(25,4))
                flameBg.addQuadCurve(to: pt(18,10), control: pt(24,9))
                flameBg.addQuadCurve(to: pt(9,12), control: pt(12,9))
                flameBg.closeSubpath()
                ctx.fill(flameBg, with: .color(Color(hex:"#FF6B1A")))

                // flame highlight (yellow)
                var flameFg = Path()
                flameFg.move(to: pt(11,11)); flameFg.addQuadCurve(to: pt(17,9), control: pt(14,7))
                flameFg.addQuadCurve(to: pt(23,9), control: pt(20,6))
                flameFg.addQuadCurve(to: pt(25,12), control: pt(26,7))
                flameFg.addQuadCurve(to: pt(18,11), control: pt(21,10))
                flameFg.addQuadCurve(to: pt(11,11), control: pt(15,10))
                flameFg.closeSubpath()
                ctx.fill(flameFg, with: .color(Color(hex:"#FFD84D").opacity(0.85)))

                // mask
                var mask = Path(); mask.move(to: pt(11,14))
                mask.addQuadCurve(to: pt(25,14), control: pt(18,12))
                mask.addLine(to: pt(24,17)); mask.addQuadCurve(to: pt(12,17), control: pt(18,18))
                mask.closeSubpath()
                ctx.fill(mask, with: .color(inverted ? accent : Color(hex:"#a31b00")))

                ctx.fill(Path(ellipseIn: CGRect(x:13.5*s, y:14.5*s, width:2*s, height:2*s)), with: .color(Color(hex:"#FFD84D")))
                ctx.fill(Path(ellipseIn: CGRect(x:20.5*s, y:14.5*s, width:2*s, height:2*s)), with: .color(Color(hex:"#FFD84D")))

                var mouth = Path(); mouth.move(to: pt(16,19)); mouth.addQuadCurve(to: pt(20,19), control: pt(18,20.5))
                ctx.stroke(mouth, with: .color(skinShade), style: StrokeStyle(lineWidth:0.8*s, lineCap:.round))

                // flame emblem
                var flame = Path(); flame.move(to: pt(16,25))
                flame.addQuadCurve(to: pt(17,29), control: pt(18,27))
                flame.addQuadCurve(to: pt(20,25), control: pt(19,28))
                flame.addQuadCurve(to: pt(21,25), control: pt(20,27))
                ctx.stroke(flame, with: .color(inverted ? accent : Color(hex:"#FFD84D")),
                           style: StrokeStyle(lineWidth:1.2*s, lineCap:.round, lineJoin:.round))
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        ForEach(ZapTheme.HeroKind.allCases, id: \.self) { kind in
            ChibiHero(kind: kind, size: 72)
                .padding(8)
                .background(Color(hex: "#141416"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
    .background(Color(hex: "#0A0A0B"))
}
