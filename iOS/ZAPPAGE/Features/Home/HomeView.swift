import SwiftUI

// MARK: - Route
enum HomeRoute: String, CaseIterable {
    case home, reading, library, favourites, read

    var label: String {
        switch self {
        case .home:       return "Home"
        case .reading:    return "Currently Reading"
        case .library:    return "My Library"
        case .favourites: return "Favourites"
        case .read:       return "Read Comics"
        }
    }
    var icon: String {
        switch self {
        case .home:       return "house"
        case .reading:    return "book"
        case .library:    return "books.vertical"
        case .favourites: return "heart"
        case .read:       return "checkmark.circle"
        }
    }
    var badge: String? { self == .library ? "24" : nil }
}

// MARK: - HomeView
struct HomeView: View {
    @State private var route: HomeRoute = .home
    @State private var menuOpen = false
    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }

    var body: some View {
        VStack(spacing: 0) {
            HomeBrandBar(tone: tone, route: route, menuOpen: $menuOpen)

            ZStack(alignment: .topTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch route {
                        case .home:
                            homeSections
                        default:
                            SubPageView(route: route, tone: tone)
                        }
                        Spacer().frame(height: 32)
                    }
                }
                .background(tone.bg)

                if menuOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { menuOpen = false } }
                }

                if menuOpen {
                    UserMenuDropdown(tone: tone, route: $route, menuOpen: $menuOpen)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing))
                            .combined(with: .offset(y: -6)))
                        .padding(.trailing, 20)
                        .padding(.top, 4)
                }
            }
        }
        .background(tone.bg)
        .ignoresSafeArea(edges: .top)
        .animation(.easeOut(duration: 0.14), value: menuOpen)
    }

    // MARK: - Home feed sections
    @ViewBuilder
    private var homeSections: some View {
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
    }
}

// MARK: - Brand bar
private struct HomeBrandBar: View {
    let tone: ZapTheme.Tone
    let route: HomeRoute
    @Binding var menuOpen: Bool
    private let accent = ZapTheme.accent

