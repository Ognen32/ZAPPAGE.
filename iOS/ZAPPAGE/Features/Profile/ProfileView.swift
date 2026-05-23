import SwiftUI

// TODO: implement Profile — avatar, stats, settings, sign out
struct ProfileView: View {
    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }

    var body: some View {
        ZStack {
            tone.bg.ignoresSafeArea()
            Text("Profile — coming soon")
                .font(.system(size: 14))
                .foregroundStyle(tone.textMuted)
        }
    }
}
