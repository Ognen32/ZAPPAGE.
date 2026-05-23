import SwiftUI

// TODO: implement Search — full-text search, filters, genre chips
struct SearchView: View {
    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }

    var body: some View {
        ZStack {
            tone.bg.ignoresSafeArea()
            Text("Search — coming soon")
                .font(.system(size: 14))
                .foregroundStyle(tone.textMuted)
        }
    }
}
