import SwiftUI

// TODO: implement Home screen — comic discovery, featured, trending, genres
struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }

    var body: some View {
        ZStack {
            tone.bg.ignoresSafeArea()
            VStack(spacing: 12) {
                ZapWordmark(size: 22, textColor: tone.text)
                Text("Home — coming soon")
                    .font(.system(size: 14))
                    .foregroundStyle(tone.textMuted)
            }
        }
    }
}
