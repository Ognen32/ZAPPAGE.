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
    var badge: String? { nil }

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
    @State private var readerComicID: String = ""
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
            CBZReaderView(pages: cbzPages, comicID: readerComicID)
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
            if let latest = library.comics
                .filter({ !library.isRead(id: $0.id) && (library.readingProgress[$0.id]?.total ?? 0) > 0 })
                .sorted(by: { (library.readingProgress[$0.id]?.lastReadAt ?? .distantPast) > (library.readingProgress[$1.id]?.lastReadAt ?? .distantPast) })
                .first {
                FeaturedReadingCard(comic: latest, library: library, tone: tone) { openLibraryComic(latest) }
                    .id(latest.id)
            } else {
                FeaturedHeroCard(comic: MockData.featured, tone: tone, s: s)
            }
            HomeSectionHeader(title: s.continueReading, tone: tone, s: s)
            RealContinueReadingRow(library: library, tone: tone, onOpen: openLibraryComic)
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
            await MainActor.run { cbzPages = pages; readerComicID = comic.id; showReader = true }
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
        HStack(spacing: 14) {
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
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
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
    private var library: LibraryStore { LibraryStore.shared }
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

                            if !active {
                                let badgeText: String? = r == .library
                                    ? (library.comics.isEmpty ? nil : "\(library.comics.count)")
                                    : r.badge
                                if let badge = badgeText {
                                    Text(badge)
                                        .font(ZapTheme.archivoBlack(10))
                                        .kerning(0.3)
                                        .foregroundStyle(tone.textDim)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(tone.chipBg)
                                        .clipShape(Capsule())
                                }
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
                if route == .library {
                    let count = library.comics.count
                    Text(count == 0
                         ? "No comics downloaded yet"
                         : "\(count) \(count == 1 ? "comic" : "comics") · \(library.totalSizeFormatted)")
                        .font(.system(size: 13))
                        .foregroundStyle(tone.textDim)
                } else if route == .favourites {
                    let count = library.comics.filter { library.isFavourite(id: $0.id) }.count
                    Text(count == 0
                         ? "Tap ♥ on any downloaded comic"
                         : "\(count) \(count == 1 ? "comic" : "comics") saved")
                        .font(.system(size: 13))
                        .foregroundStyle(tone.textDim)
                } else if route == .reading {
                    let count = library.comics.filter {
                        !library.isRead(id: $0.id) &&
                        (library.readingProgress[$0.id]?.total ?? 0) > 0
                    }.count
                    Text(count == 0 ? "No comics in progress" : "\(count) in progress")
                        .font(.system(size: 13))
                        .foregroundStyle(tone.textDim)
                } else if route == .read {
                    let count = library.comics.filter { library.isRead(id: $0.id) }.count
                    Text(count == 0 ? "No comics marked as read" : "\(count) \(count == 1 ? "comic" : "comics") finished")
                        .font(.system(size: 13))
                        .foregroundStyle(tone.textDim)
                } else {
                    Text(route.localSubtitle(s))
                        .font(.system(size: 13))
                        .foregroundStyle(tone.textDim)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            if route == .library {
                LibraryGridView(library: library, tone: tone, onOpen: onOpenLibraryComic)
            } else if route == .favourites {
                FavouritesView(library: library, tone: tone, onOpen: onOpenLibraryComic)
            } else if route == .read {
                ReadComicsView(library: library, tone: tone, onOpen: onOpenLibraryComic)
            } else if route == .reading {
                CurrentlyReadingView(library: library, tone: tone, onOpen: onOpenLibraryComic)
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

// MARK: - Featured reading card (tiled brick backdrop + dominant-colour glow)
private struct FeaturedReadingCard: View {
    let comic: LibraryComic
    let library: LibraryStore
    let tone: ZapTheme.Tone
    let onOpen: () -> Void

    // Image loaded once — avoids repeated synchronous disk reads during render
    @State private var cover:     UIImage? = nil
    @State private var glowColor: Color   = ZapTheme.accent
    @State private var rock       = false
    @State private var glowPulse  = false
    @State private var pulseDot   = false
    @State private var shimmer    = false
    @State private var tileDrift: CGFloat = 0

    private let coverW: CGFloat = 148
    private let coverH: CGFloat = 207
    private let cardW:  CGFloat = UIScreen.main.bounds.width - 40
    private let tW:     CGFloat = 64   // tile cell width
    private let tH:     CGFloat = 90   // tile cell height (2:3 ≈ comic ratio)
    private let tGap:   CGFloat = 6

    private var prog: LocalReadingProgress? { library.readingProgress[comic.id] }
    private var pct: CGFloat {
        guard let p = prog, p.total > 0 else { return 0 }
        return min(1, CGFloat(p.page + 1) / CGFloat(p.total))
    }

    var body: some View {
        // Background layers — no interaction, no text
        ZStack {
            // 1 ── Tiled brick-pattern backdrop (cover repeating, drifting)
            if let img = cover { tileGrid(img) }
            else { Color(hex: "#0d0d18") }

            // 2 ── Colour-bloom wash (same cover, blurred + saturated)
            if let img = cover {
                Image(uiImage: img)
                    .resizable().aspectRatio(contentMode: .fill)
                    .blur(radius: 36).saturation(1.8).opacity(0.28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            }

            // 3 ── Dark scrim
            Color.black.opacity(0.52).allowsHitTesting(false)

            // 4 ── Featured cover (right) — .fit so small images never distort
            if let img = cover {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: coverW, height: coverH)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .rotationEffect(.degrees(rock ? 1.2 : -1.2))
                    .shadow(color: glowColor.opacity(glowPulse ? 0.95 : 0.50),
                            radius: glowPulse ? 30 : 16)
                    .shadow(color: .black.opacity(0.55), radius: 8, x: 2, y: 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 20).padding(.bottom, 22)
                    .allowsHitTesting(false)
            }

            // 5 ── Bottom gradient (makes left-side text legible)
            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.00),
                    .init(color: .black.opacity(0.22),  location: 0.32),
                    .init(color: .black.opacity(0.88),  location: 0.66),
                    .init(color: .black.opacity(0.97),  location: 1.00)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)

            // 6 ── Shimmer ray (fires via .task loop every ~5 s)
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .white.opacity(0.07), .white.opacity(0.17),
                             .white.opacity(0.07), .clear],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: 110).rotationEffect(.degrees(22))
                .offset(x: shimmer ? cardW + 150 : -(cardW + 110))
                .allowsHitTesting(false)
        }
        .frame(height: 260)
        // Content overlay — always on top of all background layers
        .overlay(alignment: .topLeading) {
            // TOP — live badge
            HStack(spacing: 6) {
                Circle().fill(glowColor).frame(width: 6, height: 6)
                    .opacity(pulseDot ? 0.28 : 1.0)
                    .scaleEffect(pulseDot ? 0.58 : 1.0)
                Text("CONTINUE WHERE YOU LEFT OFF")
                    .font(ZapTheme.archivoBlack(12)).kerning(0.8)
                    .foregroundStyle(.white)
            }
            .padding(18)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            // BOTTOM — publisher · title · progress · RESUME button
            VStack(alignment: .leading, spacing: 6) {
                if let pub = comic.publisher {
                    Text(pub.uppercased())
                        .font(.system(size: 11, weight: .black)).kerning(0.5)
                        .foregroundStyle(glowColor)
                }
                Text(comic.title)
                    .font(ZapTheme.archivoBlack(22))
                    .foregroundStyle(.white)
                    .textCase(.uppercase).kerning(-0.6).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.7), radius: 0, x: 0, y: 2)

                if let p = prog, p.total > 0 {
                    VStack(alignment: .leading, spacing: 5) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.18))
                                RoundedRectangle(cornerRadius: 2).fill(glowColor)
                                    .shadow(color: glowColor, radius: 5)
                                    .frame(width: geo.size.width * pct)
                            }
                        }
                        .frame(height: 4)
                        Text("Page \(p.page + 1) of \(p.total)  ·  \(Int(pct * 100))%")
                            .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.55))
                        Button(action: onOpen) {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill").font(.system(size: 9, weight: .bold))
                                Text("RESUME").font(ZapTheme.archivoBlack(10)).kerning(0.5)
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .white.opacity(0.3), radius: 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: cardW * 0.57, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: glowColor.opacity(glowPulse ? 0.72 : 0.30),
                radius: glowPulse ? 34 : 18, x: 0, y: 10)
        .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 5)
        .padding(.horizontal, 20).padding(.top, 14)
        .onAppear {
            // Load image synchronously (small thumbnail on disk — fast)
            cover = library.coverImage(for: comic)
            if let img = cover {
                Task.detached(priority: .utility) {
                    let c = extractDominantColor(from: img)
                    await MainActor.run { glowColor = c }
                }
            }
            // Animations
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true))  { rock      = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true))  { glowPulse = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true))  { pulseDot  = true }
            // Tile drift: moves exactly one tile width → seamless loop
            withAnimation(.linear(duration: 14.0).repeatForever(autoreverses: false))   { tileDrift = -(tW + tGap) }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.78)) { shimmer = true }
                try? await Task.sleep(for: .milliseconds(950))
                shimmer = false
                try? await Task.sleep(for: .seconds(4.3))
            }
        }
    }

    // Diagonal brick-pattern tiling — 10 cols × 6 rows, edge-to-edge coverage.
    // Gradient mask: fully invisible on the left, fully opaque on the right.
    @ViewBuilder
    private func tileGrid(_ img: UIImage) -> some View {
        HStack(alignment: .top, spacing: tGap) {
            ForEach(0..<10, id: \.self) { col in
                VStack(spacing: tGap) {
                    ForEach(0..<6, id: \.self) { _ in
                        Image(uiImage: img)
                            .resizable()
                            .interpolation(.medium)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: tW, height: tH)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
                .offset(y: col.isMultiple(of: 2) ? 0 : (tH + tGap) / 2)
            }
        }
        .offset(x: tileDrift)
        .rotationEffect(.degrees(-10), anchor: .center)
        .opacity(0.68)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.00),
                    .init(color: .black.opacity(0.55),  location: 0.07),
                    .init(color: .black.opacity(0.88),  location: 0.16),
                    .init(color: .black,               location: 0.26),
                    .init(color: .black,               location: 1.00)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// Samples a 50×50 downsample of the image, skips near-black/white/grey pixels,
// buckets remaining colours and returns the most frequent saturated one.
private func extractDominantColor(from image: UIImage) -> Color {
    guard let cg = image.cgImage else { return ZapTheme.accent }
    let side = 50
    var px = [UInt8](repeating: 0, count: side * side * 4)
    guard let ctx = CGContext(data: &px, width: side, height: side,
                              bitsPerComponent: 8, bytesPerRow: side * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        return ZapTheme.accent
    }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

    var buckets: [UInt32: (n: Int, r: Int, g: Int, b: Int)] = [:]
    for i in stride(from: 0, to: px.count, by: 4) {
        let r = Int(px[i]), g = Int(px[i+1]), b = Int(px[i+2]), a = Int(px[i+3])
        guard a > 128 else { continue }
        let hi = max(r, g, b), lo = min(r, g, b)
        let brightness  = Double(hi) / 255
        let saturation  = hi > 0 ? Double(hi - lo) / Double(hi) : 0
        guard brightness > 0.15 && brightness < 0.88 && saturation > 0.22 else { continue }
        // 5-bit quantise per channel → 32 768 possible buckets
        let key = (UInt32(r >> 3) << 10) | (UInt32(g >> 3) << 5) | UInt32(b >> 3)
        if let e = buckets[key] { buckets[key] = (e.n+1, e.r+r, e.g+g, e.b+b) }
        else                    { buckets[key] = (1, r, g, b) }
    }
    guard let top = buckets.values.max(by: { $0.n < $1.n }), top.n > 0 else { return ZapTheme.accent }
    let n = Double(top.n)
    return Color(red: Double(top.r)/n/255, green: Double(top.g)/n/255, blue: Double(top.b)/n/255)
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

// MARK: - Real continue reading row (live library data)
private struct RealContinueReadingRow: View {
    let library: LibraryStore
    let tone: ZapTheme.Tone
    var onOpen: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent
    private let cardW: CGFloat = 110
    private let cardH: CGFloat = 154

    private var inProgress: [LibraryComic] {
        library.comics
            .filter { !library.isRead(id: $0.id) && (library.readingProgress[$0.id]?.total ?? 0) > 0 }
            .sorted {
                (library.readingProgress[$0.id]?.lastReadAt ?? .distantPast) >
                (library.readingProgress[$1.id]?.lastReadAt ?? .distantPast)
            }
    }

    var body: some View {
        if inProgress.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "book").font(.system(size: 16)).foregroundStyle(tone.textMuted)
                Text("Open any downloaded comic to start reading.")
                    .font(.system(size: 12)).foregroundStyle(tone.textMuted).lineSpacing(2)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(inProgress) { comic in
                        VStack(alignment: .leading, spacing: 5) {
                            Button { onOpen(comic) } label: {
                                ZStack(alignment: .bottom) {
                                    Group {
                                        if let img = library.coverImage(for: comic) {
                                            Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                                            .overlay(Image(systemName: "book.closed")
                                                .font(.system(size: 20)).foregroundStyle(.white.opacity(0.12)))
                                        }
                                    }
                                    .frame(width: cardW, height: cardH).clipped()

                                    LinearGradient(
                                        stops: [.init(color: .clear, location: 0.38),
                                                .init(color: .black.opacity(0.9), location: 1.0)],
                                        startPoint: .top, endPoint: .bottom
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        if let pub = comic.publisher {
                                            Text(pub.uppercased())
                                                .font(.system(size: 7, weight: .black)).kerning(0.4)
                                                .foregroundStyle(accent).lineLimit(1)
                                        }
                                        Text(comic.title)
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundStyle(.white).lineLimit(2)

                                        if let prog = library.readingProgress[comic.id], prog.total > 0 {
                                            let pct = min(1.0, CGFloat(prog.page + 1) / CGFloat(prog.total))
                                            HStack(spacing: 4) {
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        Capsule().fill(Color.white.opacity(0.2))
                                                        Capsule().fill(accent).frame(width: geo.size.width * pct)
                                                    }
                                                }
                                                .frame(height: 2.5)
                                                Text("\(Int(pct * 100))%")
                                                    .font(.system(size: 7, weight: .bold))
                                                    .foregroundStyle(.white.opacity(0.7)).fixedSize()
                                            }
                                            .padding(.top, 1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 7).padding(.bottom, 7)
                                }
                                .frame(width: cardW, height: cardH)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
                            }
                            .buttonStyle(.plain)

                            if let date = library.readingProgress[comic.id]?.lastReadAt {
                                Text(relativeTime(date))
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(tone.textMuted)
                                    .frame(width: cardW, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let days = Date().timeIntervalSince(date) / 86400
        switch days {
        case ..<0.5:   return "Just now"
        case ..<1:     return "Today"
        case ..<2:     return "1 day ago"
        case ..<7:     return "\(Int(days)) days ago"
        case ..<14:    return "1 week ago"
        case ..<21:    return "2 weeks ago"
        case ..<30:    return "3 weeks ago"
        case ..<60:    return "1 month ago"
        case ..<90:    return "2 months ago"
        case ..<180:   return "3 months ago"
        case ..<270:   return "6 months ago"
        case ..<365:   return "9 months ago"
        case ..<730:   return "1 year ago"
        default:       return "Over 1 year ago"
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

// MARK: - Favourites (grouped by publisher)
private struct FavouritesView: View {
    let library: LibraryStore
    let tone: ZapTheme.Tone
    var onOpen: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent
    private let colW: CGFloat = (UIScreen.main.bounds.width - 40 - 24) / 3
    @State private var comicToDelete: LibraryComic? = nil

    private var favourites: [LibraryComic] {
        library.comics.filter { library.isFavourite(id: $0.id) }
    }

    private var grouped: [(label: String, color: Color, comics: [LibraryComic])] {
        let knownSlugs = ["dc", "marvel"]
        var result: [(String, Color, [LibraryComic])] = []
        for slug in knownSlugs {
            let group = favourites.filter { $0.publisher?.lowercased().contains(slug) == true }
            if !group.isEmpty { result.append((slug.uppercased(), pubColor(slug), group)) }
        }
        let other = favourites.filter { c in
            guard let p = c.publisher?.lowercased() else { return true }
            return !knownSlugs.contains(where: { p.contains($0) })
        }
        if !other.isEmpty { result.append(("Other", accent, other)) }
        return result
    }

    private let cardW: CGFloat = 160
    private let cardH: CGFloat = 224

    var body: some View {
        if favourites.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "heart")
                    .font(.system(size: 44))
                    .foregroundStyle(accent.opacity(0.3))
                Text("NO FAVOURITES YET")
                    .font(ZapTheme.archivoBlack(15))
                    .foregroundStyle(tone.text)
                Text("Tap the ♥ on any downloaded comic\nto save it here.")
                    .font(.system(size: 13))
                    .foregroundStyle(tone.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity).padding(.top, 80).padding(.horizontal, 40)
        } else {
            VStack(alignment: .leading, spacing: 32) {
                ForEach(grouped, id: \.label) { section in
                    VStack(alignment: .leading, spacing: 14) {
                        // Section header
                        HStack(alignment: .center, spacing: 10) {
                            // Coloured left bar
                            RoundedRectangle(cornerRadius: 2)
                                .fill(section.color)
                                .frame(width: 3, height: 18)

                            Text(section.label)
                                .font(ZapTheme.archivoBlack(15))
                                .kerning(-0.3)
                                .foregroundStyle(tone.text)

                            Text("\(section.comics.count)")
                                .font(ZapTheme.archivoBlack(10))
                                .foregroundStyle(section.color)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(section.color.opacity(0.15))
                                .clipShape(Capsule())

                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Horizontal scroll of taller cards
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(section.comics) { comic in
                                    FavouriteCard(
                                        comic: comic, library: library,
                                        width: cardW, height: cardH,
                                        accentColor: section.color,
                                        tone: tone,
                                        onOpen: { onOpen(comic) },
                                        onDelete: { comicToDelete = comic },
                                        onToggleRead: { library.toggleRead(id: comic.id) }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .alert("Delete this comic?", isPresented: .init(
                get: { comicToDelete != nil },
                set: { if !$0 { comicToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let c = comicToDelete { library.delete(c) }
                    comicToDelete = nil
                }
                Button("Cancel", role: .cancel) { comicToDelete = nil }
            } message: {
                Text("The CBZ file and cover will be removed from your library.")
            }
        }
    }

    private func pubColor(_ slug: String) -> Color {
        switch slug {
        case "dc":     return Color(hex: "#0476F2")
        case "marvel": return Color(hex: "#E2231A")
        default:       return accent
        }
    }
}

// MARK: - Favourite card (horizontal scroll item)
private struct FavouriteCard: View {
    let comic: LibraryComic
    let library: LibraryStore
    let width: CGFloat
    let height: CGFloat
    let accentColor: Color
    let tone: ZapTheme.Tone
    var onOpen: () -> Void = {}
    var onDelete: () -> Void = {}
    var onToggleRead: () -> Void = {}

    private var isFav: Bool { library.isFavourite(id: comic.id) }
    private var isRead: Bool { library.isRead(id: comic.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            ZStack(alignment: .topTrailing) {
                Button { onOpen() } label: {
                    ZStack(alignment: .bottom) {
                        Group {
                            if let img = library.coverImage(for: comic) {
                                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                                .overlay(Image(systemName: "book.closed")
                                    .font(.system(size: 28)).foregroundStyle(.white.opacity(0.12)))
                            }
                        }
                        .frame(width: width, height: height).clipped()

                        // Bottom gradient + title
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.45),
                                    .init(color: .black.opacity(0.85), location: 1.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            if let pub = comic.publisher {
                                Text(pub.uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(accentColor)
                                    .lineLimit(1)
                            }
                            Text(comic.title)
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            if let prog = library.readingProgress[comic.id], prog.total > 0 {
                                let pct = min(1.0, CGFloat(prog.page + 1) / CGFloat(prog.total))
                                HStack(spacing: 6) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.2))
                                            Capsule().fill(accentColor).frame(width: geo.size.width * pct)
                                        }
                                    }
                                    .frame(height: 3)
                                    Text("\(prog.page + 1)/\(prog.total)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.75))
                                        .fixedSize()
                                }
                                .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.bottom, 10)
                    }
                }
                .buttonStyle(.plain)

                // Heart
                Button { library.toggleFavourite(id: comic.id) } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isFav ? ZapTheme.accent : ZapTheme.accent.opacity(0.7))
                        .padding(8)
                        .background(.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: accentColor.opacity(0.25), radius: 8, x: 0, y: 4)

            // Dots menu below
            HStack {
                Spacer(minLength: 0)
                Menu {
                    Button { onOpen() } label: { Label("Read", systemImage: "book") }
                    Button { onToggleRead() } label: {
                        Label(isRead ? "Mark as Unread" : "Mark as Read",
                              systemImage: isRead ? "circle" : "checkmark.circle")
                    }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tone.textDim)
                        .frame(width: 40, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .frame(width: width)
        }
        .frame(width: width)
    }
}

// MARK: - Library grid (full-page library sub-view)
private struct LibraryGridView: View {
    let library: LibraryStore
    let tone: ZapTheme.Tone
    var onOpen: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent
    private let colW: CGFloat = (UIScreen.main.bounds.width - 40 - 24) / 3
    @State private var comicToDelete: LibraryComic? = nil

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
                    LibraryComicCard(
                        comic: comic, library: library,
                        width: colW, height: colW * 1.25, accent: accent, tone: tone,
                        onOpen: { onOpen(comic) },
                        onDelete: { comicToDelete = comic },
                        onToggleRead: { library.toggleRead(id: comic.id) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .alert("Delete this comic?", isPresented: .init(
                get: { comicToDelete != nil },
                set: { if !$0 { comicToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let c = comicToDelete { library.delete(c) }
                    comicToDelete = nil
                }
                Button("Cancel", role: .cancel) { comicToDelete = nil }
            } message: {
                Text("The CBZ file and cover will be removed from your library.")
            }
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
    var onOpen: () -> Void = {}
    var onDelete: () -> Void = {}
    var onToggleRead: () -> Void = {}

    private var isFav: Bool { library.isFavourite(id: comic.id) }
    private var isRead: Bool { library.isRead(id: comic.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Button { onOpen() } label: {
                    ZStack(alignment: .bottom) {
                        Group {
                            if let img = library.coverImage(for: comic) {
                                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                                .overlay(Image(systemName: "book.closed")
                                    .font(.system(size: 18)).foregroundStyle(.white.opacity(0.12)))
                            }
                        }
                        .frame(width: width, height: height).clipped()

                        // Gradient overlay with title + progress
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0.4),
                                    .init(color: .black.opacity(0.88), location: 1.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            if let pub = comic.publisher {
                                Text(pub.uppercased())
                                    .font(.system(size: 7, weight: .black))
                                    .foregroundStyle(accent).lineLimit(1)
                            }
                            Text(comic.title)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white).lineLimit(2)

                            if let prog = library.readingProgress[comic.id], prog.total > 0 {
                                let pct = min(1.0, CGFloat(prog.page + 1) / CGFloat(prog.total))
                                HStack(spacing: 4) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.2))
                                            Capsule().fill(accent).frame(width: geo.size.width * pct)
                                        }
                                    }
                                    .frame(height: 2.5)
                                    Text("\(prog.page + 1)/\(prog.total)")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .fixedSize()
                                }
                                .padding(.top, 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 7).padding(.bottom, 7)
                    }
                }
                .buttonStyle(.plain)

                Button { library.toggleFavourite(id: comic.id) } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isFav ? accent : accent.opacity(0.7))
                        .padding(7)
                        .background(.black.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(5)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)

            HStack {
                Spacer(minLength: 0)
                Menu {
                    Button { onOpen() } label: { Label("Read", systemImage: "book") }
                    Button { onToggleRead() } label: {
                        Label(isRead ? "Mark as Unread" : "Mark as Read",
                              systemImage: isRead ? "circle" : "checkmark.circle")
                    }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tone.textDim)
                        .frame(width: 36, height: 28)
                        .contentShape(Rectangle())
                }
            }
        }
    }
}

// MARK: - Currently Reading view
private struct CurrentlyReadingView: View {
    let library: LibraryStore
    let tone: ZapTheme.Tone
    var onOpen: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent

    private var inProgress: [LibraryComic] {
        library.comics.filter { comic in
            guard !library.isRead(id: comic.id) else { return false }
            guard let prog = library.readingProgress[comic.id] else { return false }
            return prog.total > 0
        }
        .sorted {
            let a = library.readingProgress[$0.id]?.lastReadAt ?? .distantPast
            let b = library.readingProgress[$1.id]?.lastReadAt ?? .distantPast
            return a > b
        }
    }

    var body: some View {
        if inProgress.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "book")
                    .font(.system(size: 44))
                    .foregroundStyle(accent.opacity(0.3))
                Text("NOTHING IN PROGRESS")
                    .font(ZapTheme.archivoBlack(15))
                    .foregroundStyle(tone.text)
                Text("Open a downloaded comic to start reading.\nIt'll appear here automatically.")
                    .font(.system(size: 13))
                    .foregroundStyle(tone.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity).padding(.top, 80).padding(.horizontal, 40)
        } else {
            VStack(spacing: 12) {
                ForEach(inProgress) { comic in
                    CurrentlyReadingCard(comic: comic, library: library, tone: tone, accent: accent) {
                        onOpen(comic)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct CurrentlyReadingCard: View {
    let comic: LibraryComic
    let library: LibraryStore
    let tone: ZapTheme.Tone
    let accent: Color
    let onOpen: () -> Void

    private var prog: LocalReadingProgress? { library.readingProgress[comic.id] }

    private var pct: CGFloat {
        guard let p = prog, p.total > 0 else { return 0 }
        return min(1, CGFloat(p.page + 1) / CGFloat(p.total))
    }

    private var lastReadLabel: String {
        guard let date = prog?.lastReadAt else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    var body: some View {
        Button { onOpen() } label: {
            HStack(spacing: 14) {
                // Cover
                ZStack {
                    if let img = library.coverImage(for: comic) {
                        Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#0a0a14")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "book.closed")
                            .font(.system(size: 20)).foregroundStyle(.white.opacity(0.15))
                    }
                }
                .frame(width: 68, height: 96)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let pub = comic.publisher {
                            Text(pub.uppercased())
                                .font(.system(size: 9, weight: .black)).kerning(0.4)
                                .foregroundStyle(accent).lineLimit(1)
                        }
                        Text(comic.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tone.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(tone.chipBg)
                            Capsule().fill(accent)
                                .frame(width: geo.size.width * pct)
                                .animation(.easeInOut(duration: 0.3), value: pct)
                        }
                    }
                    .frame(height: 4)

                    // Stats row
                    HStack(spacing: 8) {
                        if let p = prog, p.total > 0 {
                            Text("Page \(p.page + 1) of \(p.total)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(tone.textDim)
                            Text("·")
                                .foregroundStyle(tone.textMuted)
                            Text("\(Int(pct * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(accent)
                        }
                        Spacer(minLength: 0)
                        if !lastReadLabel.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "clock").font(.system(size: 9))
                                Text(lastReadLabel).font(.system(size: 10))
                            }
                            .foregroundStyle(tone.textMuted)
                        }
                    }
                }

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tone.textMuted)
            }
            .padding(12)
            .background(tone.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tone.chipBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Read Comics view
private struct ReadComicsView: View {
    let library: LibraryStore
    let tone: ZapTheme.Tone
    var onOpen: (LibraryComic) -> Void = { _ in }
    private let accent = ZapTheme.accent
    private let colW: CGFloat = (UIScreen.main.bounds.width - 40 - 24) / 3
    @State private var comicToDelete: LibraryComic? = nil

    private var readComics: [LibraryComic] {
        library.comics.filter { library.isRead(id: $0.id) }
    }

    var body: some View {
        if readComics.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(accent.opacity(0.3))
                Text("NO READ COMICS YET")
                    .font(ZapTheme.archivoBlack(15))
                    .foregroundStyle(tone.text)
                Text("Use the ··· menu on any comic\nand tap \"Mark as Read\".")
                    .font(.system(size: 13))
                    .foregroundStyle(tone.textDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity).padding(.top, 80).padding(.horizontal, 40)
        } else {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(readComics) { comic in
                    LibraryComicCard(
                        comic: comic, library: library,
                        width: colW, height: colW * 1.25, accent: accent, tone: tone,
                        onOpen: { onOpen(comic) },
                        onDelete: { comicToDelete = comic },
                        onToggleRead: { library.toggleRead(id: comic.id) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .alert("Delete this comic?", isPresented: .init(
                get: { comicToDelete != nil },
                set: { if !$0 { comicToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let c = comicToDelete { library.delete(c) }
                    comicToDelete = nil
                }
                Button("Cancel", role: .cancel) { comicToDelete = nil }
            } message: {
                Text("The CBZ file and cover will be removed from your library.")
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
