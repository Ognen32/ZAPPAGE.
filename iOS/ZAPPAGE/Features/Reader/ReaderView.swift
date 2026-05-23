import SwiftUI

// TODO: implement Reader — page-by-page comic reader, zoom, progress tracking, download
struct ReaderView: View {
    let comic: Comic

    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Reader — coming soon")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}
