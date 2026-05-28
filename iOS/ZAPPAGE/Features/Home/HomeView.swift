import SwiftUI
import FirebaseAuth

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

    func localLabel(_ s: ZapStrings) -> String {
        switch self {
        case .home:       return s.routeHome
        case .reading:    return s.routeReading
        case .library:    return s.routeLibrary
        case .favourites: return s.routeFavourites
        case .read:       return s.routeRead
        }
    }

    func localSubtitle(_ s: ZapStrings) -> String {
        switch self {
        case .reading:    return s.subtitleReading
        case .library:    return s.subtitleLibrary
        case .favourites: return s.subtitleFavourites
        case .read:       return s.subtitleRead
        default:          return ""
        }
    }
}

// MARK: - Connection state
enum ConnectionState {
    case idle, checking, online, offline

    var dotColor: Color {
        switch self {
        case .idle:     return Color(hex: "#555566")
        case .checking: return Color(hex: "#FFD84D")
        case .online:   return Color(hex: "#3DD68C")
        case .offline:  return Color(hex: "#F04E2A")
        }
    }

    var label: String {
        switch self {
        case .idle:     return "OFF"
        case .checking: return "···"
        case .online:   return "ON"
        case .offline:  return "ERR"
        }
    }
}

// MARK: - HomeView
struct HomeView: View {
    var onSignOut: () -> Void = {}
    @State private var session = UserSession()
    @State private var route: HomeRoute = .home
    @State private var menuOpen = false
    @AppStorage("backendIP") private var backendIP: String = ""
    @AppStorage("zapLanguage") private var languageRaw: String = ZapLanguage.english.rawValue
    @State private var connectionState: ConnectionState = .idle
    @State private var searchActive = false
    @State private var selectedPublisher = "Home"
    @State private var dcNewComics: [APIComic] = []
    @State private var marvelNewComics: [APIComic] = []
    @State private var showDocPicker = false
    @State private var cbzPages: [CBZPage] = []
    @State private var showReader = false
    @State private var selectedComic: APIComic? = nil
    private var library: LibraryStore { LibraryStore.shared }
    @Environment(\.colorScheme) private var scheme
    private var tone: ZapTheme.Tone { scheme == .dark ? ZapTheme.dark : ZapTheme.light }
    private var language: ZapLanguage { ZapLanguage(rawValue: languageRaw) ?? .english }
    private var s: ZapStrings { ZapStrings(language: language) }

