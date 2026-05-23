import SwiftUI

// TODO: implement Library — downloaded comics, reading progress, favourites, read history
struct LibraryView: View {
    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }

    var body: some View {
        ZStack {
            tone.bg.ignoresSafeArea()
            Text("Library — coming soon")
                .font(.system(size: 14))
                .foregroundStyle(tone.textMuted)
        }
    }
}