    var body: some View {
        HStack {
            ZapWordmark(size: 26, textColor: tone.text, accent: accent)
            Spacer()
            // Avatar button — accent bg when open, chipBg when closed
            Button { withAnimation(.easeOut(duration: 0.14)) { menuOpen.toggle() } } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(menuOpen ? accent : tone.chipBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(menuOpen ? accent : tone.chipBorder, lineWidth: 0.5)
                        )
                    ChibiHero(kind: .zap, accent: accent, inverted: menuOpen, size: 30)
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
        .background(tone.bg)
    }
}

// MARK: - User menu dropdown
// Matches UserMenu in the design reference (home.jsx).
private struct UserMenuDropdown: View {
    let tone: ZapTheme.Tone
    @Binding var route: HomeRoute
    @Binding var menuOpen: Bool
    private let accent = ZapTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            // Header — avatar + name + tier
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent)
                    ChibiHero(kind: .zap, accent: accent, size: 36)
                }
                .frame(width: 36, height: 36)
                .clipped()

                VStack(alignment: .leading, spacing: 1) {
                    Text("Kira Soto")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(tone.text)
                        .kerning(-0.15)
                    Text("Premium · 247 issues")
                        .font(.system(size: 11.5))
                        .foregroundStyle(tone.textDim)
                }
                Spacer()
            }
            .padding(14)
            .padding(.bottom, 12)

            Divider().overlay(tone.line)

            // Navigation items
            VStack(spacing: 2) {
                ForEach(HomeRoute.allCases, id: \.self) { r in
                    let active = r == route
                    Button {
                        withAnimation(.easeOut(duration: 0.14)) {
                            route = r
                            menuOpen = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: r.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(active ? accent : tone.textDim)
                                .frame(width: 22, height: 22)

                            Text(r.label)
                                .font(.system(size: 14, weight: active ? .semibold : .medium))
                                .foregroundStyle(active ? accent : tone.text)
                                .kerning(-0.15)

                            Spacer()

                            if let badge = r.badge, !active {
                                Text(badge)
                                    .font(ZapTheme.archivoBlack(10))
                                    .kerning(0.3)
                                    .foregroundStyle(tone.textDim)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(tone.chipBg)
                                    .clipShape(Capsule())
                            }

                            if active {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(active ? tone.chipBg : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)

            Divider().overlay(tone.line)

            // Logout
            Button {
                menuOpen = false
                // TODO: sign out
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#F04E2A"))
                        .frame(width: 22, height: 22)
                    Text("Log Out")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "#F04E2A"))
                        .kerning(-0.15)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .frame(width: 232)
        .background(tone.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tone.chipBorder, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 12)
        .shadow(color: .black.opacity(0.3),  radius: 4,  x: 0, y: 2)
    }
}

// MARK: - Sub-page (Currently Reading / My Library / Favourites / Read)
private struct SubPageView: View {
    let route: HomeRoute
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent

    private var comics: [MockComic] {
        switch route {
        case .reading:    return MockData.continueReading
        case .library:    return MockData.myLibrary
        case .favourites: return MockData.covers.filter { $0.isFavourite }
        case .read:       return MockData.covers.filter { $0.progress >= 1.0 }
        default:          return []
        }
    }

    private var subtitle: String {
        switch route {
        case .reading:    return "Pick up where you left off"
        case .library:    return "24 issues downloaded · 2.3 GB"
        case .favourites: return "Your saved comics & series"
        case .read:       return "Finished issues · 142 total"
        default:          return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // page header
            VStack(alignment: .leading, spacing: 4) {
                Text(route.label)
                    .font(ZapTheme.archivoBlack(26))
                    .foregroundStyle(tone.text)
                    .textCase(.uppercase)
                    .kerning(-0.5)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(tone.textDim)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            if comics.isEmpty {
                Text("Nothing here yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(tone.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 60)
            } else {
                // 3-column grid
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(comics) { comic in
                        VStack(alignment: .leading, spacing: 6) {
                            ComicCoverCard(comic: comic,
                                           width: (UIScreen.main.bounds.width - 40 - 24) / 3,
                                           height: ((UIScreen.main.bounds.width - 40 - 24) / 3) * 1.4,
                                           accent: accent)

                            if route == .reading && comic.progress > 0 {
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(tone.chipBg)
                                    RoundedRectangle(cornerRadius: 2).fill(accent)
                                        .frame(width: ((UIScreen.main.bounds.width - 40 - 24) / 3) * CGFloat(comic.progress))
                                }
                                .frame(height: 3)
                            }

                            Text(comic.displayTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(tone.text)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
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
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(tone.chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(tone.chipBorder, lineWidth: 0.5))
            } else {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(tone.textDim)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(focused ? tone.fieldFocus : tone.field)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? accent.opacity(0.5) : tone.chipBorder, lineWidth: 0.5))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.12), value: focused)
    }
}

// MARK: - Publisher chips
private struct PublisherChips: View {
    let tone: ZapTheme.Tone
    @State private var active = "All"
    private let accent = ZapTheme.accent
    private let publishers = ["All","DC","Marvel","Image","Dark Horse","Boom!","IDW","Indie"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(publishers, id: \.self) { pub in
                    let on = pub == active
                    Button { active = pub } label: {
                        Text(pub)
                            .font(ZapTheme.archivoBlack(12)).kerning(0.4).textCase(.uppercase)
                            .foregroundStyle(on ? .white : tone.text)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(on ? accent : tone.chipBg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? accent : tone.chipBorder, lineWidth: 0.5))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Featured hero card
private struct FeaturedHeroCard: View {
    let comic: MockComic
    let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: comic.bgFrom), Color(hex: comic.bgTo)],
                           startPoint: .init(x: 0.1, y: 0), endPoint: .init(x: 0.9, y: 1))
            Canvas { ctx, size in
                let sp: CGFloat = 8, r: CGFloat = 0.55
                for col in 0...Int(size.width/sp)+1 {
                    for row in 0...Int(size.height/sp)+1 {
                        ctx.fill(Path(ellipseIn: CGRect(x: CGFloat(col)*sp-r, y: CGFloat(row)*sp-r, width: r*2, height: r*2)),
                                 with: .color(Color(hex: comic.fgAlt).opacity(0.18)))
                    }
                }
            }.blendMode(.overlay)
            RadialGradient(colors: [Color(hex: comic.fg).opacity(0.55), .clear],
                           center: .init(x: 1.1, y: -0.25), startRadius: 0, endRadius: 180)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(.white).frame(width: 6, height: 6)
                        .opacity(pulse ? 0.5 : 1).scaleEffect(pulse ? 0.7 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(), value: pulse)
                    Text("Pick Up Where You Left Off")
                        .font(ZapTheme.archivoBlack(10)).kerning(0.8).textCase(.uppercase).foregroundStyle(.white)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(accent).clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(14).onAppear { pulse = true }

                Spacer()

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(comic.title)
                            .font(ZapTheme.archivoBlack(32)).foregroundStyle(Color(hex: comic.fg))
                            .textCase(.uppercase).kerning(-0.8).lineLimit(2)
                            .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 2)
                        Text("Issue \(comic.issue) · Page \(comic.currentPage) of \(comic.pages) · \(Int(comic.progress*100))%")
                            .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.85)).kerning(0.2)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2).fill(Color.black.opacity(0.4))
                                RoundedRectangle(cornerRadius: 2).fill(accent).shadow(color: accent, radius: 4)
                                    .frame(width: geo.size.width * comic.progress)
                            }
                        }.frame(height: 4)
                    }
                    Button { } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill").font(.system(size: 10))
                            Text("Resume").font(ZapTheme.archivoBlack(11)).kerning(0.4).textCase(.uppercase)
                        }
                        .foregroundStyle(Color(hex: "#0A0A0B"))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.white).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).fixedSize()
                }
                .padding(14)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.35), radius: 15, x: 0, y: 10)
        .padding(.horizontal, 20).padding(.top, 14)
    }
}