    var body: some View {
        VStack(spacing: 0) {
            HomeBrandBar(
                tone: tone,
                route: route,
                menuOpen: $menuOpen,
                hero: session.hero,
                connectionState: connectionState,
                languageRaw: $languageRaw,
                onConnectionTap: {
                    if connectionState == .online { connectionState = .idle }
                    else if connectionState != .checking { checkConnection() }
                }
            )

            ZStack(alignment: .topTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch route {
                        case .home:
                            if connectionState == .online { homeSections }
                        default:
                            SubPageView(route: route, tone: tone, s: s,
                                        onOpenLibraryComic: openLibraryComic)
                        }
                        Spacer().frame(height: 32)
                    }
                }
                .background(tone.bg)

                if connectionState != .online && route == .home {
                    ServerConnectPrompt(
                        tone: tone,
                        connectionState: connectionState,
                        s: s,
                        onTap: { if connectionState != .checking { checkConnection() } }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if menuOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { menuOpen = false } }
                }

                if menuOpen {
                    UserMenuDropdown(tone: tone, route: $route, menuOpen: $menuOpen, hero: session.hero, username: session.username, email: session.email, connectionState: connectionState, s: s, onSignOut: onSignOut, onLoadComic: { showDocPicker = true })
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing))
                            .combined(with: .offset(y: -6)))
                        .padding(.trailing, 20)
                        .padding(.top, 4)
                        .zIndex(20)
                }

                if searchActive {
                    SearchView(
                        tone: tone,
                        s: s,
                        backendIP: backendIP,
                        onDismiss: { withAnimation(.easeOut(duration: 0.2)) { searchActive = false; selectedPublisher = "Home" } },
                        onSelect: { selectedComic = $0 }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }
            }
        }
        .background(tone.bg)
        .ignoresSafeArea(edges: .top)
        .animation(.easeOut(duration: 0.14), value: menuOpen)
        .task { await session.load() }
        .onChange(of: connectionState) { _, new in
            if new == .online { fetchNewComics() }
        }
        .sheet(isPresented: $showDocPicker) {
            DocumentPicker { url in
                // Acquire scope now, while the picker callback is still active,
                // before dismissing the sheet could invalidate the sandbox grant.
                let access = url.startAccessingSecurityScopedResource()
                showDocPicker = false
                Task.detached(priority: .userInitiated) {
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let pages = try? loadCBZPages(from: url), !pages.isEmpty else { return }
                    await MainActor.run {
                        cbzPages = pages
                        showReader = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showReader) {
            CBZReaderView(pages: cbzPages)
        }
        .fullScreenCover(item: $selectedComic) { comic in
            ComicDetailView(comic: comic, backendIP: backendIP, tone: tone)
        }
    }

    // MARK: - Home feed sections
    @ViewBuilder
    private var homeSections: some View {
        HomeSearchBar(tone: tone, s: s, onActivate: {
            withAnimation(.easeOut(duration: 0.2)) { searchActive = true }
        })
        PublisherChips(tone: tone, s: s, active: $selectedPublisher)
        if selectedPublisher == "Home" {
            FeaturedHeroCard(comic: MockData.featured, tone: tone, s: s)
            HomeSectionHeader(title: s.continueReading, tone: tone, s: s)
            ContinueReadingRow(comics: MockData.continueReading, tone: tone)
            HomeSectionHeader(title: s.newThisWeek, tone: tone, s: s, tag: "DC")
            MarqueeComicsRow(comics: dcNewComics, scrollLeft: true, tone: tone, onSelect: { selectedComic = $0 })
            HomeSectionHeader(title: s.newThisWeek, tone: tone, s: s, tag: "Marvel")
            MarqueeComicsRow(comics: marvelNewComics, scrollLeft: false, tone: tone, onSelect: { selectedComic = $0 })
            HomeSectionHeader(title: s.myLibrary, tone: tone, s: s)
            DownloadedComicsRow(library: library, tone: tone, onOpen: openLibraryComic)
            HomeSectionHeader(title: s.trending, tone: tone, s: s)
            TrendingList(comics: MockData.trending, tone: tone)
        } else {
            BrowseView(publisher: selectedPublisher, backendIP: backendIP, tone: tone, onSelect: { selectedComic = $0 })
        }
    }

    // MARK: - Open a locally downloaded comic in the reader
    func openLibraryComic(_ comic: LibraryComic) {
        let url = LibraryStore.shared.cbzURL(for: comic)
        Task.detached(priority: .userInitiated) {
            guard let pages = try? loadCBZPages(from: url), !pages.isEmpty else { return }
            await MainActor.run { cbzPages = pages; showReader = true }
        }
    }

    // MARK: - New comics fetch
    private func fetchNewComics() {
        Task {
            async let dc = try? BackendService(ip: backendIP).browse(category: "DC", page: 1)
            async let marvel = try? BackendService(ip: backendIP).browse(category: "Marvel", page: 1)
            let (dcResult, marvelResult) = await (dc, marvel)
            dcNewComics = Array((dcResult?.comics ?? []).prefix(10))
            marvelNewComics = Array((marvelResult?.comics ?? []).prefix(10))
        }
    }

    // MARK: - Backend connection check
    private func checkConnection() {
        guard !backendIP.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        connectionState = .checking
        Task { @MainActor in
            let raw = backendIP.trimmingCharacters(in: .whitespaces)
            guard let url = URL(string: "http://\(raw)/testConnection") else {
                connectionState = .offline; return
            }
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                connectionState = (response as? HTTPURLResponse)?.statusCode == 200 ? .online : .offline
            } catch {
                connectionState = .offline
            }
        }
    }
}

