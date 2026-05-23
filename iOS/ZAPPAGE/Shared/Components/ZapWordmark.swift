import SwiftUI

struct ZapWordmark: View {
    var size: CGFloat = 22
    var textColor: Color = Color(hex: "#FAFAFA")
    var accent: Color = ZapTheme.accent
    var letterSpacing: CGFloat = -0.5

    var body: some View {
        (Text("ZAP").foregroundStyle(accent)
            + Text("COMICS").foregroundStyle(textColor)
            + Text(".").foregroundStyle(accent)
                .font(ZapTheme.archivoBlack(size * 0.9))
        )
        .font(ZapTheme.archivoBlack(size))
        .kerning(letterSpacing)
    }
}

#Preview {
    ZapWordmark()
        .padding()
        .background(Color(hex: "#0A0A0B"))
}
