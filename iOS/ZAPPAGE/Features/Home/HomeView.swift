import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }

    var body: some View {
        TabView {
            homeTab
                .tabItem { Label("Home",    systemImage: "house.fill") }
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }
            Text("Store")
                .tabItem { Label("Store",   systemImage: "storefront.fill") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(ZapTheme.accent)
    }

    private var homeTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HomeBrandBar(tone: tone)
                HomeSearchBar(tone: tone)
                PublisherChips(tone: tone)
                FeaturedHeroCard(comic: MockData.featured, tone: tone)
                HomeSectionHeader(title: "Continue Reading", tone: tone)
                ContinueReadingRow(comics: MockData.continueReading, tone: tone)
                HomeSectionHeader(title: "New This Week", tone: tone)
                NewThisWeekRow(comics: MockData.newThisWeek, tone: tone)
                HomeSectionHeader(title: "My Library", tone: tone)
                MyLibraryList(comics: MockData.myLibrary, tone: tone)
                HomeSectionHeader(title: "Trending", tone: tone)
                TrendingList(comics: MockData.trending, tone: tone)
                Spacer().frame(height: 24)
            }
        }
        .background(tone.bg)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Brand bar
private struct HomeBrandBar: View {
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent

    var body: some View {
        HStack {
            ZapWordmark(size: 22, textColor: tone.text, accent: accent)
            Spacer()
            // Avatar button
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(tone.chipBg)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(tone.chipBorder, lineWidth: 0.5))
                ChibiHero(kind: .zap, accent: accent, size: 28)
            }
            .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 6)
    }
}

// MARK: - Search bar
private struct HomeSearchBar: View {
    let tone: ZapTheme.Tone
    @State private var query = ""
    @FocusState private var focused: Bool
    private let accent = ZapTheme.accent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(focused ? tone.text : tone.textDim)

            TextField("Search titles, characters, creators…", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(tone.text)
                .tint(accent)
                .focused($focused)

            if query.isEmpty {
                Text("⌘K")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tone.textMuted)
                    .kerning(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(tone.chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(tone.chipBorder, lineWidth: 0.5))
            } else {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(tone.textDim)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(focused ? tone.fieldFocus : tone.field.opacity(1.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? accent.opacity(0.5) : tone.chipBorder, lineWidth: 0.5))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.12), value: focused)
    }
}

// MARK: - Publisher filter chips
private struct PublisherChips: View {
    let tone: ZapTheme.Tone
    @State private var active = "All"
    private let accent = ZapTheme.accent
    private let publishers = ["All", "DC", "Marvel", "Image", "Dark Horse", "Boom!", "IDW", "Indie"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(publishers, id: \.self) { pub in
                    let on = pub == active
                    Button { active = pub } label: {
                        Text(pub)
                            .font(ZapTheme.archivoBlack(12))
                            .kerning(0.4)
                            .textCase(.uppercase)
                            .foregroundStyle(on ? .white : tone.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(on ? accent : tone.chipBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? accent : tone.chipBorder, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Featured hero card (currently reading)
private struct FeaturedHeroCard: View {
    let comic: MockComic
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // gradient bg
            LinearGradient(colors: [Color(hex: comic.bgFrom), Color(hex: comic.bgTo)],
                           startPoint: .init(x: 0.1, y: 0), endPoint: .init(x: 0.9, y: 1))

            // halftone
            Canvas { ctx, size in
                let sp: CGFloat = 8, r: CGFloat = 0.55
                for col in 0...Int(size.width/sp)+1 {
                    for row in 0...Int(size.height/sp)+1 {
                        ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(col)*sp-r, y: CGFloat(row)*sp-r, width: r*2, height: r*2)),
                                 with: .color(Color(hex: comic.fgAlt).opacity(0.18)))
                    }
                }
            }.blendMode(.overlay)

            // burst
            RadialGradient(colors: [Color(hex: comic.fg).opacity(0.55), .clear],
                           center: .init(x: 1.1, y: -0.25), startRadius: 0, endRadius: 180)

            // content
            VStack(alignment: .leading, spacing: 0) {
                // "Pick up where you left off" tag
                HStack(spacing: 6) {
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .opacity(pulse ? 0.5 : 1)
                        .scaleEffect(pulse ? 0.7 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
                    Text("Pick Up Where You Left Off")
                        .font(ZapTheme.archivoBlack(10))
                        .kerning(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(14)
                .onAppear { pulse = true }

                Spacer()

                // bottom row
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comic.title)
                            .font(ZapTheme.archivoBlack(32))
                            .foregroundStyle(Color(hex: comic.fg))
                            .textCase(.uppercase)
                            .kerning(-0.8)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 2)

                        Text("Issue \(comic.issue) · Page \(comic.currentPage) of \(comic.pages) · \(Int(comic.progress * 100))%")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.85))
                            .kerning(0.2)

                        // progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.black.opacity(0.4))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(accent)
                                    .shadow(color: accent, radius: 4)
                                    .frame(width: geo.size.width * comic.progress)
                            }
                        }
                        .frame(height: 4)
                    }