// MARK: - Brand bar
private struct HomeBrandBar: View {
    let tone: ZapTheme.Tone
    let route: HomeRoute
    @Binding var menuOpen: Bool
    let hero: ZapTheme.HeroKind
    let connectionState: ConnectionState
    @Binding var languageRaw: String
    let onConnectionTap: () -> Void
    private let accent = ZapTheme.accent

    var body: some View {
        HStack(spacing: 10) {
            ZapWordmark(size: 28, textColor: tone.text, accent: accent, letterSpacing: -1.5)
            Spacer()
            ConnectionPill(state: connectionState, action: onConnectionTap)
            LanguageToggle(selected: $languageRaw, tone: tone, accent: accent)
            // Avatar button — accent bg when open, chipBg when closed
            Button { withAnimation(.easeOut(duration: 0.14)) { menuOpen.toggle() } } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(menuOpen ? accent : tone.chipBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(menuOpen ? accent : tone.chipBorder, lineWidth: 0.5)
                        )
                    ChibiHero(kind: hero, accent: accent, inverted: menuOpen, size: 30)
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

// MARK: - Connection pill
private struct ConnectionPill: View {
    let state: ConnectionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(state.dotColor)
                    .frame(width: 6, height: 6)
                Text(state.label)
                    .font(ZapTheme.archivoBlack(9))
                    .kerning(0.5)
                    .foregroundStyle(state.dotColor)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(state.dotColor.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(state.dotColor.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(state == .checking)
    }
}

// MARK: - User menu dropdown
// Matches UserMenu in the design reference (home.jsx).
private struct UserMenuDropdown: View {
    let tone: ZapTheme.Tone
    @Binding var route: HomeRoute
    @Binding var menuOpen: Bool
    let hero: ZapTheme.HeroKind
    let username: String
    let email: String
    let connectionState: ConnectionState
    let s: ZapStrings
    let onSignOut: () -> Void
    let onLoadComic: () -> Void
    @AppStorage("backendIP") private var backendIP: String = ""
    private let accent = ZapTheme.accent

    var body: some View {
        VStack(spacing: 0) {
            // Header — avatar + name + tier
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accent)
                    ChibiHero(kind: hero, accent: accent, size: 36)
                }
                .frame(width: 36, height: 36)
                .clipped()

                VStack(alignment: .leading, spacing: 1) {
                    Text(username.isEmpty ? "Reader" : username)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(tone.text)
                        .kerning(-0.15)
                    Text(email)
                        .font(.system(size: 11.5))
                        .foregroundStyle(tone.textDim)
                        .lineLimit(1)
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

                            Text(r.localLabel(s))
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

            // Backend IP
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 11))
                        .foregroundStyle(tone.textDim)
                    Text("BACKEND IP")
                        .font(ZapTheme.archivoBlack(9))
                        .kerning(0.5)
                        .foregroundStyle(tone.textDim)
                    Spacer()
                    Circle()
                        .fill(connectionState.dotColor)
                        .frame(width: 6, height: 6)
                }
                TextField("192.168.1.1:8000", text: $backendIP)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tone.text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(tone.field)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tone.chipBorder, lineWidth: 0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().overlay(tone.line)

            // Load comic
            Button {
                menuOpen = false
                onLoadComic()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 15))
                        .foregroundStyle(accent)
                        .frame(width: 22, height: 22)
                    Text("Load Comic")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .kerning(-0.15)
                    Spacer()
                    Text("CBZ / ZIP")
                        .font(ZapTheme.archivoBlack(9))
                        .kerning(0.4)
                        .foregroundStyle(tone.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(tone.chipBg)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)

            Divider().overlay(tone.line)

            // Logout
            Button {
                menuOpen = false
                try? FirebaseAuth.Auth.auth().signOut()
                onSignOut()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: "#F04E2A"))
                        .frame(width: 22, height: 22)
                    Text(s.logOut)
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
    let s: ZapStrings
    var onOpenLibraryComic: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent
    private var library: LibraryStore { LibraryStore.shared }