// MARK: - Section header
private struct HomeSectionHeader: View {
    let title: String
    let tone: ZapTheme.Tone
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(ZapTheme.archivoBlack(18)).textCase(.uppercase).kerning(-0.2).foregroundStyle(tone.text)
            Spacer()
            Button("See all ›") { }.font(.system(size: 13, weight: .semibold)).foregroundStyle(ZapTheme.accent).kerning(-0.1)
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 10)
    }
}

// MARK: - Continue Reading row
private struct ContinueReadingRow: View {
    let comics: [MockComic]; let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(comics) { comic in
                    VStack(alignment: .leading, spacing: 6) {
                        ComicCoverCard(comic: comic, width: 110, height: 154, accent: accent)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(tone.chipBg)
                            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 110 * comic.progress)
                        }.frame(width: 110, height: 3)
                        Text(comic.displayTitle).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(tone.text).lineLimit(1).frame(width: 110, alignment: .leading)
                        Text("\(Int(comic.progress*100))% · \(comic.issue)").font(.system(size: 10.5)).foregroundStyle(tone.textDim)
                    }
                }
            }.padding(.horizontal, 20)
        }
    }
}

// MARK: - New This Week row
private struct NewThisWeekRow: View {
    let comics: [MockComic]; let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(comics.enumerated()), id: \.element.id) { index, comic in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            ComicCoverCard(comic: comic, width: 124, height: 174, accent: accent)
                            if index == 0 {
                                Text("NEW").font(ZapTheme.archivoBlack(8)).kerning(0.6)
                                    .foregroundStyle(Color(hex: "#0A0A0B"))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 3))
                                    .padding(8)
                            }
                        }
                        Text(comic.displayTitle).font(.system(size: 12, weight: .semibold)).foregroundStyle(tone.text).lineLimit(1).frame(width: 124, alignment: .leading)
                        Text(comic.sub).font(.system(size: 10.5)).foregroundStyle(tone.textDim)
                    }
                }
            }.padding(.horizontal, 20)
        }
    }
}

// MARK: - My Library list
private struct MyLibraryList: View {
    let comics: [MockComic]; let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent
    var body: some View {
        VStack(spacing: 12) {
            ForEach(comics) { comic in
                HStack(spacing: 12) {
                    ComicCoverCard(comic: comic, width: 48, height: 68, accent: accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(comic.displayTitle) \(comic.issue)").font(.system(size: 14, weight: .semibold)).foregroundStyle(tone.text).kerning(-0.2).lineLimit(1)
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#3DD68C"))
                            Text("Downloaded · \(String(format: "%.1f", comic.fileSizeMB)) MB · \(comic.publisher)").font(.system(size: 12)).foregroundStyle(tone.textDim)
                        }
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(tone.chipBg).overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.chipBorder, lineWidth: 0.5))
                        Image(systemName: "ellipsis").font(.system(size: 13)).foregroundStyle(tone.text)
                    }.frame(width: 32, height: 32)
                }
            }
        }.padding(.horizontal, 20).padding(.bottom, 12)
    }
}

// MARK: - Trending list
private struct TrendingList: View {
    let comics: [MockComic]; let tone: ZapTheme.Tone
    private let accent = ZapTheme.accent
    private let readers = ["18.4k","22.1k","15.9k","31.2k","12.7k"]
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(comics.enumerated()), id: \.element.id) { index, comic in
                HStack(spacing: 12) {
                    Text(String(format: "%02d", index+1)).font(ZapTheme.archivoBlack(18)).foregroundStyle(index == 0 ? accent : tone.textMuted).frame(width: 22, alignment: .center)
                    ComicCoverCard(comic: comic, width: 48, height: 68, accent: accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(comic.displayTitle) \(comic.issue)").font(.system(size: 14, weight: .semibold)).foregroundStyle(tone.text).kerning(-0.2).lineLimit(1)
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(accent)
                            Text("\(String(format: "%.1f", comic.rating)) · \(comic.publisher) · \(readers[index]) readers").font(.system(size: 12)).foregroundStyle(tone.textDim)
                        }
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(tone.chipBg).overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.chipBorder, lineWidth: 0.5))
                        Image(systemName: "bookmark").font(.system(size: 13)).foregroundStyle(tone.text)
                    }.frame(width: 32, height: 32)
                }
            }
        }.padding(.horizontal, 20).padding(.bottom, 12)
    }
}

#Preview("Dark")  { HomeView().preferredColorScheme(.dark) }
#Preview("Light") { HomeView().preferredColorScheme(.light) }
