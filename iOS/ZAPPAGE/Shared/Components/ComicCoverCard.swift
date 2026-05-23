import SwiftUI

// Comic cover placeholder card — gradient + halftone + burst + typography.
// Faithfully translated from the Cover component in the design reference (covers.jsx).
struct ComicCoverCard: View {
    let comic: MockComic
    var width: CGFloat = 120
    var height: CGFloat = 168
    var accent: Color = ZapTheme.accent

    var body: some View {
        ZStack(alignment: .topLeading) {
            // base gradient
            LinearGradient(colors: [Color(hex: comic.bgFrom), Color(hex: comic.bgTo)],
                           startPoint: .init(x: 0.1, y: 0),
                           endPoint: .init(x: 0.9, y: 1))

            // halftone dots
            Canvas { ctx, size in
                let spacing: CGFloat = 5
                let r: CGFloat = 0.45
                let cols = Int(size.width  / spacing) + 1
                let rows = Int(size.height / spacing) + 1
                for col in 0...cols {
                    for row in 0...rows {
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: CGFloat(col)*spacing - r, y: CGFloat(row)*spacing - r, width: r*2, height: r*2)),
                            with: .color(Color(hex: comic.fgAlt).opacity(0.18))
                        )
                    }
                }
            }
            .blendMode(.overlay)

            // burst
            RadialGradient(colors: [Color(hex: comic.fg).opacity(0.55), .clear],
                           center: .init(x: 1.1, y: -0.2),
                           startRadius: 0,
                           endRadius: width * 0.85)

            // issue chip
            Text(comic.issue)
                .font(ZapTheme.archivoBlack(max(8, width * 0.075)))
                .kerning(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(8)

            // title + subtitle pinned to bottom
            VStack(alignment: .leading, spacing: 3) {
                Text(comic.title)
                    .font(ZapTheme.archivoBlack(max(12, width * 0.135)))
                    .foregroundStyle(Color(hex: comic.fg))
                    .textCase(.uppercase)
                    .kerning(-0.5)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: 1)

                if !comic.sub.isEmpty {
                    Text(comic.sub)
                        .font(ZapTheme.archivoBlack(max(7, width * 0.058)))
                        .foregroundStyle(Color(hex: comic.fgAlt))
                        .textCase(.uppercase)
                        .kerning(0.8)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // barcode strip
            LinearGradient(colors: [.clear, Color(hex: comic.fgAlt).opacity(0.5), Color(hex: comic.fgAlt).opacity(0.5), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 3)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.35), radius: 7, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
        )
    }
}