    private var mockComics: [MockComic] {
        switch route {
        case .reading:    return MockData.continueReading
        case .favourites: return MockData.covers.filter { $0.isFavourite }
        case .read:       return MockData.covers.filter { $0.progress >= 1.0 }
        default:          return []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.localLabel(s))
                    .font(ZapTheme.archivoBlack(26))
                    .foregroundStyle(tone.text)
                    .textCase(.uppercase)
                    .kerning(-0.5)
                Text(route.localSubtitle(s))
                    .font(.system(size: 13))
                    .foregroundStyle(tone.textDim)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            if route == .library {
                LibraryGridView(library: library, tone: tone, onOpen: onOpenLibraryComic)
            } else if mockComics.isEmpty {
                Text(s.nothingHere)
                    .font(.system(size: 14))
                    .foregroundStyle(tone.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 60)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(mockComics) { comic in
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
    let s: ZapStrings
    let onActivate: () -> Void
    private let accent = ZapTheme.accent

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(tone.textDim)
                Text(s.searchPlaceholder)
                    .font(.system(size: 15))
                    .foregroundStyle(tone.textMuted)
                Spacer()
                Text("⌘K")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tone.textMuted)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(tone.chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(tone.chipBorder, lineWidth: 0.5))
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(tone.field)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tone.chipBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Publisher chips
private struct PublisherChips: View {
    let tone: ZapTheme.Tone
    let s: ZapStrings
    @Binding var active: String
    private let accent = ZapTheme.accent
    private let publishers = ["Home", "All", "DC", "Marvel", "Indie Week", "Europe Comics", "Other"]

    private let categories = ["All", "DC", "Marvel", "Indie Week", "Europe Comics", "Other"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Home — icon pill, always first, distinct from browse chips
                let homeOn = active == "Home"
                Button { active = "Home" } label: {
                    HStack(spacing: 5) {
                        Image(systemName: homeOn ? "house.fill" : "house")
                            .font(.system(size: 11, weight: .bold))
                        Text("HOME")
                            .font(ZapTheme.archivoBlack(11)).kerning(0.6)
                    }
                    .foregroundStyle(homeOn ? .white : tone.text)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(homeOn ? accent : tone.chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(homeOn ? accent : tone.chipBorder, lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                // Divider
                Rectangle()
                    .fill(tone.textMuted.opacity(0.4))
                    .frame(width: 1.5, height: 26)
                    .padding(.horizontal, 10)

                // Browse category chips
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { pub in
                        let on = pub == active
                        Button { active = pub } label: {
                            Text(pub == "All" ? s.allPublishers : pub)
                                .font(ZapTheme.archivoBlack(11)).kerning(0.4).textCase(.uppercase)
                                .foregroundStyle(on ? .white : tone.textDim)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(on ? accent : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(on ? accent : tone.chipBorder, lineWidth: 0.5))
                        }.buttonStyle(.plain)
                    }
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
    let s: ZapStrings
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
                    Text(s.pickUpWhere)
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
                        Text("\(s.issueWord) \(comic.issue) · \(s.pageWord) \(comic.currentPage) \(s.ofWord) \(comic.pages) · \(Int(comic.progress*100))%")
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
                            Text(s.resumeBtn).font(ZapTheme.archivoBlack(11)).kerning(0.4).textCase(.uppercase)
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
    let s: ZapStrings
    var tag: String? = nil
    private let accent = ZapTheme.accent
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(title)
                .font(ZapTheme.archivoBlack(18)).textCase(.uppercase).kerning(-0.2)
                .foregroundStyle(tone.text)
            if let tag {
                Text("  |  ")
                    .font(ZapTheme.archivoBlack(14)).foregroundStyle(tone.textMuted)
                Text(tag.uppercased())
                    .font(ZapTheme.archivoBlack(18)).kerning(-0.2)
                    .foregroundStyle(accent)
            }
            Spacer()
            Button(s.seeAll) { }.font(.system(size: 13, weight: .semibold)).foregroundStyle(accent).kerning(-0.1)
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
    let comics: [MockComic]; let tone: ZapTheme.Tone; let s: ZapStrings
    private let accent = ZapTheme.accent
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(comics.enumerated()), id: \.element.id) { index, comic in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
                            ComicCoverCard(comic: comic, width: 124, height: 174, accent: accent)
                            if index == 0 {
                                Text(s.newBadge).font(ZapTheme.archivoBlack(8)).kerning(0.6)
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
    let comics: [MockComic]; let tone: ZapTheme.Tone; let s: ZapStrings
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
                            Text("\(s.downloaded) · \(String(format: "%.1f", comic.fileSizeMB)) MB · \(comic.publisher)").font(.system(size: 12)).foregroundStyle(tone.textDim)
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

// MARK: - Server connect prompt
private struct ServerConnectPrompt: View {
    let tone: ZapTheme.Tone
    let connectionState: ConnectionState
    let s: ZapStrings
    let onTap: () -> Void
    private let accent = ZapTheme.accent

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text(s.offlineTitle)
                        .font(ZapTheme.archivoBlack(22))
                        .foregroundStyle(tone.text)
                        .textCase(.uppercase)
                        .kerning(-0.4)

                    Text(s.offlineSubtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(tone.textDim)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Button(action: onTap) {
                    HStack(spacing: 8) {
                        if connectionState == .checking {
                            ProgressView().tint(.white).scaleEffect(0.8)
                            Text(s.connectingLabel)
                        } else {
                            Text(s.connectNow)
                        }
                    }
                    .font(ZapTheme.archivoBlack(13))
                    .kerning(0.3)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(connectionState == .checking ? accent.opacity(0.5) : accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(connectionState == .checking)

                HStack(spacing: 6) {
                    Rectangle().fill(tone.line).frame(height: 0.5)
                    Text(s.orDivider).font(.system(size: 12)).foregroundStyle(tone.textMuted).fixedSize()
                    Rectangle().fill(tone.line).frame(height: 0.5)
                }
                .padding(.horizontal, 24)

                Text(s.offlineFooter)
                    .font(.system(size: 13))
                    .foregroundStyle(tone.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 36)
            Spacer()
        }
    }
}

// MARK: - Infinite marquee row
// Pre-fetches ALL images before showing the animated strip so there are zero
// mid-animation state changes that could reset the repeatForever offset.
// Touch pauses the scroll; releasing resumes from the same position.
private struct MarqueeComicsRow: View {
    let comics: [APIComic]
    let scrollLeft: Bool
    let tone: ZapTheme.Tone
    var onSelect: (APIComic) -> Void = { _ in }
    private let accent = ZapTheme.accent
    private let cardW: CGFloat = 128
    private let cardH: CGFloat = 188
    private let gap:   CGFloat = 10
    private var step:  CGFloat { cardW + gap }
    private var loopW: CGFloat { step * CGFloat(max(comics.count, 1)) }
    private var duration: Double { Double(max(comics.count, 1)) * 12.0 }
    private var startX: CGFloat { scrollLeft ?  20 : -(loopW - 20) }
    private var endX:   CGFloat { scrollLeft ? -(loopW - 20) : 20 }

    @State private var offset: CGFloat = 0
    @State private var images: [String: UIImage] = [:]
    @State private var imagesReady = false
    @State private var shimmer = false
    @State private var isPaused = false
    @State private var pausedAt: CGFloat = 0
    @State private var animStartTime: Date = .now
    @State private var dragTranslation: CGFloat = 0

    var body: some View {
        Group {
            if !imagesReady || comics.isEmpty {
                skeleton.transition(.opacity)
            } else {
                Color.clear
                    .overlay(alignment: .leading) {
                        HStack(spacing: gap) {
                            ForEach(Array((comics + comics).enumerated()), id: \.offset) { _, comic in
                                MarqueeComicCard(
                                    comic: comic, accent: accent,
                                    width: cardW, height: cardH,
                                    image: comic.coverImage.flatMap { images[$0] }
                                )
                                .onTapGesture { onSelect(comic) }
                            }
                        }
                        .offset(x: offset + dragTranslation)
                    }
                    .clipped()
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isPaused { pauseScroll() }
                                dragTranslation = value.translation.width
                            }
                            .onEnded { value in
                                pausedAt += value.translation.width
                                dragTranslation = 0
                                offset = pausedAt
                                resumeScroll()
                            }
                    )
                    .onAppear {
                        offset = startX
                        animStartTime = Date().addingTimeInterval(0.5)
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(500))
                            guard !isPaused else { return }
                            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                                offset = endX
                            }
                        }
                    }
                    .transition(.opacity)
            }
        }
        .frame(height: cardH)
        .animation(.easeInOut(duration: 0.3), value: imagesReady)
        .task(id: comics.map { $0.coverImage ?? "" }.joined()) {
            await MainActor.run { imagesReady = false; images = [:] }
            await prefetchImages()
        }
    }

    // Estimate the current animated position based on elapsed time
    private var currentLiveX: CGFloat {
        let elapsed = max(0, Date().timeIntervalSince(animStartTime))
        let t = elapsed.truncatingRemainder(dividingBy: duration) / duration
        return startX + (endX - startX) * CGFloat(t)
    }

    private func pauseScroll() {
        guard !isPaused else { return }
        isPaused = true
        pausedAt = currentLiveX
        withAnimation(.none) { offset = pausedAt }
    }

    private func resumeScroll() {
        guard isPaused else { return }
        isPaused = false
        let totalDist = abs(Double(endX - startX))
        let remaining = abs(Double(endX - pausedAt))
        let remainDur = max(0.05, duration * remaining / totalDist)
        withAnimation(.linear(duration: remainDur)) { offset = endX }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(remainDur))
            guard !isPaused else { return }
            offset = startX
            animStartTime = Date()
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                offset = endX
            }
        }
    }

    private var skeleton: some View {
        // Mirror the real marquee layout so the cards pin to the leading edge.
        Color.clear
            .overlay(alignment: .leading) {
                HStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { i in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 9).fill(tone.chipBg)

                            VStack(alignment: .leading, spacing: 5) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(tone.textMuted.opacity(0.5))
                                    .frame(width: cardW * 0.45, height: 7)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(tone.textMuted.opacity(0.28))
                                    .frame(width: cardW - 12, height: 7)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(tone.textMuted.opacity(0.2))
                                    .frame(width: cardW * 0.65, height: 7)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 6).padding(.vertical, 7)
                            .background(Color(hex: "#0d0d14").opacity(0.65))
                        }
                        .frame(width: cardW, height: cardH)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .opacity(shimmer ? (i % 2 == 0 ? 0.4 : 0.55) : (i % 2 == 0 ? 0.85 : 0.7))
                        .animation(
                            .easeInOut(duration: 0.85)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.12),
                            value: shimmer
                        )
                    }
                }
                .padding(.leading, 20)
            }
            .clipped()
            .onAppear { shimmer = true }
    }

    private func prefetchImages() async {
        var collected: [String: UIImage] = [:]
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for comic in comics {
                guard let urlStr = comic.coverImage,
                      let url = URL(string: urlStr) else { continue }
                group.addTask {
                    guard let (data, _) = try? await URLSession.shared.data(from: url),
                          let img = UIImage(data: data) else { return (urlStr, nil) }
                    return (urlStr, img)
                }
            }
            for await (urlStr, img) in group {
                if let img { collected[urlStr] = img }
            }
        }
        await MainActor.run {
            images = collected
            imagesReady = true
        }
    }
}