                    // Resume button
                    Button {  } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Resume")
                                .font(ZapTheme.archivoBlack(11))
                                .kerning(0.4)
                                .textCase(.uppercase)
                        }
                        .foregroundStyle(Color(hex: "#0A0A0B"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
                .padding(14)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.35), radius: 15, x: 0, y: 10)
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
}

// MARK: - Section header
private struct HomeSectionHeader: View {
    let title: String
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(ZapTheme.archivoBlack(18))
                .textCase(.uppercase)
                .kerning(-0.2)
                .foregroundStyle(tone.text)
            Spacer()
            Button("See all ›") { }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .kerning(-0.1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Continue Reading row
private struct ContinueReadingRow: View {
    let comics: [MockComic]
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(comics) { comic in
                    VStack(alignment: .leading, spacing: 6) {
                        ComicCoverCard(comic: comic, width: 110, height: 154, accent: accent)

                        // progress bar
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(tone.chipBg)
                            RoundedRectangle(cornerRadius: 2).fill(accent)
                                .frame(width: 110 * comic.progress)
                        }
                        .frame(width: 110, height: 3)

                        Text(comic.displayTitle)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(tone.text)
                            .lineLimit(1)
                            .frame(width: 110, alignment: .leading)

                        Text("\(Int(comic.progress * 100))% · \(comic.issue)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(tone.textDim)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - New This Week row
private struct NewThisWeekRow: View {
    let comics: [MockComic]
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(comics.enumerated()), id: \.element.id) { index, comic in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            ComicCoverCard(comic: comic, width: 124, height: 174, accent: accent)
                            if index == 0 {
                                Text("NEW")
                                    .font(ZapTheme.archivoBlack(8))
                                    .kerning(0.6)
                                    .foregroundStyle(Color(hex: "#0A0A0B"))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                    .padding(8)
                            }
                        }

                        Text(comic.displayTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tone.text)
                            .lineLimit(1)
                            .frame(width: 124, alignment: .leading)

                        Text(comic.sub)
                            .font(.system(size: 10.5))
                            .foregroundStyle(tone.textDim)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - My Library list
private struct MyLibraryList: View {
    let comics: [MockComic]
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent

    var body: some View {
        VStack(spacing: 12) {
            ForEach(comics) { comic in
                HStack(spacing: 12) {
                    ComicCoverCard(comic: comic, width: 48, height: 68, accent: accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(comic.displayTitle) \(comic.issue)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tone.text)
                            .kerning(-0.2)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#3DD68C"))
                            Text("Downloaded · \(String(format: "%.1f", comic.fileSizeMB)) MB · \(comic.publisher)")
                                .font(.system(size: 12))
                                .foregroundStyle(tone.textDim)
                        }
                    }

                    Spacer()

                    // three-dots button
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tone.chipBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.chipBorder, lineWidth: 0.5))
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13))
                            .foregroundStyle(tone.text)
                    }
                    .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Trending list
private struct TrendingList: View {
    let comics: [MockComic]
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent
    private let publishers = ["Boom!", "Marvel", "Image", "DC", "Dark Horse"]
    private let readers = ["18.4k", "22.1k", "15.9k", "31.2k", "12.7k"]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(comics.enumerated()), id: \.element.id) { index, comic in
                HStack(spacing: 12) {
                    // rank number
                    Text(String(format: "%02d", index + 1))
                        .font(ZapTheme.archivoBlack(18))
                        .foregroundStyle(index == 0 ? accent : tone.textMuted)
                        .frame(width: 22, alignment: .center)

                    ComicCoverCard(comic: comic, width: 48, height: 68, accent: accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(comic.displayTitle) \(comic.issue)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tone.text)
                            .kerning(-0.2)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(accent)
                            Text("\(String(format: "%.1f", comic.rating)) · \(publishers[index]) · \(readers[index]) readers")
                                .font(.system(size: 12))
                                .foregroundStyle(tone.textDim)
                        }
                    }

                    Spacer()

                    // bookmark button
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tone.chipBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.chipBorder, lineWidth: 0.5))
                        Image(systemName: "bookmark")
                            .font(.system(size: 13))
                            .foregroundStyle(tone.text)
                    }
                    .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

#Preview("Dark")  { HomeView().preferredColorScheme(.dark) }
#Preview("Light") { HomeView().preferredColorScheme(.light) }