// MARK: - Marquee card — same visual design as SearchResultCard
private struct MarqueeComicCard: View {
    let comic: APIComic
    let accent: Color
    let width: CGFloat
    let height: CGFloat
    let image: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(width: width, height: height)
                .overlay(Image(systemName: "book.closed")
                    .font(.system(size: 26)).foregroundStyle(.white.opacity(0.12)))
            }

            // Dark strip matching SearchResultCard
            VStack(alignment: .leading, spacing: 4) {
                if let pub = comic.publisher {
                    Text(pub.uppercased())
                        .font(.system(size: 9, weight: .black)).kerning(0.5)
                        .foregroundStyle(accent).lineLimit(1)
                }
                Text(comic.title ?? "—")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase).kerning(-0.1).lineLimit(2).truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 6).padding(.vertical, 6)
            .background(Color(hex: "#0d0d14").opacity(0.95))
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(alignment: .topTrailing) {
            if let size = comic.size {
                Text(size)
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(accent).clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(6)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Browse view (publisher chip results)
private struct BrowseView: View {
    let publisher: String
    let backendIP: String
    let tone: ZapTheme.Tone
    var onSelect: (APIComic) -> Void = { _ in }
    private let accent = ZapTheme.accent

    @State private var results: [APIComic] = []
    @State private var pagination: [APIPaginationItem] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var browseTask: Task<Void, Never>?

    var body: some View {
        Group {
            if isLoading && results.isEmpty {
                ProgressView().tint(accent)
                    .frame(maxWidth: .infinity).padding(.top, 60)
            } else if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 32)).foregroundStyle(tone.textMuted)
                    Text("No comics found")
                        .font(.system(size: 14)).foregroundStyle(tone.textMuted)
                }
                .frame(maxWidth: .infinity).padding(.top, 60)
            } else {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(results) { comic in
                        Button { onSelect(comic) } label: {
                            BrowseComicCard(comic: comic, tone: tone, accent: accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14)

                if !pagination.isEmpty { paginationBar }
            }
        }
        .onAppear { load(page: 1) }
        .onChange(of: publisher) { _, _ in results = []; pagination = []; load(page: 1) }
    }

    private var paginationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(pagination) { item in
                    switch item {
                    case .page(let n, _):
                        Button { load(page: n) } label: { pageChip(label: "\(n)", active: false) }
                            .buttonStyle(.plain)
                    case .current(let n):
                        pageChip(label: "\(n)", active: true)
                    case .dots:
                        Text("…").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(tone.textMuted).frame(width: 28, height: 32)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20).padding(.bottom, 4)
    }

    private func pageChip(label: String, active: Bool) -> some View {
        Text(label)
            .font(ZapTheme.archivoBlack(12)).kerning(0.2)
            .foregroundStyle(active ? .white : tone.text)
            .frame(minWidth: 32, minHeight: 32).padding(.horizontal, 6)
            .background(active ? accent : tone.chipBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(active ? accent : tone.chipBorder, lineWidth: 0.5))
    }

    private func load(page: Int) {
        browseTask?.cancel()
        isLoading = true
        currentPage = page
        browseTask = Task {
            do {
                let response = try await BackendService(ip: backendIP).browse(category: publisher, page: page)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = response.comics
                    pagination = response.pagination
                    currentPage = response.page
                    isLoading = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Browse comic card
private struct BrowseComicCard: View {
    let comic: APIComic
    let tone: ZapTheme.Tone
    let accent: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .bottom) {
            coverImage
            VStack(alignment: .leading, spacing: 4) {
                if let pub = comic.publisher {
                    Text(pub.uppercased())
                        .font(.system(size: 9, weight: .black)).kerning(0.5)
                        .foregroundStyle(accent).lineLimit(1)
                }
                Text(comic.title ?? "—")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.9))
                    .textCase(.uppercase).kerning(-0.1)
                    .lineLimit(2).truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 4).padding(.vertical, 5)
            .background(scheme == .dark ? Color(hex: "#0d0d14").opacity(0.95) : Color(hex: "#1a2040").opacity(0.93))

            if let size = comic.size {
                VStack {
                    HStack {
                        Spacer()
                        Text(size)
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(accent).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .shadow(color: .black.opacity(0.45), radius: 6, x: 0, y: 3)
    }

    private var coverImage: some View {
        Group {
            if let urlString = comic.coverImage, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                    default: placeholder
                    }
                }
            } else { placeholder }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay(Image(systemName: "book.closed").font(.system(size: 20)).foregroundStyle(.white.opacity(0.12)))
    }
}

// MARK: - Library grid (full-page library sub-view)
private struct LibraryGridView: View {
    let library: LibraryStore
    let tone: ZapTheme.Tone
    var onOpen: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent
    private let colW: CGFloat = (UIScreen.main.bounds.width - 40 - 24) / 3

    var body: some View {
        if library.comics.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.to.line.circle")
                    .font(.system(size: 36)).foregroundStyle(tone.textMuted)
                Text("NO DOWNLOADS YET")
                    .font(ZapTheme.archivoBlack(14)).foregroundStyle(tone.text)
                Text("Download comics from the detail page\nand they'll appear here.")
                    .font(.system(size: 13)).foregroundStyle(tone.textDim)
                    .multilineTextAlignment(.center).lineSpacing(3)
            }
            .frame(maxWidth: .infinity).padding(.top, 60).padding(.horizontal, 32)
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(library.comics) { comic in
                    Button { onOpen(comic) } label: {
                        LibraryComicCard(comic: comic, library: library,
                                         width: colW, height: colW * 1.4, accent: accent, tone: tone)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct LibraryComicCard: View {
    let comic: LibraryComic
    let library: LibraryStore
    let width: CGFloat
    let height: CGFloat
    let accent: Color
    let tone: ZapTheme.Tone

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                Group {
                    if let img = library.coverImage(for: comic) {
                        Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        .overlay(Image(systemName: "book.closed")
                            .font(.system(size: 22)).foregroundStyle(.white.opacity(0.12)))
                    }
                }
                .frame(width: width, height: height).clipped()

                VStack(alignment: .leading, spacing: 3) {
                    if let pub = comic.publisher {
                        Text(pub.uppercased()).font(.system(size: 8, weight: .black))
                            .foregroundStyle(accent).lineLimit(1)
                    }
                    Text(comic.title).font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                        .textCase(.uppercase).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 5).padding(.vertical, 5)
                .background(Color(hex: "#0d0d14").opacity(0.95))
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)

            Text(comic.title).font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tone.text).lineLimit(1)
            if let yr = comic.year {
                Text(yr).font(.system(size: 9)).foregroundStyle(tone.textDim)
            }
        }
    }
}

// MARK: - Inline recent-downloads row on home feed
private struct DownloadedComicsRow: View {
    let library: LibraryStore
    let tone: ZapTheme.Tone
    var onOpen: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent

    var body: some View {
        if library.comics.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.to.line.circle")
                    .font(.system(size: 18)).foregroundStyle(tone.textMuted)
                Text("Downloads will appear here after you save a comic.")
                    .font(.system(size: 13)).foregroundStyle(tone.textMuted).lineSpacing(2)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(library.comics.prefix(10)) { comic in
                        Button { onOpen(comic) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ZStack(alignment: .bottom) {
                                    Group {
                                        if let img = library.coverImage(for: comic) {
                                            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            LinearGradient(
                                                colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                                                startPoint: .topLeading, endPoint: .bottomTrailing)
                                        }
                                    }
                                    .frame(width: 80, height: 112).clipped()

                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.7)],
                                        startPoint: .center, endPoint: .bottom)
                                }
                                .frame(width: 80, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Text(comic.title).font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(tone.text).lineLimit(1).frame(width: 80, alignment: .leading)
                                Text(comic.publisher ?? comic.year ?? "—")
                                    .font(.system(size: 9)).foregroundStyle(tone.textDim)
                            }
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview("Dark")  { HomeView().preferredColorScheme(.dark) }
#Preview("Light") { HomeView().preferredColorScheme(.light) }
